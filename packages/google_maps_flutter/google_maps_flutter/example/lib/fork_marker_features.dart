// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Side-by-side comparison showcasing the fork-specific marker features.
///
/// Left  — Legacy fork Marker: stuck with the default red Google pin plus a
///         single line of text via markerLabel, optional BOUNCE animation on
///         hover.
/// Right — AdvancedMarker + WebMarkerOverlay: pure-DOM markers shaped, styled,
///         and animated entirely from CSS (see web/fd_marker_styles.css):
///         pill cards with multi-line content, status rings, pulse animation
///         on live drivers, hover lift, click-to-select gold ring.
class ForkMarkerFeaturesPage extends GoogleMapExampleAppPage {
  const ForkMarkerFeaturesPage({super.key, required this.mapId})
    : super(const Icon(Icons.label_important), 'Fork: marker label & hover');

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _ForkMarkerFeaturesBody(mapId: mapId);
  }
}

enum DriverStatus { live, busy, offline }

class _Driver {
  const _Driver({
    required this.id,
    required this.pos,
    required this.name,
    required this.eta,
    required this.status,
    this.unread = 0,
  });
  final String id;
  final LatLng pos;
  final String name;
  final String eta;
  final DriverStatus status;
  final int unread;
}

class _ForkMarkerFeaturesBody extends StatefulWidget {
  const _ForkMarkerFeaturesBody({required this.mapId});

  final String? mapId;

  @override
  State<_ForkMarkerFeaturesBody> createState() =>
      _ForkMarkerFeaturesBodyState();
}

class _ForkMarkerFeaturesBodyState extends State<_ForkMarkerFeaturesBody> {
  static const LatLng _center = LatLng(59.9139, 10.7522);
  static const List<_Driver> _drivers = <_Driver>[
    _Driver(
      id: 'd1',
      pos: LatLng(59.9245, 10.7591),
      name: 'FD-1 Anna',
      eta: '2 min',
      status: DriverStatus.live,
    ),
    _Driver(
      id: 'd2',
      pos: LatLng(59.9127, 10.7461),
      name: 'FD-2 Bjørn',
      eta: '5 min',
      status: DriverStatus.busy,
      unread: 3,
    ),
    _Driver(
      id: 'd3',
      pos: LatLng(59.9171, 10.7674),
      name: 'FD-3 Cassia',
      eta: 'idle',
      status: DriverStatus.offline,
    ),
    _Driver(
      id: 'd4',
      pos: LatLng(59.9080, 10.7522),
      name: 'FD-4 Dag',
      eta: '8 min',
      status: DriverStatus.live,
      unread: 1,
    ),
  ];

  MarkerId? _hoveredId;
  MarkerId? _selectedId;
  double _zoom = 13;
  static const double _zoomLabelThreshold = 13.5;

  static const LatLng _truckPos = LatLng(59.9210, 10.7390);
  static const LatLng _zoomMarkerPos = LatLng(59.9100, 10.7700);

  /// Courier loop — keep id stable so the platform diff calls
  /// `set('position', ...)` on the existing AdvancedMarker rather than
  /// removing + recreating it. Smoothness comes from Flutter rebuild
  /// cadence (Timer.periodic ~60 Hz), not from any native tween.
  static const List<LatLng> _courierRoute = <LatLng>[
    LatLng(59.9165, 10.7480),
    LatLng(59.9205, 10.7560),
    LatLng(59.9180, 10.7660),
    LatLng(59.9120, 10.7620),
    LatLng(59.9110, 10.7510),
  ];
  Timer? _courierTimer;
  int _courierSeg = 0;
  double _courierT = 0;
  LatLng _courierPos = _courierRoute.first;

