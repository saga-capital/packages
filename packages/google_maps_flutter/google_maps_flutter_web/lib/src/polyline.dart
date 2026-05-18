// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// The `PolygonController` class wraps a [gmaps.Polyline] and its `onTap` behavior.
class PolylineController {
  /// Creates a `PolylineController` that wraps a [gmaps.Polyline] object and its `onTap` behavior.
  PolylineController({
    required gmaps.Polyline polyline,
    required List<LatLng> points,
    bool consumeTapEvents = false,
    VoidCallback? onTap,
    LatLngCallback? onMouseOver,
    LatLngCallback? onMouseOut,
    void Function(LatLng position, int segmentIndex)? onMouseOverEdge,
    void Function(LatLng position, int segmentIndex)? onMouseOutEdge,
  })  : _polyline = polyline,
        _consumeTapEvents = consumeTapEvents,
        _points = points,
        _animationHandle = 0 {
    if (onTap != null) {
      polyline.onClick.listen((gmaps.PolyMouseEvent event) {
        onTap.call();
      });
    }
    if (onMouseOver != null || onMouseOverEdge != null) {
      polyline.onMouseover.listen((gmaps.PolyMouseEvent event) {
        final gmaps.LatLng gm = event.latLng ?? _nullGmapsLatLng;
        onMouseOver?.call(gm);
        if (onMouseOverEdge != null) {
          final LatLng pos = gmLatLngToLatLng(gm);
          onMouseOverEdge(pos, _closestSegmentIndex(_points, pos));
        }
      });
    }
    if (onMouseOut != null || onMouseOutEdge != null) {
      polyline.onMouseout.listen((gmaps.PolyMouseEvent event) {
        final gmaps.LatLng gm = event.latLng ?? _nullGmapsLatLng;
        onMouseOut?.call(gm);
        if (onMouseOutEdge != null) {
          final LatLng pos = gmLatLngToLatLng(gm);
          onMouseOutEdge(pos, _closestSegmentIndex(_points, pos));
        }
      });
    }
  }

  gmaps.Polyline? _polyline;

  final bool _consumeTapEvents;

  // Latest path snapshot — kept in sync via [setPoints] so the closest-edge
  // computation doesn't have to cross the JS bridge on every mouse event.
  List<LatLng> _points;

  /// Replace the cached path used for edge index computation.
  void setPoints(List<LatLng> points) {
    _points = points;
  }

  int _animationHandle;

  _PolylineGradientOverlay? _gradient;

  /// Registers (or replaces) a gradient stroke overlay on this polyline.
  /// When [gradient] is set, the underlying gmaps polyline's stroke
  /// becomes transparent so only the SVG layer is visible. When [gradient]
  /// is null the gmaps polyline becomes visible again (caller is expected
  /// to push fresh options via [update]).
  void setGradient(
    WebPolylineGradient? gradient,
    List<LatLng> points,
    double strokeWidth,
    int zIndex,
    gmaps.Map map,
  ) {
    final gmaps.Polyline? p = _polyline;
    if (p == null) {
      return;
    }
    if (gradient == null) {
      _gradient?.detach();
      _gradient = null;
      return;
    }
    final _PolylineGradientOverlay? existing = _gradient;
    if (existing != null &&
        existing.gradient == gradient &&
        existing.zIndex == zIndex) {
      existing.setPoints(points);
      return;
    }
    existing?.detach();
    final overlay = _PolylineGradientOverlay(
      gradient: gradient,
      strokeWidth: gradient.strokeWidth ?? strokeWidth,
      zIndex: zIndex,
      points: points,
    );
    overlay.attach(map);
    _gradient = overlay;
  }

  /// Registers (or replaces) a flowing-symbol animation for this polyline.
  /// Pass null to clear.
  void setAnimation(
    WebPolylineAnimation? animation,
    Color polylineColor, {
    gmaps.Map? map,
  }) {
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
      map: map,
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
    _gradient?.detach();
    _gradient = null;
    if (_polyline != null) {
      _polyline!.visible = false;
      _polyline!.map = null;
      _polyline = null;
    }
  }
}

/// Returns the index of the edge `(points[i], points[i+1])` whose closest
/// point to [cursor] minimises Euclidean distance. Returns `-1` when the
/// path has fewer than two points.
///
/// Longitude is scaled by `cos(latitude)` to correct for distortion at
/// non-equatorial latitudes. Accurate enough for hover hit-tests anywhere
/// except near the poles.
int _closestSegmentIndex(List<LatLng> pts, LatLng cursor) {
  if (pts.length < 2) {
    return -1;
  }
  final double cosLat = math.cos(cursor.latitude * math.pi / 180.0);
  final double px = cursor.longitude * cosLat;
  final double py = cursor.latitude;
  int best = 0;
  double bestD2 = double.infinity;
  for (int i = 0; i < pts.length - 1; i++) {
    final double ax = pts[i].longitude * cosLat;
    final double ay = pts[i].latitude;
    final double bx = pts[i + 1].longitude * cosLat;
    final double by = pts[i + 1].latitude;
    final double dx = bx - ax;
    final double dy = by - ay;
    final double lenSq = dx * dx + dy * dy;
    double t = lenSq == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lenSq;
    if (t < 0) {
      t = 0;
    } else if (t > 1) {
      t = 1;
    }
    final double qx = ax + t * dx;
    final double qy = ay + t * dy;
    final double ex = px - qx;
    final double ey = py - qy;
    final double d2 = ex * ex + ey * ey;
    if (d2 < bestD2) {
      bestD2 = d2;
      best = i;
    }
  }
  return best;
}
