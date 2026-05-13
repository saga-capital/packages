// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// This class manages a set of [PolylinesController]s associated to a [GoogleMapController].
class PolylinesController extends GeometryController {
  /// Initializes the cache. The [StreamController] comes from the [GoogleMapController], and is shared with other controllers.
  PolylinesController({required StreamController<MapEvent<Object?>> stream})
    : _streamController = stream,
      _polylineIdToController = <PolylineId, PolylineController>{};

  // A cache of [PolylineController]s indexed by their [PolylineId].
  final Map<PolylineId, PolylineController> _polylineIdToController;

  // The stream over which polylines broadcast their events
  final StreamController<MapEvent<Object?>> _streamController;

  /// Returns the cache of [PolylineContrller]s. Test only.
  @visibleForTesting
  Map<PolylineId, PolylineController> get lines => _polylineIdToController;

  /// Adds a set of [Polyline] objects to the cache.
  ///
  /// Wraps each line into its corresponding [PolylineController].
  void addPolylines(Set<Polyline> polylinesToAdd) {
    polylinesToAdd.forEach(_addPolyline);
  }

  void _addPolyline(Polyline polyline) {
    final gmaps.PolylineOptions polylineOptions = _polylineOptionsFromPolyline(
      googleMap,
      polyline,
    );
    final gmPolyline = gmaps.Polyline(polylineOptions)..map = googleMap;
    final controller = PolylineController(
      polyline: gmPolyline,
      points: polyline.points,
      consumeTapEvents: polyline.consumeTapEvents,
      onTap: () {
        _onPolylineTap(polyline.polylineId);
      },
      onMouseOver: (gmaps.LatLng latLng) {
        _onPolylineMouseOver(polyline.polylineId, latLng);
      },
      onMouseOut: (gmaps.LatLng latLng) {
        _onPolylineMouseOut(polyline.polylineId, latLng);
      },
      onMouseOverEdge: (LatLng pos, int segmentIndex) {
        _onPolylineMouseOverEdge(polyline.polylineId, pos, segmentIndex);
      },
      onMouseOutEdge: (LatLng pos, int segmentIndex) {
        _onPolylineMouseOutEdge(polyline.polylineId, pos, segmentIndex);
      },
    );
    controller.setAnimation(polyline.webAnimation, polyline.color);
    controller.setGradient(
      polyline.webGradient,
      polyline.points,
      polyline.width.toDouble(),
      polyline.zIndex,
      googleMap,
    );
    _polylineIdToController[polyline.polylineId] = controller;
  }

  /// Updates a set of [Polyline] objects with new options.
  void changePolylines(Set<Polyline> polylinesToChange) {
    polylinesToChange.forEach(_changePolyline);
  }

  void _changePolyline(Polyline polyline) {
    final PolylineController? polylineController =
        _polylineIdToController[polyline.polylineId];
    polylineController?.update(
      _polylineOptionsFromPolyline(googleMap, polyline),
    );
    polylineController?.setPoints(polyline.points);
    polylineController?.setAnimation(polyline.webAnimation, polyline.color);
    polylineController?.setGradient(
      polyline.webGradient,
      polyline.points,
      polyline.width.toDouble(),
      polyline.zIndex,
      googleMap,
    );
  }

  /// Removes a set of [PolylineId]s from the cache.
  void removePolylines(Set<PolylineId> polylineIdsToRemove) {
    polylineIdsToRemove.forEach(_removePolyline);
  }

  // Removes a polyline and its controller by its [PolylineId].
  void _removePolyline(PolylineId polylineId) {
    final PolylineController? polylineController =
        _polylineIdToController[polylineId];
    polylineController?.remove();
    _polylineIdToController.remove(polylineId);
  }

  // Handle internal events

  bool _onPolylineTap(PolylineId polylineId) {
    // Have you ended here on your debugging? Is this wrong?
    // Comment here: https://github.com/flutter/flutter/issues/64084
    _streamController.add(PolylineTapEvent(mapId, polylineId));
    return _polylineIdToController[polylineId]?.consumeTapEvents ?? false;
  }

  void _onPolylineMouseOver(PolylineId polylineId, gmaps.LatLng latLng) {
    _streamController.add(PolylineOverEvent(mapId, gmLatLngToLatLng(latLng), polylineId));
  }

  void _onPolylineMouseOut(PolylineId polylineId, gmaps.LatLng latLng) {
    _streamController.add(PolylineOutEvent(mapId, gmLatLngToLatLng(latLng), polylineId));
  }

  void _onPolylineMouseOverEdge(
    PolylineId polylineId,
    LatLng position,
    int segmentIndex,
  ) {
    _streamController.add(
      PolylineEdgeOverEvent(mapId, position, polylineId, segmentIndex),
    );
  }

  void _onPolylineMouseOutEdge(
    PolylineId polylineId,
    LatLng position,
    int segmentIndex,
  ) {
    _streamController.add(
      PolylineEdgeOutEvent(mapId, position, polylineId, segmentIndex),
    );
  }
}
