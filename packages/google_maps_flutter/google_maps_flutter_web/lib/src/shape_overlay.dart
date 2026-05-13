// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

// SVG namespace, shared across the shape overlay files.
const String _shapeSvgNs = 'http://www.w3.org/2000/svg';

// Monotonically increasing ID seed for paint / filter `<defs>` so each
// reference is unique within the page.
int _paintIdSeed = 0;

String _nextPaintId(String prefix) {
  _paintIdSeed++;
  return '$prefix-$_paintIdSeed';
}

/// Resolves a [WebOverlayPane] to the actual `<Element>` panes object
/// returned by `gmaps.OverlayView.getPanes()`.
web.Element _resolvePaneElement(gmaps.MapPanes panes, WebOverlayPane pane) {
  switch (pane) {
    case WebOverlayPane.overlayLayer:
      return panes.overlayLayer;
    case WebOverlayPane.markerLayer:
      return panes.markerLayer;
    case WebOverlayPane.floatPane:
      return panes.floatPane;
  }
}

/// Holds the SVG resources created by [installPaint] so the overlay can
/// hand them to the animation tick callback later.
class _InstalledPaint {
  _InstalledPaint(this.refUrl, this.targetEl);

  /// `url(#id)` string for the `fill` / `stroke` attribute.
  final String refUrl;

  /// The element that should receive `gradientTransform` / `patternTransform`
  /// updates each animation tick. Null for non-animatable paints.
  final web.Element? targetEl;
}

/// Renders the SVG `<defs>` describing [paint] into [defs], returns the
/// generated `url(#id)` reference for use as the consumer element's `fill`
/// or `stroke` attribute.
_InstalledPaint _installPaint({
  required web.Element defs,
  required WebShapePaint paint,
}) {
  switch (paint) {
    case WebGradientPaint():
      return _installGradient(defs, paint);
    case WebStripesPaint():
      return _installStripes(defs, paint);
    case WebDotsPaint():
      return _installDots(defs, paint);
  }
}

_InstalledPaint _installGradient(web.Element defs, WebGradientPaint paint) {
  final String id = _nextPaintId('fd-grad');
  final web.Element grad = web.document.createElementNS(
    _shapeSvgNs,
    paint.kind == WebGradientKind.linear ? 'linearGradient' : 'radialGradient',
  )
    ..setAttribute('id', id)
    ..setAttribute('gradientUnits', 'objectBoundingBox')
    ..setAttribute('spreadMethod', 'repeat');

  if (paint.kind == WebGradientKind.linear) {
    // Rotate the gradient using userSpaceOnUse-friendly endpoints inside
    // the 0..1 box, then apply `gradientTransform` rotation in objectBox
    // units so the stop layout follows [angleDegrees].
    grad
      ..setAttribute('x1', '0')
      ..setAttribute('y1', '0.5')
      ..setAttribute('x2', '${1.0 / paint.repeatCount}')
      ..setAttribute('y2', '0.5');
    grad.setAttribute(
      'gradientTransform',
      'rotate(${paint.angleDegrees} 0.5 0.5)',
    );
  } else {
    grad
      ..setAttribute('cx', paint.centerX.toStringAsFixed(3))
      ..setAttribute('cy', paint.centerY.toStringAsFixed(3))
      ..setAttribute('r', '${paint.radius / paint.repeatCount}')
      ..setAttribute('fx', paint.centerX.toStringAsFixed(3))
      ..setAttribute('fy', paint.centerY.toStringAsFixed(3));
  }

  for (int i = 0; i < paint.stops.length; i++) {
    final double pct = i / (paint.stops.length - 1) * 100.0;
    final Color c = paint.stops[i];
    final web.Element stopEl =
        web.document.createElementNS(_shapeSvgNs, 'stop')
          ..setAttribute('offset', '${pct.toStringAsFixed(2)}%')
          ..setAttribute('stop-color', _getCssColor(c))
          ..setAttribute('stop-opacity', _getCssOpacity(c).toString());
    grad.appendChild(stopEl);
  }
  defs.appendChild(grad);

  return _InstalledPaint('url(#$id)', grad);
}

