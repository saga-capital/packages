// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web/web.dart' as web;

import 'page.dart';

/// Demonstrates the placement controls on [WebMarkerPortal]:
///
/// * `WebMarkerPortalPlacement.{above,below,left,right}` — forces a side.
/// * `WebMarkerPortalPlacement.auto` — plugin picks the side with the most
///   viewport room and flips when the marker is near an edge.
///
/// Plus the built-in **viewport-edge clamping**: whatever side the plugin
/// settles on, the popup is clamped inside the viewport with the configured
/// `viewportMargin`, so popups never disappear off-screen even when the
/// marker is near a corner.
///
/// The dropdown at the top switches between the five placement modes; the
/// row of markers spans the visible map so the edge-avoidance is visible at
/// the corners.
class ForkMarkerPlacementDemoPage extends GoogleMapExampleAppPage {
  const ForkMarkerPlacementDemoPage({super.key, required this.mapId})
      : super(
          const Icon(Icons.swap_horiz),
          'Fork: marker portal placement',
        );

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _ForkMarkerPlacementDemoBody(mapId: mapId);
  }
}

class _ForkMarkerPlacementDemoBody extends StatefulWidget {
  const _ForkMarkerPlacementDemoBody({required this.mapId});

  final String? mapId;

  @override
  State<_ForkMarkerPlacementDemoBody> createState() =>
      _ForkMarkerPlacementDemoBodyState();
}

class _ForkMarkerPlacementDemoBodyState
    extends State<_ForkMarkerPlacementDemoBody> {
  static const LatLng _center = LatLng(59.9139, 10.7522);

  // Markers spread to all corners + centre so the chosen placement (and
  // edge clamping when `auto`) is visible across the whole viewport.
  static const List<({String id, LatLng pos, String label})> _markers = [
    (id: 'm-nw', pos: LatLng(59.9300, 10.7250), label: 'NW corner'),
    (id: 'm-ne', pos: LatLng(59.9300, 10.7800), label: 'NE corner'),
    (id: 'm-c', pos: LatLng(59.9139, 10.7522), label: 'Centre'),
    (id: 'm-sw', pos: LatLng(59.8980, 10.7250), label: 'SW corner'),
    (id: 'm-se', pos: LatLng(59.8980, 10.7800), label: 'SE corner'),
  ];

  WebMarkerPortalPlacement _placement = WebMarkerPortalPlacement.auto;
  String? _hoveredId;

  void _onHover(String id, bool entering) {
    setState(() {
      _hoveredId = entering ? id : (_hoveredId == id ? null : _hoveredId);
    });
  }

  void Function(Object) _wrapperBridge(String id) {
    return (Object wrapperObj) {
      final wrapper = wrapperObj as web.HTMLElement;
      wrapper.addEventListener(
        'mouseenter',
        ((web.Event _) => _onHover(id, true)).toJS,
      );
      wrapper.addEventListener(
        'mouseleave',
        ((web.Event _) => _onHover(id, false)).toJS,
      );
    };
  }

  String _popupHtml(String label) {
    return "<div class='fd-placement-card__head'>$label</div>"
        "<div class='fd-placement-card__body'>"
        "placement: <code>${_placement.name}</code>"
        '</div>'
        "<div class='fd-placement-card__tail'></div>";
  }

  Set<Marker> _buildMarkers() {
    return _markers.map((m) {
      final bool hovered = _hoveredId == m.id;
      return AdvancedMarker(
        markerId: MarkerId(m.id),
        position: m.pos,
        webOverlay: WebMarkerOverlay(
          label: WebMarkerLabel(
            text: m.label,
            className: 'fd-placement-pill__label',
          ),
          className: 'fd-placement-pill${hovered ? ' is-hovered' : ''}',
          customizeKey: 'pl:${m.id}',
          customize: kIsWeb ? _wrapperBridge(m.id) : null,
          portal: hovered
              ? WebMarkerPortal(
                  html: _popupHtml(m.label),
                  className: 'fd-placement-card',
                  placement: _placement,
                  offset: 12,
                  viewportMargin: 12,
                )
              : null,
        ),
      );
    }).toSet();
  }

  Widget _placementButton(WebMarkerPortalPlacement p) {
    final bool selected = _placement == p;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () => setState(() => _placement = p),
        style: TextButton.styleFrom(
          backgroundColor: selected ? const Color(0xFF1f2937) : null,
          foregroundColor: selected ? Colors.white : null,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(p.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mapId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Set localMapId in lib/local_keys.dart (or pass '
            '--dart-define=GMAPS_MAP_ID=...) to enable this demo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Container(
          color: const Color(0xFFf1f5f9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: <Widget>[
              const Text(
                'Placement:',
                style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 8),
              ...WebMarkerPortalPlacement.values.map(_placementButton),
              const Spacer(),
              const Text(
                'Hover corner markers — auto flips to fit, others clamp at edge',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748b)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GoogleMap(
            mapId: widget.mapId,
            markerType: GoogleMapMarkerType.advancedMarker,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 13,
            ),
            markers: _buildMarkers(),
          ),
        ),
      ],
    );
  }
}
