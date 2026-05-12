// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../google_maps_flutter_web.dart';

/// The `MarkerController` class wraps a [gmaps.AdvancedMarkerElement]
/// or [gmaps.Marker], how it handles events, and its associated (optional)
/// [gmaps.InfoWindow] widget.
///
/// Type parameters:
/// * [T] - The marker type (e.g., [gmaps.Marker] or [gmaps.AdvancedMarkerElement])
/// * [O] - The options type used to configure the marker
///   (e.g., [gmaps.MarkerOptions] or [gmaps.AdvancedMarkerElementOptions])
abstract class MarkerController<T, O> {
  /// Creates a `MarkerController`, which wraps a [gmaps.AdvancedMarkerElement]
  /// or [gmaps.Marker] object, its `onTap`/`onDrag` behavior, and its
  /// associated [gmaps.InfoWindow].
  MarkerController({
    required T marker,
    gmaps.InfoWindow? infoWindow,
    bool consumeTapEvents = false,
    LatLngCallback? onDragStart,
    LatLngCallback? onDrag,
    LatLngCallback? onDragEnd,
    VoidCallback? onTap,
    ClusterManagerId? clusterManagerId,
    VoidCallback? onEnter,
    VoidCallback? onExit,
  }) : _marker = marker,
       _infoWindow = infoWindow,
       _consumeTapEvents = consumeTapEvents,
       _clusterManagerId = clusterManagerId {
    addMarkerListener(
      marker: marker,
      onDragStart: onDragStart,
      onDrag: onDrag,
      onDragEnd: onDragEnd,
      onTap: onTap,
      onEnter: onEnter,
      onExit: onExit,
    );
  }

  T? _marker;

  final bool _consumeTapEvents;

  final ClusterManagerId? _clusterManagerId;

  final gmaps.InfoWindow? _infoWindow;

  bool _infoWindowShown = false;

  /// Returns `true` if this Controller will use its own `onTap` handler to consume events.
  bool get consumeTapEvents => _consumeTapEvents;

  /// Returns `true` if the [gmaps.InfoWindow] associated to this marker is being shown.
  bool get infoWindowShown => _infoWindowShown;

  /// Returns [ClusterManagerId] if marker belongs to cluster.
  ClusterManagerId? get clusterManagerId => _clusterManagerId;

  /// Returns the marker associated to this controller.
  T? get marker => _marker;

  /// Returns the [gmaps.InfoWindow] associated to the marker.
  @visibleForTesting
  gmaps.InfoWindow? get infoWindow => _infoWindow;

  /// Updates the options of the wrapped marker object.
  ///
  /// This cannot be called after [remove].
  void update(O options, {web.HTMLElement? newInfoWindowContent});

  /// Initializes the listener for the wrapped marker object.
  void addMarkerListener({
    required T marker,
    required LatLngCallback? onDragStart,
    required LatLngCallback? onDrag,
    required LatLngCallback? onDragEnd,
    required VoidCallback? onTap,
    VoidCallback? onEnter,
    VoidCallback? onExit,
  });

  /// Disposes of the currently wrapped marker object.
  void remove();

  /// Hide the associated [gmaps.InfoWindow].
  ///
  /// This cannot be called after [remove].
  void hideInfoWindow() {
    assert(_marker != null, 'Cannot `hideInfoWindow` on a `remove`d Marker.');
    if (_infoWindow != null) {
      _infoWindow.close();
      _infoWindowShown = false;
    }
  }

  /// Show the associated [gmaps.InfoWindow].
  ///
  /// This cannot be called after [remove].
  void showInfoWindow();

  /// Sets the map of the wrapped marker object.
  void setMap(gmaps.Map map);
}