_InstalledPaint _installStripes(web.Element defs, WebStripesPaint paint) {
  final String id = _nextPaintId('fd-stripes');
  // Stripes are drawn inside a pattern tile of size
  // (stripeWidth + gapWidth) by stripeWidth, rotated by [angleDegrees].
  final double w = paint.stripeWidthPx + paint.gapWidthPx;
  final double h = paint.stripeWidthPx;
  final web.Element pat = web.document.createElementNS(_shapeSvgNs, 'pattern')
    ..setAttribute('id', id)
    ..setAttribute('patternUnits', 'userSpaceOnUse')
    ..setAttribute('width', w.toStringAsFixed(2))
    ..setAttribute('height', h.toStringAsFixed(2))
    ..setAttribute(
      'patternTransform',
      'rotate(${paint.angleDegrees})',
    );

  final web.Element bg = web.document.createElementNS(_shapeSvgNs, 'rect')
    ..setAttribute('x', '0')
    ..setAttribute('y', '0')
    ..setAttribute('width', w.toStringAsFixed(2))
    ..setAttribute('height', h.toStringAsFixed(2))
    ..setAttribute('fill', _getCssColor(paint.colorB))
    ..setAttribute('fill-opacity', _getCssOpacity(paint.colorB).toString());
  pat.appendChild(bg);

  final web.Element stripe = web.document.createElementNS(_shapeSvgNs, 'rect')
    ..setAttribute('x', '0')
    ..setAttribute('y', '0')
    ..setAttribute('width', paint.stripeWidthPx.toStringAsFixed(2))
    ..setAttribute('height', h.toStringAsFixed(2))
    ..setAttribute('fill', _getCssColor(paint.colorA))
    ..setAttribute('fill-opacity', _getCssOpacity(paint.colorA).toString());
  pat.appendChild(stripe);
  defs.appendChild(pat);

  return _InstalledPaint('url(#$id)', pat);
}

_InstalledPaint _installDots(web.Element defs, WebDotsPaint paint) {
  final String id = _nextPaintId('fd-dots');
  final web.Element pat = web.document.createElementNS(_shapeSvgNs, 'pattern')
    ..setAttribute('id', id)
    ..setAttribute('patternUnits', 'userSpaceOnUse')
    ..setAttribute('width', paint.spacingPx.toStringAsFixed(2))
    ..setAttribute('height', paint.spacingPx.toStringAsFixed(2));

  if (paint.backgroundColor.a > 0) {
    final web.Element bg = web.document.createElementNS(_shapeSvgNs, 'rect')
      ..setAttribute('x', '0')
      ..setAttribute('y', '0')
      ..setAttribute('width', paint.spacingPx.toStringAsFixed(2))
      ..setAttribute('height', paint.spacingPx.toStringAsFixed(2))
      ..setAttribute('fill', _getCssColor(paint.backgroundColor))
      ..setAttribute(
        'fill-opacity',
        _getCssOpacity(paint.backgroundColor).toString(),
      );
    pat.appendChild(bg);
  }

  final web.Element dot = web.document.createElementNS(_shapeSvgNs, 'circle')
    ..setAttribute('cx', (paint.spacingPx / 2).toStringAsFixed(2))
    ..setAttribute('cy', (paint.spacingPx / 2).toStringAsFixed(2))
    ..setAttribute('r', paint.dotRadiusPx.toStringAsFixed(2))
    ..setAttribute('fill', _getCssColor(paint.color))
    ..setAttribute('fill-opacity', _getCssOpacity(paint.color).toString());
  pat.appendChild(dot);
  defs.appendChild(pat);

  return _InstalledPaint('url(#$id)', pat);
}

/// Builds an SVG `<filter>` realising [glow] and appends it to [defs].
/// Returns the `url(#id)` string for the consumer's `filter` attribute.
String _installGlow(web.Element defs, WebGlow glow) {
  final String id = _nextPaintId('fd-glow');
  // Generous padding so the blur isn't clipped by the filter region.
  const String pad = '-50%';
  final web.Element filter = web.document.createElementNS(_shapeSvgNs, 'filter')
    ..setAttribute('id', id)
    ..setAttribute('x', pad)
    ..setAttribute('y', pad)
    ..setAttribute('width', '200%')
    ..setAttribute('height', '200%');

  final web.Element blur = web.document.createElementNS(_shapeSvgNs, 'feGaussianBlur')
    ..setAttribute('in', 'SourceAlpha')
    ..setAttribute('stdDeviation', glow.blurPx.toStringAsFixed(2));
  filter.appendChild(blur);

  final web.Element offset = web.document.createElementNS(_shapeSvgNs, 'feOffset')
    ..setAttribute('dx', glow.offsetX.toStringAsFixed(2))
    ..setAttribute('dy', glow.offsetY.toStringAsFixed(2))
    ..setAttribute('result', 'offsetBlur');
  filter.appendChild(offset);

  final web.Element flood = web.document.createElementNS(_shapeSvgNs, 'feFlood')
    ..setAttribute('flood-color', _getCssColor(glow.color))
    ..setAttribute('flood-opacity', _getCssOpacity(glow.color).toString());
  filter.appendChild(flood);

  final web.Element comp = web.document.createElementNS(_shapeSvgNs, 'feComposite')
    ..setAttribute('in2', 'offsetBlur')
    ..setAttribute('operator', 'in');
  filter.appendChild(comp);

  final web.Element merge = web.document.createElementNS(_shapeSvgNs, 'feMerge');
  merge
    ..appendChild(web.document.createElementNS(_shapeSvgNs, 'feMergeNode'))
    ..appendChild(
      web.document.createElementNS(_shapeSvgNs, 'feMergeNode')
        ..setAttribute('in', 'SourceGraphic'),
    );
  filter.appendChild(merge);

  defs.appendChild(filter);
  return 'url(#$id)';
}

