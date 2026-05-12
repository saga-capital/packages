// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Demonstrates the fork-specific marker features:
///   * Legacy API (Marker)        — markerLabel, animate, onEnter/onExit
///   * New API (AdvancedMarker)   — webOverlay { label, badge, className }
///
/// Toggle the switch in the app bar to compare the two paths on the same map.
/// Note: the AdvancedMarker tab requires a [mapId] (provided via constructor).
class ForkMarkerFeaturesPage extends GoogleMapExampleAppPage {
  const ForkMarkerFeaturesPage({super.key, required this.mapId})
    : super(const Icon(Icons.label_important), 'Fork: marker label & hover');

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _ForkMarkerFeaturesBody(mapId: mapId);
  }
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
  static const List<({String id, LatLng pos, String name, int unread})>
  _drivers = <({String id, LatLng pos, String name, int unread})>[
    (id: 'd1', pos: LatLng(59.9245, 10.7591), name: 'FD-1', unread: 0),
    (id: 'd2', pos: LatLng(59.9127, 10.7461), name: 'FD-2', unread: 3),
    (id: 'd3', pos: LatLng(59.9171, 10.7674), name: 'FD-3', unread: 1),
    (id: 'd4', pos: LatLng(59.9080, 10.7522), name: 'FD-4', unread: 0),
  ];

  bool _useAdvanced = false;
  MarkerId? _hoveredId;
  MarkerId? _selectedId;

  // -- Legacy fork API --------------------------------------------------------
  // Marker.markerLabel renders text directly on the gmaps.Marker via
  // _markerLabelFromMarker (web only — mobile bakes label into the icon
  // BitmapDescriptor). animate=true triggers Animation.BOUNCE (web only).
  // onEnter/onExit fire DOM mouseover/mouseout on the marker glyph.
  Set<Marker> _buildLegacyMarkers() {
    return _drivers.map((driver) {
      final id = MarkerId(driver.id);
      final isHover = _hoveredId == id;
      final isSelected = _selectedId == id;
      return Marker(
        markerId: id,
        position: driver.pos,
        markerLabel: MarkerLabel(
          text: '${driver.name}${driver.unread > 0 ? " (${driver.unread})" : ""}',
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

  // -- New API ---------------------------------------------------------------
  // AdvancedMarker.icon stays plain — the app's bitmap cache stays warm
  // because the label text isn't part of the icon's key. The label lives in
  // DOM via webOverlay, mutating textContent only. The className composes
  // hover/selected state without rebuilding the icon. Mobile ignores
  // webOverlay; app would still bake label into icon for mobile rendering.
  Set<Marker> _buildAdvancedMarkers() {
    return _drivers.map((driver) {
      final id = MarkerId(driver.id);
      final isSelected = _selectedId == id;
      return AdvancedMarker(
        markerId: id,
        position: driver.pos,
        webOverlay: WebMarkerOverlay(
          label: WebMarkerLabel(
            text: driver.name,
            color: Colors.white,
            fontSize: '12px',
            fontWeight: '600',
          ),
          badge: driver.unread > 0
              ? WebMarkerBadge(
                  text: driver.unread.toString(),
                  color: Colors.red,
                )
              : null,
          className:
              'fd-driver-pin${isSelected ? " is-selected" : ""}',
        ),
        onTap: () => setState(() => _selectedId = id),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final canUseAdvanced = widget.mapId != null;
    final Set<Marker> markers = _useAdvanced
        ? _buildAdvancedMarkers()
        : _buildLegacyMarkers();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              const Text('Legacy fork Marker  '),
              Switch(
                value: _useAdvanced,
                onChanged: canUseAdvanced
                    ? (bool v) => setState(() {
                        _useAdvanced = v;
                        _hoveredId = null;
                      })
                    : null,
              ),
              const Text('  AdvancedMarker + webOverlay'),
              if (!canUseAdvanced) ...<Widget>[
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Set _mapId in main.dart to enable',
                  child: Icon(Icons.info_outline, size: 18),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: GoogleMap(
            mapId: _useAdvanced ? widget.mapId : null,
            markerType: _useAdvanced
                ? GoogleMapMarkerType.advancedMarker
                : GoogleMapMarkerType.marker,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 13,
            ),
            markers: markers,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _useAdvanced
                ? 'AdvancedMarker: hover via CSS (.fd-driver-pin:hover { ... }); '
                      'selection via className flip; badge as DOM span.'
                : 'Legacy Marker: hover via onEnter/onExit; animate=BOUNCE on hover; '
                      'label as gmaps.MarkerLabel.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