/// A `MarkerController` that wraps a [gmaps.Marker] object.
///
/// [gmaps.Marker] is a legacy class that is being replaced
/// by [gmaps.AdvancedMarkerElement].
class LegacyMarkerController
    extends MarkerController<gmaps.Marker, gmaps.MarkerOptions> {
  /// Creates a `LegacyMarkerController`, which wraps a [gmaps.Marker] object.
  LegacyMarkerController({
    required super.marker,
    super.infoWindow,
    super.consumeTapEvents,
    super.onDragStart,
    super.onDrag,
    super.onDragEnd,
    super.onTap,
    super.clusterManagerId,
    super.onEnter,
    super.onExit,
  });

  /// List of active stream subscriptions for marker events.
  ///
  /// This list keeps track of all event subscriptions created for the marker,
  /// including taps and different drag events.
  /// These subscriptions should be disposed when the controller is disposed.
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  @override
  void addMarkerListener({
    required gmaps.Marker marker,
    required LatLngCallback? onDragStart,
    required LatLngCallback? onDrag,
    required LatLngCallback? onDragEnd,
    required VoidCallback? onTap,
    VoidCallback? onEnter,
    VoidCallback? onExit,
  }) {
    if (onTap != null) {
      _subscriptions.add(
        marker.onClick.listen((gmaps.MapMouseEvent event) {
          onTap.call();
        }),
      );
    }
    if (onDragStart != null) {
      _subscriptions.add(
        marker.onDragstart.listen((gmaps.MapMouseEvent event) {
          marker.position = event.latLng;
          onDragStart.call(event.latLng ?? _nullGmapsLatLng);
        }),
      );
    }
    if (onDrag != null) {
      _subscriptions.add(
        marker.onDrag.listen((gmaps.MapMouseEvent event) {
          marker.position = event.latLng;
          onDrag.call(event.latLng ?? _nullGmapsLatLng);
        }),
      );
    }
    if (onDragEnd != null) {
      _subscriptions.add(
        marker.onDragend.listen((gmaps.MapMouseEvent event) {
          marker.position = event.latLng;
          onDragEnd.call(event.latLng ?? _nullGmapsLatLng);
        }),
      );
    }
    if (onEnter != null) {
      _subscriptions.add(
        marker.onMouseover.listen((gmaps.MapMouseEvent event) {
          onEnter.call();
        }),
      );
    }
    if (onExit != null) {
      _subscriptions.add(
        marker.onMouseout.listen((gmaps.MapMouseEvent event) {
          onExit.call();
        }),
      );
    }
  }

  @override
  void remove() {
    if (_marker != null) {
      _infoWindowShown = false;
      _marker!.label = null;
      _marker!.map = null;
      _marker = null;

      for (final StreamSubscription<dynamic> sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
    }
  }

  @override
  void showInfoWindow() {
    if (_marker == null) {
      throw StateError('Cannot `showInfoWindow` on a `remove`d Marker.');
    }

    if (_infoWindow != null) {
      _infoWindow.open(_marker!.map, _marker);
      _infoWindowShown = true;
    }
  }

  @override
  void update(
    gmaps.MarkerOptions options, {
    web.HTMLElement? newInfoWindowContent,
  }) {
    assert(_marker != null, 'Cannot `update` Marker after calling `remove`.');
    _marker!.options = options;

    if (_infoWindow != null && newInfoWindowContent != null) {
      _infoWindow.content = newInfoWindowContent;
    }
  }

  @override
  void setMap(gmaps.Map map) => _marker?.map = map;
}

/// A `MarkerController` that wraps a [gmaps.AdvancedMarkerElement] object.
///
/// [gmaps.AdvancedMarkerElement] is a new class that is
/// replacing [gmaps.Marker].
class AdvancedMarkerController
    extends
        MarkerController<
          gmaps.AdvancedMarkerElement,
          gmaps.AdvancedMarkerElementOptions
        > {
  /// Creates a `AdvancedMarkerController`, which wraps
  /// a [gmaps.AdvancedMarkerElement] object.
  AdvancedMarkerController({
    required super.marker,
    super.infoWindow,
    super.consumeTapEvents,
    super.onDragStart,
    super.onDrag,
    super.onDragEnd,
    super.onTap,
    super.clusterManagerId,
    super.onEnter,
    super.onExit,
  });

  /// List of active stream subscriptions for marker events.
  ///
  /// This list keeps track of all event subscriptions created for the marker,
  /// including taps and different drag events.
  /// These subscriptions should be disposed when the controller is disposed.
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  @override
  void addMarkerListener({
    required gmaps.AdvancedMarkerElement marker,
    required LatLngCallback? onDragStart,
    required LatLngCallback? onDrag,
    required LatLngCallback? onDragEnd,
    required VoidCallback? onTap,
    VoidCallback? onEnter,
    VoidCallback? onExit,
  }) {
    if (onTap != null) {
      _subscriptions.add(
        marker.onClick.listen((gmaps.MapMouseEvent event) {
          onTap.call();
        }),
      );
    }
    if (onDragStart != null) {
      _subscriptions.add(
        marker.onDragstart.listen((gmaps.MapMouseEvent event) {
          marker.position = event.latLng;
          onDragStart.call(event.latLng ?? _nullGmapsLatLng);
        }),
      );
    }
    if (onDrag != null) {
      _subscriptions.add(
        marker.onDrag.listen((gmaps.MapMouseEvent event) {
          marker.position = event.latLng;
          onDrag.call(event.latLng ?? _nullGmapsLatLng);
        }),
      );
    }
    if (onDragEnd != null) {
      _subscriptions.add(
        marker.onDragend.listen((gmaps.MapMouseEvent event) {
          marker.position = event.latLng;
          onDragEnd.call(event.latLng ?? _nullGmapsLatLng);
        }),
      );
    }
    if (onEnter != null) {
      _subscriptions.add(
        _domEventStream(marker.element, 'mouseenter').listen(
          (_) => onEnter(),
        ),
      );
    }
    if (onExit != null) {
      _subscriptions.add(
        _domEventStream(marker.element, 'mouseleave').listen(
          (_) => onExit(),
        ),
      );
    }
  }

  @override
  void remove() {
    if (_marker != null) {
      _infoWindowShown = false;

      _marker!.remove();
      _marker!.map = null;
      _marker = null;

      for (final StreamSubscription<dynamic> sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
    }
  }

  @override
  void showInfoWindow() {
    if (_marker == null) {
      throw StateError('Cannot `showInfoWindow` on a `remove`d Marker.');
    }

    if (_infoWindow != null) {
      _infoWindow.open(_marker!.map, _marker);
      _infoWindowShown = true;
    }
  }

  @override
  void update(
    gmaps.AdvancedMarkerElementOptions options, {
    web.HTMLElement? newInfoWindowContent,
  }) {
    assert(_marker != null, 'Cannot `update` Marker after calling `remove`.');

    final gmaps.AdvancedMarkerElement marker = _marker!;
    marker.collisionBehavior = options.collisionBehavior;
    marker.content = options.content;
    marker.gmpDraggable = options.gmpDraggable;
    marker.position = options.position;
    marker.title = options.title ?? '';
    marker.zIndex = options.zIndex;

    if (_infoWindow != null && newInfoWindowContent != null) {
      _infoWindow.content = newInfoWindowContent;
    }
  }

  @override
  void setMap(gmaps.Map map) => _marker?.map = map;
}

Stream<web.Event> _domEventStream(web.HTMLElement element, String eventType) {
  late StreamController<web.Event> controller;
  late JSFunction handler;
  controller = StreamController<web.Event>(
    onListen: () {
      handler = ((web.Event event) => controller.add(event)).toJS;
      element.addEventListener(eventType, handler);
    },
    onCancel: () {
      element.removeEventListener(eventType, handler);
    },
  );
  return controller.stream;
}