/// Returns the animation speed (in percent-per-second for gradients,
/// CSS-pixels-per-second for patterns) configured on [paint], or null
/// when [paint] is not animatable.
double? _paintAnimationSpeed(WebShapePaint paint) {
  switch (paint) {
    case WebGradientPaint():
      return paint.animationSpeedPercentPerSecond;
    case WebStripesPaint():
      return paint.animationSpeedPxPerSecond;
    case WebDotsPaint():
      return paint.animationSpeedPxPerSecond;
  }
}

/// Applies an animation offset to the `gradientTransform` /
/// `patternTransform` attribute of the installed paint's target element.
/// [offsetSeconds] is elapsed time, the caller decides how to interpret it.
void _animatePaintTarget({
  required WebShapePaint paint,
  required web.Element target,
  required double elapsedSec,
}) {
  switch (paint) {
    case WebGradientPaint():
      final double speed = paint.animationSpeedPercentPerSecond ?? 0;
      if (speed == 0) {
        return;
      }
      // Translate by fraction of object box. spreadMethod="repeat" tiles
      // the ramp so the slide is seamless.
      double frac = (elapsedSec * speed / 100.0);
      frac = frac - frac.floor();
      if (frac < 0) {
        frac += 1.0;
      }
      final double tx = frac / paint.repeatCount;
      if (paint.kind == WebGradientKind.linear) {
        target.setAttribute(
          'gradientTransform',
          'rotate(${paint.angleDegrees} 0.5 0.5) translate(${tx.toStringAsFixed(4)} 0)',
        );
      } else {
        // For radial we shift the focal point along the radius — a subtle
        // breathing effect rather than a rotation.
        final double shift = (tx - 0.5) * paint.radius;
        target.setAttribute(
          'gradientTransform',
          'translate(${shift.toStringAsFixed(4)} 0)',
        );
      }
    case WebStripesPaint():
      final double speed = paint.animationSpeedPxPerSecond ?? 0;
      if (speed == 0) {
        return;
      }
      final double w = paint.stripeWidthPx + paint.gapWidthPx;
      final double tx = (elapsedSec * speed) % w;
      target.setAttribute(
        'patternTransform',
        'rotate(${paint.angleDegrees}) translate(${tx.toStringAsFixed(2)} 0)',
      );
    case WebDotsPaint():
      final double speed = paint.animationSpeedPxPerSecond ?? 0;
      if (speed == 0) {
        return;
      }
      final double tx = (elapsedSec * speed) % paint.spacingPx;
      target.setAttribute(
        'patternTransform',
        'translate(${tx.toStringAsFixed(2)} 0)',
      );
  }
}

/// Records what a shape overlay registered with the shared animation
/// manager. Each tick the manager invokes the closure with the elapsed
/// time so the overlay can update its own paints.
class _AnimatedPaintSubscription {
  _AnimatedPaintSubscription(this.tick);
  final void Function(double elapsedSec) tick;
}

/// Shared RAF loop driving all shape-overlay paint animations. Both the
/// polygon and circle overlays register their tick closures here.
class _ShapePaintAnimationManager {
  _ShapePaintAnimationManager._();
  static final _ShapePaintAnimationManager instance =
      _ShapePaintAnimationManager._();

  final Map<int, _AnimatedPaintSubscription> _active =
      <int, _AnimatedPaintSubscription>{};
  int _next = 1;
  int _rafId = 0;
  double? _startMs;
  bool _visibilityHooked = false;

  int register(void Function(double elapsedSec) tick) {
    final int handle = _next++;
    _active[handle] = _AnimatedPaintSubscription(tick);
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
    for (final _AnimatedPaintSubscription sub in _active.values) {
      sub.tick(elapsedSec);
    }
    if (_active.isNotEmpty) {
      _rafId = web.window.requestAnimationFrame(_tick.toJS);
    }
  }
}