  @override
  void initState() {
    super.initState();
    _courierTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      _courierT += 0.012;
      if (_courierT >= 1.0) {
        _courierT = 0;
        _courierSeg = (_courierSeg + 1) % _courierRoute.length;
      }
      final LatLng a = _courierRoute[_courierSeg];
      final LatLng b = _courierRoute[(_courierSeg + 1) % _courierRoute.length];
      final double lat = a.latitude + (b.latitude - a.latitude) * _courierT;
      final double lng = a.longitude + (b.longitude - a.longitude) * _courierT;
      setState(() => _courierPos = LatLng(lat, lng));
    });
  }

  @override
  void dispose() {
    _courierTimer?.cancel();
    super.dispose();
  }

  // -- Legacy fork API --------------------------------------------------------
  // What we get: default red Google pin, one line of text below, optional
  // BOUNCE animation. No shapes, no multi-line, no per-driver visual identity.
  Set<Marker> _buildLegacyMarkers() {
    return _drivers.map((driver) {
      final id = MarkerId(driver.id);
      final isHover = _hoveredId == id;
      final isSelected = _selectedId == id;
      return Marker(
        markerId: id,
        position: driver.pos,
        markerLabel: MarkerLabel(
          text: '${driver.name} · ${driver.eta}'
              '${driver.unread > 0 ? " · ${driver.unread}" : ""}',
          color: isSelected ? const Color(0xFFFFD700) : Colors.white,
          fontSize: '12px',
          fontWeight: '600',
        ),
        animate: isHover,
        onEnter: () => setState(() => _hoveredId = id),
        onExit: () =>
            setState(() => _hoveredId = _hoveredId == id ? null : _hoveredId),
        onTap: () => setState(() => _selectedId = id),
      );
    }).toSet();
  }

  // -- New API (pure-DOM) ----------------------------------------------------
  // Each marker is a styled <div> built from a className + label/badge
  // combination. The label slot carries the driver name; the badge slot the
  // unread count. CSS in web/fd_marker_styles.css owns shape, ring, pulse,
  // hover lift, selected ring. No bitmap, no Flutter rebuild on hover.
  Set<Marker> _buildAdvancedMarkers() {
    final Set<Marker> out = _drivers.map((driver) {
      final id = MarkerId(driver.id);
      final isSelected = _selectedId == id;
      final String statusClass = switch (driver.status) {
        DriverStatus.live => 'is-live',
        DriverStatus.busy => 'is-busy',
        DriverStatus.offline => 'is-offline',
      };
      return AdvancedMarker(
        markerId: id,
        position: driver.pos,
        webOverlay: WebMarkerOverlay(
          label: WebMarkerLabel(
            text: '${driver.name}\n${driver.eta}',
            className: 'fd-card__label',
          ),
          badge: driver.unread > 0
              ? WebMarkerBadge(
                  text: driver.unread.toString(),
                  className: 'fd-card__badge',
                )
              : null,
          className:
              'fd-card $statusClass${isSelected ? " is-selected" : ""}',
        ),
        onTap: () => setState(() => _selectedId = id),
      );
    }).toSet();

    // Truck pin — label hidden by default, revealed on hover via CSS transition.
    out.add(
      AdvancedMarker(
        markerId: const MarkerId('truck'),
        position: _truckPos,
        webOverlay: const WebMarkerOverlay(
          label: WebMarkerLabel(
            text: 'Truck 42\nDowntown depot',
            className: 'fd-truck__label',
          ),
          className: 'fd-truck',
        ),
      ),
    );

    // Moving courier — same id every frame, only `position` changes.
    // Appearance varies along the route: per-segment colour/glow class, and a
    // `is-sprint` flag during the second half of each segment.
    final bool sprint = _courierT > 0.5;
    final String segName = switch (_courierSeg) {
      0 => 'seg-violet',
      1 => 'seg-cyan',
      2 => 'seg-amber',
      3 => 'seg-rose',
      _ => 'seg-emerald',
    };
    final String segLabel = switch (_courierSeg) {
      0 => 'Pickup',
      1 => 'En route',
      2 => 'Delivery',
      3 => 'Return',
      _ => 'Standby',
    };
    out.add(
      AdvancedMarker(
        markerId: const MarkerId('courier'),
        position: _courierPos,
        webOverlay: WebMarkerOverlay(
          label: WebMarkerLabel(
            text: 'Courier 7 · $segLabel',
            className: 'fd-courier__label',
          ),
          className:
              'fd-courier fd-courier--$segName${sprint ? ' is-sprint' : ''}',
        ),
      ),
    );

    // Zoom-aware marker — `is-far` toggles label visibility from CSS.
    final bool labelOn = _zoom >= _zoomLabelThreshold;
    out.add(
      AdvancedMarker(
        markerId: const MarkerId('zoom'),
        position: _zoomMarkerPos,
        webOverlay: WebMarkerOverlay(
          label: const WebMarkerLabel(
            text: 'Stop #7\nzoom in to see me',
            className: 'fd-zoom__label',
          ),
          className: 'fd-zoom${labelOn ? '' : ' is-far'}',
        ),
      ),
    );

    return out;
  }

  Widget _legacyPane() {
    return _MapPane(
      title: 'Legacy fork Marker',
      caption:
          'Red pin + single-line markerLabel + BOUNCE animation on hover',
      map: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 13,
        ),
        markers: _buildLegacyMarkers(),
      ),
    );
  }

  Widget _advancedPane() {
    if (widget.mapId == null) {
      return const _MapPane(
        title: 'AdvancedMarker + webOverlay',
        caption: 'Set _mapId in main.dart to enable',
        map: ColoredBox(color: Color(0xFFEEEEEE)),
      );
    }
    return _MapPane(
      title: 'AdvancedMarker + webOverlay',
      caption:
          'Pill cards · pulse · hover lift · gold ring on tap · '
          'truck pin reveals label on hover · zoom-aware label '
          '(z≥${_zoomLabelThreshold.toStringAsFixed(1)}, '
          'now ${_zoom.toStringAsFixed(2)}) · '
          'purple courier loops via Timer.periodic',
      map: GoogleMap(
        mapId: widget.mapId,
        markerType: GoogleMapMarkerType.advancedMarker,
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 13,
        ),
        onCameraMove: (CameraPosition pos) {
          final bool wasOn = _zoom >= _zoomLabelThreshold;
          final bool nowOn = pos.zoom >= _zoomLabelThreshold;
          if (wasOn != nowOn) {
            setState(() => _zoom = pos.zoom);
          } else {
            _zoom = pos.zoom;
          }
        },
        markers: _buildAdvancedMarkers(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: _legacyPane()),
        const VerticalDivider(width: 1),
        Expanded(child: _advancedPane()),
      ],
    );
  }
}

class _MapPane extends StatelessWidget {
  const _MapPane({
    required this.title,
    required this.caption,
    required this.map,
  });

  final String title;
  final String caption;
  final Widget map;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: map),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
