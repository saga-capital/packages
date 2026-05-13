// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// Drives a shared RAF loop that oscillates the radius of every registered
/// animated circle between its configured min/max bounds. Self-stops when
/// the registration list empties; auto-pauses when the page is hidden.
class _CircleAnimationManager {
  _CircleAnimationManager._();

  static final _CircleAnimationManager instance = _CircleAnimationManager._();

  final Map<int, _AnimatedCircle> _active = <int, _AnimatedCircle>{};
  int _nextHandle = 1;
  int _rafId = 0;
  double? _startMs;
  bool _visibilityHooked = false;

  int register(
    gmaps.Circle circle,
    WebCircleAnimation animation,
    double baseRadius,
  ) {
    final int handle = _nextHandle++;
    _active[handle] = _AnimatedCircle(
      circle: circle,
      animation: animation,
      baseRadius: baseRadius,
    );
    _ensureVisibilityHook();
    _start();
    return handle;
  }

  void unregister(int handle) {
    final _AnimatedCircle? entry = _active.remove(handle);
    if (entry != null) {
      try {
        entry.circle.radius = entry.baseRadius;
      } catch (_) {
        // Circle may already be removed; safe to ignore.
      }
    }
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

    for (final _AnimatedCircle entry in _active.values) {
      // Sine wave between min/max — phase chosen so t=0 sits at the midpoint
      // climbing toward max, giving a natural "breathe out" first.
      final double t =
          (elapsedMs % entry.animation.periodMs) / entry.animation.periodMs;
      final double s = 0.5 - 0.5 * math.cos(2 * math.pi * t);
      final double pct = entry.animation.minRadiusPercent +
          (entry.animation.maxRadiusPercent -
                  entry.animation.minRadiusPercent) *
              s;
      entry.circle.radius = entry.baseRadius * pct / 100.0;
    }

    if (_active.isNotEmpty) {
      _rafId = web.window.requestAnimationFrame(_tick.toJS);
    }
  }
}

class _AnimatedCircle {
  _AnimatedCircle({
    required this.circle,
    required this.animation,
    required this.baseRadius,
  });

  final gmaps.Circle circle;
  final WebCircleAnimation animation;
  final double baseRadius;
}
