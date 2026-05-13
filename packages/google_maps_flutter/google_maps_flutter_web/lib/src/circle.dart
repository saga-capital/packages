// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// The `CircleController` class wraps a [gmaps.Circle] and its `onTap` behavior.
class CircleController {
  /// Creates a `CircleController`, which wraps a [gmaps.Circle] object and its `onTap` behavior.
  CircleController({
    required gmaps.Circle circle,
    bool consumeTapEvents = false,
    VoidCallback? onTap,
    VoidCallback? onEnter,
    VoidCallback? onExit,
  })  : _circle = circle,
        _consumeTapEvents = consumeTapEvents,
        _animationHandle = 0 {
    if (onTap != null) {
      _subscriptions.add(circle.onClick.listen((_) => onTap.call()));
    }
    if (onEnter != null) {
      _subscriptions.add(circle.onMouseover.listen((_) => onEnter.call()));
    }
    if (onExit != null) {
      _subscriptions.add(circle.onMouseout.listen((_) => onExit.call()));
    }
  }

  gmaps.Circle? _circle;

  final bool _consumeTapEvents;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  int _animationHandle;

  /// Registers (or replaces) a breathing-radius animation for this circle.
  /// Pass null to clear.
  void setAnimation(WebCircleAnimation? animation, double baseRadius) {
    if (_animationHandle != 0) {
      _CircleAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    final gmaps.Circle? c = _circle;
    if (animation == null || c == null || baseRadius <= 0) {
      return;
    }
    _animationHandle =
        _CircleAnimationManager.instance.register(c, animation, baseRadius);
  }

  /// Returns the wrapped [gmaps.Circle]. Only used for testing.
  @visibleForTesting
  gmaps.Circle? get circle => _circle;

  /// Returns `true` if this Controller will use its own `onTap` handler to consume events.
  bool get consumeTapEvents => _consumeTapEvents;

  /// Updates the options of the wrapped [gmaps.Circle] object.
  ///
  /// This cannot be called after [remove].
  void update(gmaps.CircleOptions options) {
    assert(_circle != null, 'Cannot `update` Circle after calling `remove`.');
    _circle!.options = options;
  }

  /// Disposes of the currently wrapped [gmaps.Circle].
  void remove() {
    if (_animationHandle != 0) {
      _CircleAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    if (_circle != null) {
      _circle!.visible = false;
      _circle!.radius = 0;
      _circle!.map = null;
      _circle = null;
    }
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
