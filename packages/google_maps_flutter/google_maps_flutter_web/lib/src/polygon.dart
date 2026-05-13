// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// The `PolygonController` class wraps a [gmaps.Polygon] and its `onTap` behavior.
class PolygonController {
  /// Creates a `PolygonController` that wraps a [gmaps.Polygon] object and its `onTap` behavior.
  PolygonController({
    required gmaps.Polygon polygon,
    bool consumeTapEvents = false,
    VoidCallback? onTap,
    VoidCallback? onEnter,
    VoidCallback? onExit,
  })  : _polygon = polygon,
        _consumeTapEvents = consumeTapEvents,
        _animationHandle = 0 {
    if (onTap != null) {
      polygon.onClick.listen((gmaps.PolyMouseEvent event) {
        onTap.call();
      });
    }
    if (onEnter != null){
      polygon.onMouseover.listen((gmaps.PolyMouseEvent event){
        onEnter.call();
      });
    }
    if (onExit != null){
      polygon.onMouseout.listen((gmaps.PolyMouseEvent event){
        onExit.call();
      });
    }
  }

  gmaps.Polygon? _polygon;

  final bool _consumeTapEvents;

  int _animationHandle;

  _PolygonShapeOverlay? _overlay;

  /// Registers (or replaces) an SVG overlay (gradient/pattern fill + stroke
  /// + glow) on this polygon. The underlying gmaps polygon becomes
  /// transparent (handled in [_polygonOptionsFromPolygon]) so the SVG
  /// carries the visuals; hit testing is unchanged.
  void setOverlay(
    WebPolygonOverlay? webOverlay,
    List<LatLng> points,
    List<List<LatLng>> holes,
    double strokeWidth,
    int zIndex,
    gmaps.Map map,
  ) {
    if (webOverlay == null) {
      _overlay?.detach();
      _overlay = null;
      return;
    }
    final _PolygonShapeOverlay? existing = _overlay;
    if (existing != null &&
        existing.overlay == webOverlay &&
        existing.zIndex == zIndex &&
        existing.strokeWidth == (webOverlay.strokeWidth ?? strokeWidth)) {
      existing.setGeometry(points, holes);
      return;
    }
    existing?.detach();
    final shape = _PolygonShapeOverlay(
      overlay: webOverlay,
      strokeWidth: webOverlay.strokeWidth ?? strokeWidth,
      zIndex: zIndex,
      points: points,
      holes: holes,
    );
    shape.attach(map);
    _overlay = shape;
  }

  /// Registers (or replaces) a colour-cycling animation for this polygon.
  /// Pass null to clear.
  void setAnimation(WebPolygonAnimation? animation) {
    if (_animationHandle != 0) {
      _PolygonAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    final gmaps.Polygon? p = _polygon;
    if (animation == null || p == null) {
      return;
    }
    if (!animation.animatesFill && !animation.animatesStroke) {
      return;
    }
    _animationHandle =
        _PolygonAnimationManager.instance.register(p, animation);
  }

  /// Returns the wrapped [gmaps.Polygon]. Only used for testing.
  @visibleForTesting
  gmaps.Polygon? get polygon => _polygon;

  /// Returns `true` if this Controller will use its own `onTap` handler to consume events.
  bool get consumeTapEvents => _consumeTapEvents;

  /// Updates the options of the wrapped [gmaps.Polygon] object.
  ///
  /// This cannot be called after [remove].
  void update(gmaps.PolygonOptions options) {
    assert(_polygon != null, 'Cannot `update` Polygon after calling `remove`.');
    _polygon!.options = options;
  }

  /// Disposes of the currently wrapped [gmaps.Polygon].
  void remove() {
    if (_animationHandle != 0) {
      _PolygonAnimationManager.instance.unregister(_animationHandle);
      _animationHandle = 0;
    }
    _overlay?.detach();
    _overlay = null;
    if (_polygon != null) {
      _polygon!.visible = false;
      _polygon!.map = null;
      _polygon = null;
    }
  }
}
