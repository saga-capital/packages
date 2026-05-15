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

/// Side-by-side comparison of three popup placement strategies for advanced
/// markers. The map container has `overflow: hidden` and ancestor transforms
/// — DOM nested inside it cannot escape the map bounds.
///
/// * **Baseline** — popup lives inside the wrapper (added via `customHtml`).
///   When the marker is near the map edge, the popup is clipped.
/// * **Portal** (plugin feature) — `WebMarkerOverlay.portal` mounts a popup
///   on `document.body`. The plugin syncs four CSS custom properties on the
///   portal element each time the map moves (`--fd-marker-x`/`y`/`w`/`h`),
///   so CSS handles the final positioning. `useTopLayer: false`.
/// * **Popover API** (plugin feature) — same `portal` field with
///   `useTopLayer: true` (default). Plugin feature-detects `showPopover()`
///   and places the portal in the browser's top layer — guaranteed to paint
///   above every stacking context. Falls back to plain portal on old
///   browsers.
class ForkMarkerPortalDemoPage extends GoogleMapExampleAppPage {
  const ForkMarkerPortalDemoPage({super.key, required this.mapId})
      : super(
          const Icon(Icons.open_in_new),
          'Fork: marker popups outside map',
        );

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _ForkMarkerPortalDemoBody(mapId: mapId);
  }
}

class _ForkMarkerPortalDemoBody extends StatefulWidget {
  const _ForkMarkerPortalDemoBody({required this.mapId});

  final String? mapId;

  @override
  State<_ForkMarkerPortalDemoBody> createState() =>
      _ForkMarkerPortalDemoBodyState();
}

enum _Mode { baseline, portal, popover }

class _MarkerSpec {
  const _MarkerSpec({
    required this.id,
    required this.pos,
    required this.mode,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final LatLng pos;
  final _Mode mode;
  final String title;
  final String subtitle;
}

class _ForkMarkerPortalDemoBodyState extends State<_ForkMarkerPortalDemoBody> {
  static const LatLng _center = LatLng(59.9120, 10.7530);

  static const List<_MarkerSpec> _markers = <_MarkerSpec>[
    _MarkerSpec(
      id: 'm-baseline',
      pos: LatLng(59.9170, 10.7400),
      mode: _Mode.baseline,
      title: 'Baseline',
      subtitle: 'Popup inside wrapper · clipped by map overflow',
    ),
    _MarkerSpec(
      id: 'm-portal',
      pos: LatLng(59.9170, 10.7530),
      mode: _Mode.portal,
      title: 'Portal',
      subtitle: 'Plugin mounts portal on document.body',
    ),
    _MarkerSpec(
      id: 'm-popover',
      pos: LatLng(59.9170, 10.7660),
      mode: _Mode.popover,
      title: 'Popover API',
      subtitle: 'Plugin places portal in top layer',
    ),
  ];

  String? _hoveredId;

  void _onHover(String id, bool entering) {
    setState(() {
      _hoveredId = entering ? id : (_hoveredId == id ? null : _hoveredId);
    });
  }

  // Wrapper-level customize: attaches mouseenter/leave listeners so the app
  // can toggle `portal` on the hovered marker. Listeners are reattached when
  // the snapshot changes (cheap; no leak — plugin replaces the wrapper, GC
  // collects the old listener).
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

  // Card HTML common to all three strategies. The plugin writes
  // --fd-marker-x/y/w/h on the portal element; the .fd-portal-card class
  // uses those vars to position itself above the marker.
  String _popupHtml(_MarkerSpec m) {
    return "<div class='fd-portal-card__head'>${m.title}</div>"
        "<div class='fd-portal-card__body'>${m.subtitle}</div>"
        "<div class='fd-portal-card__tip'>↑ ${m.title} marker</div>";
  }

  // Baseline: popup rendered as part of customHtml inside the wrapper.
  String _baselineCustomHtml(_MarkerSpec m, bool hovered) {
    if (!hovered) {
      return '';
    }
    return "<div class='fd-portal-card fd-portal-card--inside'>"
        '${_popupHtml(m)}'
        '</div>';
  }

  Set<Marker> _buildMarkers() {
    return _markers.map((_MarkerSpec m) {
      final bool hovered = _hoveredId == m.id;
      final String tone = switch (m.mode) {
        _Mode.baseline => 'tone-grey',
        _Mode.portal => 'tone-violet',
        _Mode.popover => 'tone-emerald',
      };
      WebMarkerPortal? portal;
      String? customHtml;
      switch (m.mode) {
        case _Mode.baseline:
          customHtml = _baselineCustomHtml(m, hovered);
        case _Mode.portal:
          portal = hovered
              ? WebMarkerPortal(
                  html: _popupHtml(m),
                  className: 'fd-portal-card fd-portal-card--portal',
                  useTopLayer: false,
                )
              : null;
        case _Mode.popover:
          portal = hovered
              ? WebMarkerPortal(
                  html: _popupHtml(m),
                  className: 'fd-portal-card fd-portal-card--popover',
                )
              : null;
      }
      return AdvancedMarker(
        markerId: MarkerId(m.id),
        position: m.pos,
        webOverlay: WebMarkerOverlay(
          label: WebMarkerLabel(
            text: m.title,
            className: 'fd-portal-pill__label',
          ),
          className: 'fd-portal-pill $tone${hovered ? ' is-hovered' : ''}',
          customHtml: customHtml,
          customizeKey: 'portal-demo:${m.id}',
          customize: kIsWeb ? _wrapperBridge(m.id) : null,
          portal: portal,
        ),
      );
    }).toSet();
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Text(
            'Hover each marker. Baseline clips at map edge; Portal renders on '
            'document.body; Popover API enters the browser top layer.',
            style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ),
        Expanded(
          child: GoogleMap(
            mapId: widget.mapId,
            markerType: GoogleMapMarkerType.advancedMarker,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 14,
            ),
            markers: _buildMarkers(),
          ),
        ),
      ],
    );
  }
}
