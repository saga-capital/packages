// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// The `PolygonController` class wraps a [gmaps.Polyline] and its `onTap` behavior.
class PolylineController {
  /// Creates a `PolylineController` that wraps a [gmaps.Polyline] object and its `onTap` behavior.
  PolylineController({
    required gmaps.Polyline polyline,
    bool consumeTapEvents = false,
    VoidCallback? onTap,
    LatLngCallback? onMouseOver,
    LatLngCallback? onMouseOut,
  }) : _polyline = polyline,
       _consumeTapEvents = consumeTapEvents,
       _animationHandle = 0 {
    if (onTap != null) {
      polyline.onClick.listen((gmaps.PolyMouseEvent event) {
        onTap.call();
      });
    }
    if(onMouseOver != null) {
      polyline.onMouseover.listen((gmaps.PolyMouseEvent event) {
        onMouseOver.call(event.latLng ?? _nullGmapsLatLng);
      });
    }
    if(onMouseOut != null) {
      polyline.onMouseout.listen((gmaps.PolyMouseEvent event) {
        onMouseOut.call(event.latLng ?? _nullGmapsLatLng);
      });
    }
  }

  gmaps.Polyline? _polyline;

  final bool _consumeTapEvents;

  int _animationHandle;

  /// Registers (or replaces) a flowing-symbol animation for this polyline.
  /// Pass null to clear.
  void setAnimation(WebPolylineAnimation? animation, Color polylineColor) {
    if (_animationHandle != 0) {
      _PolylineAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    final poly = _polyline;
    if (animation == null || poly == null) {
      return;
    }
    _animationHandle = _PolylineAnimationManager.instance.register(
      poly,
      animation,
      polylineColor,
    );
  }

  /// Returns the wrapped [gmaps.Polyline]. Only used for testing.
  @visibleForTesting
  gmaps.Polyline? get line => _polyline;

  /// Returns `true` if this Controller will use its own `onTap` handler to consume events.
  bool get consumeTapEvents => _consumeTapEvents;

  /// Updates the options of the wrapped [gmaps.Polyline] object.
  ///
  /// This cannot be called after [remove].
  void update(gmaps.PolylineOptions options) {
    assert(
      _polyline != null,
      'Cannot `update` Polyline after calling `remove`.',
    );
    _polyline!.options = options;
  }

  /// Disposes of the currently wrapped [gmaps.Polyline].
  void remove() {
    if (_animationHandle != 0) {
      _PolylineAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    if (_polyline != null) {
      _polyline!.visible = false;
      _polyline!.map = null;
      _polyline = null;
    }
  }
}
