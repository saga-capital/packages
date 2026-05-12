// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

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
    return _drivers.map((driver) {
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
          'Pure-DOM pill cards · status ring · pulse for live · hover lift '
          '· click for gold ring',
      map: GoogleMap(
        mapId: widget.mapId,
        markerType: GoogleMapMarkerType.advancedMarker,
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 13,
        ),
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
