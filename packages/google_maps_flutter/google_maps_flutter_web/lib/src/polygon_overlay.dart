// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// Paints a polygon as an SVG `<path>` with gradient/pattern fill +
/// stroke + glow on top of the (transparent) native gmaps polygon.
class _PolygonShapeOverlay {
  _PolygonShapeOverlay({
    required this.overlay,
    required this.strokeWidth,
    required this.zIndex,
    required List<LatLng> points,
    required List<List<LatLng>> holes,
  })  : _points = List<LatLng>.of(points),
        _holes = holes.map(List<LatLng>.of).toList();

  final WebPolygonOverlay overlay;
  final double strokeWidth;
  final int zIndex;

  List<LatLng> _points;
  List<List<LatLng>> _holes;
  gmaps.OverlayView? _gmOverlay;
  web.HTMLDivElement? _root;
  web.Element? _path;
  _InstalledPaint? _fillPaint;
  _InstalledPaint? _strokePaint;
  int _animHandle = 0;

  void attach(gmaps.Map map) {
    final gmaps.OverlayView ov = gmaps.OverlayView();
    ov.onAdd = _onAdd;
    ov.draw = _onDraw;
    ov.onRemove = _onRemove;
    ov.map = map as JSAny;
    _gmOverlay = ov;
  }

  void detach() {
    if (_animHandle != 0) {
      _ShapePaintAnimationManager.instance.unregister(_animHandle);
      _animHandle = 0;
    }
    _gmOverlay?.map = null;
    _gmOverlay = null;
  }

  void setGeometry(List<LatLng> points, List<List<LatLng>> holes) {
    _points = List<LatLng>.of(points);
    _holes = holes.map(List<LatLng>.of).toList();
    _onDraw();
  }

  // ---------------------------------------------------------------- lifecycle

  void _onAdd() {
    final gmaps.MapPanes? panes = _gmOverlay?.panes;
    if (panes == null) {
      return;
    }

    final web.HTMLDivElement root =
        web.document.createElement('div') as web.HTMLDivElement
          ..style.position = 'absolute'
          ..style.left = '0'
          ..style.top = '0'
          ..style.pointerEvents = 'none'
          ..style.zIndex = '$zIndex';

    final web.Element svg = web.document.createElementNS(_shapeSvgNs, 'svg')
      ..setAttribute('width', '1')
      ..setAttribute('height', '1');
    svg.setAttribute(
      'style',
      'position:absolute; left:0; top:0; overflow:visible; '
          'pointer-events:none;',
    );

    final web.Element defs = web.document.createElementNS(_shapeSvgNs, 'defs');
    svg.appendChild(defs);

    String? glowUrl;
    final WebGlow? glow = overlay.glow;
    if (glow != null) {
      glowUrl = _installGlow(defs, glow);
    }

    final WebShapePaint? fill = overlay.fill;
    if (fill != null) {
      _fillPaint = _installPaint(defs: defs, paint: fill);
    }
    final WebShapePaint? stroke = overlay.stroke;
    if (stroke != null) {
      _strokePaint = _installPaint(defs: defs, paint: stroke);
    }

    final web.Element path = web.document.createElementNS(_shapeSvgNs, 'path')
      ..setAttribute('fill', _fillPaint?.refUrl ?? 'none')
      ..setAttribute('fill-rule', 'evenodd')
      ..setAttribute(
        'stroke',
        _strokePaint?.refUrl ?? (stroke == null ? 'none' : ''),
      )
      ..setAttribute('stroke-width', strokeWidth.toStringAsFixed(1))
      ..setAttribute('stroke-linejoin', 'round')
      ..setAttribute('stroke-linecap', 'round');
    if (glowUrl != null) {
      path.setAttribute('filter', glowUrl);
    }
    svg.appendChild(path);

    root.appendChild(svg);
    _resolvePaneElement(panes, overlay.pane).appendChild(root);

    _root = root;
    _path = path;

    // Animation registration — any fill or stroke paint may animate.
    final WebShapePaint? animFill =
        fill != null && _paintAnimationSpeed(fill) != null ? fill : null;
    final WebShapePaint? animStroke =
        stroke != null && _paintAnimationSpeed(stroke) != null ? stroke : null;
    final web.Element? fillTarget = _fillPaint?.targetEl;
    final web.Element? strokeTarget = _strokePaint?.targetEl;
    if ((animFill != null && fillTarget != null) ||
        (animStroke != null && strokeTarget != null)) {
      _animHandle = _ShapePaintAnimationManager.instance.register(
        (double elapsedSec) {
          if (animFill != null && fillTarget != null) {
            _animatePaintTarget(
              paint: animFill,
              target: fillTarget,
              elapsedSec: elapsedSec,
            );
          }
          if (animStroke != null && strokeTarget != null) {
            _animatePaintTarget(
              paint: animStroke,
              target: strokeTarget,
              elapsedSec: elapsedSec,
            );
          }
        },
      );
    }
  }

  void _onDraw() {
    final gmaps.OverlayView? ov = _gmOverlay;
    final web.Element? path = _path;
    if (ov == null || path == null) {
      return;
    }
    final gmaps.MapCanvasProjection? projection = ov.projection;
    if (projection == null) {
      return;
    }
    final StringBuffer d = StringBuffer();
    _writeSubpath(d, _points, projection);
    for (final List<LatLng> hole in _holes) {
      _writeSubpath(d, hole, projection);
    }
    path.setAttribute('d', d.toString());
  }

  void _writeSubpath(
    StringBuffer out,
    List<LatLng> points,
    gmaps.MapCanvasProjection projection,
  ) {
    bool seen = false;
    for (final LatLng p in points) {
      final gmaps.Point? pt = projection.fromLatLngToDivPixel(
        gmaps.LatLng(p.latitude, p.longitude),
      );
      if (pt == null) {
        continue;
      }
      out.write(seen ? ' L ' : 'M ');
      out
        ..write(pt.x.toStringAsFixed(2))
        ..write(' ')
        ..write(pt.y.toStringAsFixed(2));
      seen = true;
    }
    if (seen) {
      out.write(' Z ');
    }
  }

  void _onRemove() {
    if (_animHandle != 0) {
      _ShapePaintAnimationManager.instance.unregister(_animHandle);
      _animHandle = 0;
    }
    _root?.remove();
    _root = null;
    _path = null;
    _fillPaint = null;
    _strokePaint = null;
  }
}
