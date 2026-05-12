// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// Drives a single RAF loop that advances the IconSequence offset on every
/// registered animated polyline. Self-stops when the registration list
/// empties; auto-pauses when the page is hidden.
class _PolylineAnimationManager {
  _PolylineAnimationManager._();

  static final _PolylineAnimationManager instance =
      _PolylineAnimationManager._();

  final Map<int, _AnimatedPolyline> _active = <int, _AnimatedPolyline>{};
  int _nextHandle = 1;
  int _rafId = 0;
  double? _lastFrameMs;
  bool _visibilityHooked = false;

  /// Returns a handle the caller stores; pass it back to [unregister].
  int register(gmaps.Polyline polyline, WebPolylineAnimation animation,
      Color polylineColor) {
    final int handle = _nextHandle++;
    _active[handle] = _AnimatedPolyline(
      polyline: polyline,
      animation: animation,
      polylineColor: polylineColor,
      offset: 0,
    );
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
    _lastFrameMs = null;
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
    final double dtSec =
        _lastFrameMs == null ? 0 : (now - _lastFrameMs!) / 1000.0;
    _lastFrameMs = now;

    for (final _AnimatedPolyline entry in _active.values) {
      final double signedSpeed =
          entry.animation.direction == WebFlowDirection.forward
              ? entry.animation.speedPercentPerSecond
              : -entry.animation.speedPercentPerSecond;
      entry.offset = (entry.offset + signedSpeed * dtSec) % 100;
      if (entry.offset < 0) {
        entry.offset += 100;
      }
      final JSArray<gmaps.IconSequence> icons = _buildAnimatedIcons(
        entry.animation,
        entry.polylineColor,
        entry.offset,
      );
      entry.polyline.set('icons', icons);
    }

    if (_active.isNotEmpty) {
      _rafId = web.window.requestAnimationFrame(_tick.toJS);
    }
  }
}

class _AnimatedPolyline {
  _AnimatedPolyline({
    required this.polyline,
    required this.animation,
    required this.polylineColor,
    required this.offset,
  });
  final gmaps.Polyline polyline;
  final WebPolylineAnimation animation;
  final Color polylineColor;
  double offset;
}

/// Builds the gmaps.IconSequence array for a polyline animation frame.
JSArray<gmaps.IconSequence> _buildAnimatedIcons(
  WebPolylineAnimation animation,
  Color polylineColor,
  double offsetPercent,
) {
  final gmaps.Symbol symbol = _symbolForFlow(animation, polylineColor);
  final gmaps.IconSequence sequence = gmaps.IconSequence(
    icon: symbol,
    offset: '${offsetPercent.toStringAsFixed(2)}%',
    repeat: animation.spacing,
    fixedRotation: false,
  );
  return <gmaps.IconSequence>[sequence].toJS;
}

gmaps.Symbol _symbolForFlow(
  WebPolylineAnimation animation,
  Color polylineColor,
) {
  final Color color = animation.color ?? polylineColor;
  final String cssColor = _getCssColor(color);

  switch (animation.symbol) {
    case WebFlowSymbol.arrow:
      return gmaps.Symbol(
        path: gmaps.SymbolPath.FORWARD_OPEN_ARROW as JSAny,
        scale: animation.size,
        strokeColor: cssColor,
        strokeWeight: 2,
      );
    case WebFlowSymbol.dot:
      return gmaps.Symbol(
        path: gmaps.SymbolPath.CIRCLE as JSAny,
        scale: animation.size,
        fillColor: cssColor,
        fillOpacity: 1,
        strokeColor: cssColor,
        strokeWeight: 0,
      );
    case WebFlowSymbol.dash:
      // SVG path for a short horizontal dash centered on the symbol origin.
      return gmaps.Symbol(
        path: 'M -1 0 L 1 0'.toJS,
        scale: animation.size,
        strokeColor: cssColor,
        strokeOpacity: 1,
        strokeWeight: 3,
      );
    case WebFlowSymbol.chevron:
      // Double forward arrow, drawn as two stacked V shapes.
      return gmaps.Symbol(
        path: 'M -1 -1 L 0 0 L -1 1 M 0 -1 L 1 0 L 0 1'.toJS,
        scale: animation.size,
        strokeColor: cssColor,
        strokeWeight: 2,
      );
  }
}
