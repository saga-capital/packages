// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

// SVG namespace used for all gradient overlay elements.
const String _svgNs = 'http://www.w3.org/2000/svg';

// Monotonically increasing ID seed so each gradient gets a unique
// `<linearGradient id="...">` per page lifetime.
int _gradientIdSeed = 0;

/// Paints a polyline as an SVG `<path>` filled with a `<linearGradient>` on
/// top of (or in place of) the underlying gmaps polyline.
///
/// The overlay lives in one of the gmaps panes (defaults to `overlayLayer`,
/// same level as native polylines/polygons). gmaps shifts the pane on every
/// pan, so the SVG follows the map for free; we only rebuild the path when
/// gmaps fires `draw()` (i.e. when the projection has actually changed).
/// Path coordinates come from `fromLatLngToDivPixel`, expressed in the
/// pane's own coordinate system.
class _PolylineGradientOverlay {
  _PolylineGradientOverlay({
    required this.gradient,
    required this.strokeWidth,
    required this.zIndex,
    required List<LatLng> points,
  }) : _points = List<LatLng>.of(points);

  final WebPolylineGradient gradient;
  final double strokeWidth;
  final int zIndex;

  List<LatLng> _points;
  gmaps.OverlayView? _overlay;
  web.HTMLDivElement? _root;
  web.Element? _path;
  web.Element? _gradientEl;
  String _gradientId = '';

  // Cached projected geometry — populated by _onDraw, consumed by the
  // animation tick to translate the gradient transform without redoing
  // any projection work.
  double _tileUnitX = 0;
  double _tileUnitY = 0;
  double _tileLen = 0;
  double _animOffsetPx = 0;
  int _animationHandle = 0;

  void attach(gmaps.Map map) {
    final gmaps.OverlayView overlay = gmaps.OverlayView();
    overlay.onAdd = _onAdd;
    overlay.draw = _onDraw;
    overlay.onRemove = _onRemove;
    overlay.map = map as JSAny;
    _overlay = overlay;
  }

