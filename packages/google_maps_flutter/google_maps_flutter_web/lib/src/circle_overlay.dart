// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// Paints a circle as an SVG `<circle>` with gradient/pattern fill +
/// stroke + glow on top of the (transparent) native gmaps circle.
class _CircleShapeOverlay {
  _CircleShapeOverlay({
    required this.overlay,
    required this.strokeWidth,
    required this.zIndex,
    required LatLng center,
    required double radiusMeters,
  })  : _center = center,
        _radiusMeters = radiusMeters;

  final WebCircleOverlay overlay;
  final double strokeWidth;
  final int zIndex;

  LatLng _center;
  double _radiusMeters;
  gmaps.OverlayView? _gmOverlay;
  web.HTMLDivElement? _root;
  web.Element? _circle;
  _InstalledPaint? _fillPaint;
  _InstalledPaint? _strokePaint;
  int _animHandle = 0;
  gmaps.Map? _map;

  void attach(gmaps.Map map) {
    final gmaps.OverlayView ov = gmaps.OverlayView();
    ov.onAdd = _onAdd;
    ov.draw = _onDraw;
    ov.onRemove = _onRemove;
    ov.map = map as JSAny;
    _gmOverlay = ov;
    _map = map;
  }

  void detach() {
    if (_animHandle != 0) {
      _ShapePaintAnimationManager.instance.unregister(_animHandle);
      _animHandle = 0;
    }
    _gmOverlay?.map = null;
    _gmOverlay = null;
  }

  void setCircle(LatLng center, double radiusMeters) {
    _center = center;
    _radiusMeters = radiusMeters;
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
          // Scope style + layout recalc only — `contain: paint` would
          // clip the 0×0 root box (children rely on overflow:visible).
          ..style.setProperty('contain', 'layout style')
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

    final web.Element circle =
        web.document.createElementNS(_shapeSvgNs, 'circle')
          ..setAttribute('fill', _fillPaint?.refUrl ?? 'none')
          ..setAttribute(
            'stroke',
            _strokePaint?.refUrl ?? (stroke == null ? 'none' : ''),
          )
          ..setAttribute('stroke-width', strokeWidth.toStringAsFixed(1));
    if (glowUrl != null) {
      circle.setAttribute('filter', glowUrl);
    }
    svg.appendChild(circle);

    root.appendChild(svg);
    _resolvePaneElement(panes, overlay.pane).appendChild(root);

    _root = root;
    _circle = circle;

    // Animation registration.
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
        map: _map,
      );
    }
  }

  void _onDraw() {
    final gmaps.OverlayView? ov = _gmOverlay;
    final web.Element? circle = _circle;
    if (ov == null || circle == null) {
      return;
    }
    final gmaps.MapCanvasProjection? projection = ov.projection;
    if (projection == null) {
      return;
    }

    final gmaps.Point? c = projection.fromLatLngToDivPixel(
      gmaps.LatLng(_center.latitude, _center.longitude),
    );
    if (c == null) {
      return;
    }
    // Convert radius (meters) → screen pixels by projecting a point
    // `radius` north of centre and measuring the vertical pixel delta.
    final double degLat = _radiusMeters / 111320.0;
    final gmaps.Point? north = projection.fromLatLngToDivPixel(
      gmaps.LatLng(_center.latitude + degLat, _center.longitude),
    );
    final double rPx = north == null
        ? 0
        : (c.y.toDouble() - north.y.toDouble()).abs();

    circle
      ..setAttribute('cx', c.x.toDouble().toStringAsFixed(2))
      ..setAttribute('cy', c.y.toDouble().toStringAsFixed(2))
      ..setAttribute('r', rPx.toStringAsFixed(2));
  }

  void _onRemove() {
    if (_animHandle != 0) {
      _ShapePaintAnimationManager.instance.unregister(_animHandle);
      _animHandle = 0;
    }
    _root?.remove();
    _root = null;
    _circle = null;
    _fillPaint = null;
    _strokePaint = null;
  }
}
