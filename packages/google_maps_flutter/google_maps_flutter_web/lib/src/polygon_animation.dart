// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// Drives a shared RAF loop that lerps fill and/or stroke colours of every
/// registered animated polygon between configured endpoints. Self-stops
/// when the registration list empties; auto-pauses when the page is hidden.
class _PolygonAnimationManager {
  _PolygonAnimationManager._();

  static final _PolygonAnimationManager instance = _PolygonAnimationManager._();

  final Map<int, _AnimatedPolygon> _active = <int, _AnimatedPolygon>{};
  int _nextHandle = 1;
  int _rafId = 0;
  double? _startMs;
  bool _visibilityHooked = false;

  int register(gmaps.Polygon polygon, WebPolygonAnimation animation) {
    final int handle = _nextHandle++;
    _active[handle] = _AnimatedPolygon(polygon: polygon, animation: animation);
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
    final double elapsedMs = now - _startMs!;

    for (final _AnimatedPolygon entry in _active.values) {
      final WebPolygonAnimation anim = entry.animation;
      final double t = (elapsedMs % anim.periodMs) / anim.periodMs;
      final double s = 0.5 - 0.5 * math.cos(2 * math.pi * t);

      if (anim.animatesFill) {
        final Color blended =
            Color.lerp(anim.fillColorA!, anim.fillColorB!, s)!;
        entry.polygon.set('fillColor', _getCssColor(blended).toJS);
        entry.polygon.set('fillOpacity', _getCssOpacity(blended).toJS);
      }
      if (anim.animatesStroke) {
        final Color blended =
            Color.lerp(anim.strokeColorA!, anim.strokeColorB!, s)!;
        entry.polygon.set('strokeColor', _getCssColor(blended).toJS);
        entry.polygon.set('strokeOpacity', _getCssOpacity(blended).toJS);
      }
    }

    if (_active.isNotEmpty) {
      _rafId = web.window.requestAnimationFrame(_tick.toJS);
    }
  }
}

class _AnimatedPolygon {
  _AnimatedPolygon({required this.polygon, required this.animation});

  final gmaps.Polygon polygon;
  final WebPolygonAnimation animation;
}