  void detach() {
    if (_animationHandle != 0) {
      _GradientAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    _overlay?.map = null;
    _overlay = null;
  }

  void setPoints(List<LatLng> points) {
    _points = List<LatLng>.of(points);
    _onDraw();
  }

  // ---------------------------------------------------------------- lifecycle

  void _onAdd() {
    final gmaps.MapPanes? panes = _overlay?.panes;
    if (panes == null) {
      return;
    }
    _gradientIdSeed++;
    _gradientId = 'fd-poly-grad-$_gradientIdSeed';

    final web.HTMLDivElement root =
        web.document.createElement('div') as web.HTMLDivElement
          ..style.position = 'absolute'
          ..style.left = '0'
          ..style.top = '0'
          ..style.pointerEvents = 'none'
          ..style.zIndex = '$zIndex';

    // No viewBox — user coord = CSS pixel. overflow:visible lets the path
    // paint at arbitrary div-pixel coordinates that may be far outside
    // this SVG's own 1×1 box. left/top:0 anchors the SVG's user (0,0) on
    // the pane's (0,0).
    final web.Element svg = web.document.createElementNS(_svgNs, 'svg')
      ..setAttribute('width', '1')
      ..setAttribute('height', '1');
    svg.setAttribute(
      'style',
      'position:absolute; left:0; top:0; overflow:visible; '
          'pointer-events:none;',
    );

    final web.Element defs = web.document.createElementNS(_svgNs, 'defs');
    final web.Element grad =
        web.document.createElementNS(_svgNs, 'linearGradient')
          ..setAttribute('id', _gradientId)
          ..setAttribute('gradientUnits', 'userSpaceOnUse')
          ..setAttribute('spreadMethod', 'repeat');
    for (int i = 0; i < gradient.stops.length; i++) {
      final double pct = i / (gradient.stops.length - 1) * 100.0;
      final Color stop = gradient.stops[i];
      final web.Element stopEl = web.document.createElementNS(_svgNs, 'stop')
        ..setAttribute('offset', '${pct.toStringAsFixed(2)}%')
        ..setAttribute('stop-color', _getCssColor(stop))
        ..setAttribute('stop-opacity', _getCssOpacity(stop).toString());
      grad.appendChild(stopEl);
    }
    defs.appendChild(grad);
    svg.appendChild(defs);

    final web.Element path = web.document.createElementNS(_svgNs, 'path')
      ..setAttribute('fill', 'none')
      ..setAttribute('stroke', 'url(#$_gradientId)')
      ..setAttribute('stroke-width', strokeWidth.toStringAsFixed(1))
      ..setAttribute('stroke-linecap', _linecapName(gradient.strokeLinecap))
      ..setAttribute('stroke-linejoin', _linejoinName(gradient.strokeLinejoin));
    svg.appendChild(path);

    root.appendChild(svg);
    _resolvePane(panes).appendChild(root);

    _root = root;
    _path = path;
    _gradientEl = grad;

    final double? speed = gradient.animationSpeedPercentPerSecond;
    if (speed != null && speed != 0) {
      _animationHandle =
          _GradientAnimationManager.instance.register(this, speed);
    }
  }

  void _onDraw() {
    final gmaps.OverlayView? overlay = _overlay;
    final web.Element? path = _path;
    final web.Element? grad = _gradientEl;
    if (overlay == null || path == null || grad == null) {
      return;
    }
    if (_points.length < 2) {
      path.setAttribute('d', '');
      return;
    }
    final gmaps.MapCanvasProjection? projection = overlay.projection;
    if (projection == null) {
      return;
    }

    final StringBuffer d = StringBuffer();
    double firstX = 0;
    double firstY = 0;
    double lastX = 0;
    double lastY = 0;
    bool seenAny = false;
    for (int i = 0; i < _points.length; i++) {
      final LatLng p = _points[i];
      final gmaps.Point? pt = projection.fromLatLngToDivPixel(
        gmaps.LatLng(p.latitude, p.longitude),
      );
      if (pt == null) {
        continue;
      }
      final double x = pt.x.toDouble();
      final double y = pt.y.toDouble();
      if (!seenAny) {
        firstX = x;
        firstY = y;
        d.write('M ');
        seenAny = true;
      } else {
        d.write(' L ');
      }
      d
        ..write(x.toStringAsFixed(2))
        ..write(' ')
        ..write(y.toStringAsFixed(2));
      lastX = x;
      lastY = y;
    }
    path.setAttribute('d', d.toString());

    // Lay out the gradient tile along the projected start->end axis.
    // [repeatCount] tiles get packed across the span; `spreadMethod=repeat`
    // continues the pattern past the tile boundary so any animation can
    // slide indefinitely without exposing the seam.
    final double dx = lastX - firstX;
    final double dy = lastY - firstY;
    final double len = math.sqrt(dx * dx + dy * dy);
    final int reps = gradient.repeatCount < 1 ? 1 : gradient.repeatCount;
    final double tileLen = len <= 0 ? 1 : len / reps;
    final double ux = len <= 0 ? 1 : dx / len;
    final double uy = len <= 0 ? 0 : dy / len;
    _tileUnitX = ux;
    _tileUnitY = uy;
    _tileLen = tileLen;

    grad
      ..setAttribute('x1', firstX.toStringAsFixed(1))
      ..setAttribute('y1', firstY.toStringAsFixed(1))
      ..setAttribute('x2', (firstX + ux * tileLen).toStringAsFixed(1))
      ..setAttribute('y2', (firstY + uy * tileLen).toStringAsFixed(1));

    _writeGradientTransform();
  }

  void _onRemove() {
    if (_animationHandle != 0) {
      _GradientAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    _root?.remove();
    _root = null;
    _path = null;
    _gradientEl = null;
  }

  /// Called by [_GradientAnimationManager] each RAF tick. Updates the
  /// `gradientTransform` translation so the stops slide along the path
  /// without retriggering a `draw()` reprojection.
  void _applyAnimationOffsetPercent(double pct) {
    if (_tileLen <= 0) {
      return;
    }
    double frac = pct / 100.0;
    frac = frac - frac.floor();
    if (frac < 0) {
      frac += 1.0;
    }
    _animOffsetPx = frac * _tileLen;
    _writeGradientTransform();
  }

  void _writeGradientTransform() {
    final web.Element? grad = _gradientEl;
    if (grad == null) {
      return;
    }
    if (_animOffsetPx == 0) {
      grad.removeAttribute('gradientTransform');
      return;
    }
    final double tx = _tileUnitX * _animOffsetPx;
    final double ty = _tileUnitY * _animOffsetPx;
    grad.setAttribute(
      'gradientTransform',
      'translate(${tx.toStringAsFixed(2)} ${ty.toStringAsFixed(2)})',
    );
  }

  web.Element _resolvePane(gmaps.MapPanes panes) {
    switch (gradient.pane) {
      case WebOverlayPane.overlayLayer:
        return panes.overlayLayer;
      case WebOverlayPane.markerLayer:
        return panes.markerLayer;
      case WebOverlayPane.floatPane:
        return panes.floatPane;
    }
  }
}

String _linecapName(WebStrokeLinecap cap) {
  switch (cap) {
    case WebStrokeLinecap.butt:
      return 'butt';
    case WebStrokeLinecap.round:
      return 'round';
    case WebStrokeLinecap.square:
      return 'square';
  }
}

String _linejoinName(WebStrokeLinejoin join) {
  switch (join) {
    case WebStrokeLinejoin.miter:
      return 'miter';
    case WebStrokeLinejoin.round:
      return 'round';
    case WebStrokeLinejoin.bevel:
      return 'bevel';
  }
}

/// Shared RAF loop driving the `gradientTransform` translation of every
/// registered animated gradient. Self-stops when empty; auto-pauses on
/// `document.hidden`.
class _GradientAnimationManager {
  _GradientAnimationManager._();

  static final _GradientAnimationManager instance =
      _GradientAnimationManager._();

  final Map<int, _AnimatedGradient> _active = <int, _AnimatedGradient>{};
  int _nextHandle = 1;
  int _rafId = 0;
  double? _startMs;
  bool _visibilityHooked = false;

  int register(_PolylineGradientOverlay overlay, double speedPct) {
    final int handle = _nextHandle++;
    _active[handle] = _AnimatedGradient(overlay: overlay, speedPct: speedPct);
    _ensureVisibilityHook();
    _start();
    return handle;
  }

  void unregister(int handle) {
    _active.remove(handle);
    if (_active.isEmpty) {
      _stop();
    }
  }

  void _ensureVisibilityHook() {
    if (_visibilityHooked) {
      return;
    }
    _visibilityHooked = true;
    void onVisibilityChange(web.Event _) {
      if (web.document.hidden) {
        _stop();
      } else if (_active.isNotEmpty) {
        _start();
      }
    }
    web.document.addEventListener('visibilitychange', onVisibilityChange.toJS);
  }

  void _start() {
    if (_rafId != 0 || web.document.hidden) {
      return;
    }
    _startMs = null;
    _rafId = web.window.requestAnimationFrame(_tick.toJS);
  }

  void _stop() {
    if (_rafId != 0) {
      web.window.cancelAnimationFrame(_rafId);
      _rafId = 0;
    }
  }

  void _tick(num timestamp) {
    _rafId = 0;
    final double now = timestamp.toDouble();
    _startMs ??= now;
    final double elapsedSec = (now - _startMs!) / 1000.0;

    for (final _AnimatedGradient entry in _active.values) {
      final double pct = elapsedSec * entry.speedPct;
      entry.overlay._applyAnimationOffsetPercent(pct);
    }

    if (_active.isNotEmpty) {
      _rafId = web.window.requestAnimationFrame(_tick.toJS);
    }
  }
}

class _AnimatedGradient {
  _AnimatedGradient({required this.overlay, required this.speedPct});

  final _PolylineGradientOverlay overlay;
  final double speedPct;
}
