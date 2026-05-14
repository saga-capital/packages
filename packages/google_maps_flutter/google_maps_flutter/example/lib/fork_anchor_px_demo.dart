// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Demonstrates `AdvancedMarker.anchorPx` — the web-only pixel anchor that
/// supersedes the ratio `anchor` and removes the need to keep bitmap
/// dimensions in sync with the CSS wrapper.
///
/// Map is centred at LatLng(0, 0). Two polylines cross there: the equator
/// (lat = 0) and the prime meridian (lng = 0). One AdvancedMarker is shown
/// at a time (toggled by the segmented control above the map). Each variant
/// uses a different `anchorPx`; the coloured dot in the wrapper marks that
/// exact pixel — it must land on the polyline crossing regardless of which
/// corner of the 80×80 wrapper carries it.
///
/// - All — show all three at once (overlapping dots on the crossing).
/// - Centre — `anchorPx: Offset(40, 40)`, red dot.
/// - Top-left — `anchorPx: Offset.zero`, green dot.
/// - Bottom-right — `anchorPx: Offset(80, 80)`, blue dot.
class ForkAnchorPxDemoPage extends GoogleMapExampleAppPage {
  const ForkAnchorPxDemoPage({super.key, required this.mapId})
    : super(
        const Icon(Icons.center_focus_strong),
        'Fork: AdvancedMarker anchorPx',
      );

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _ForkAnchorPxDemoBody(mapId: mapId);
  }
}

enum _AnchorChoice { all, center, topLeft, bottomRight, pin }

class _ForkAnchorPxDemoBody extends StatefulWidget {
  const _ForkAnchorPxDemoBody({required this.mapId});

  final String? mapId;

  @override
  State<_ForkAnchorPxDemoBody> createState() => _ForkAnchorPxDemoBodyState();
}

class _ForkAnchorPxDemoBodyState extends State<_ForkAnchorPxDemoBody> {
  static const LatLng _origin = LatLng(0, 0);

  static const List<LatLng> _equator = <LatLng>[
    LatLng(0, -40),
    LatLng(0, 40),
  ];
  static const List<LatLng> _primeMeridian = <LatLng>[
    LatLng(-40, 0),
    LatLng(40, 0),
  ];

  _AnchorChoice _choice = _AnchorChoice.all;

  Set<Polyline> _buildCrossPolylines() => <Polyline>{
    const Polyline(
      polylineId: PolylineId('equator'),
      points: _equator,
      color: Color(0xFF111827),
      width: 2,
    ),
    const Polyline(
      polylineId: PolylineId('prime-meridian'),
      points: _primeMeridian,
      color: Color(0xFF111827),
      width: 2,
    ),
  };

  AdvancedMarker _centerMarker() => AdvancedMarker(
    markerId: const MarkerId('anchor-center'),
    position: _origin,
    anchorPx: const Offset(40, 40),
    webOverlay: const WebMarkerOverlay(
      className: 'fd-anchor-demo fd-anchor-demo--center',
      label: WebMarkerLabel(
        text: 'center\n(40, 40)',
        className: 'fd-anchor-demo__label',
      ),
    ),
  );

  AdvancedMarker _topLeftMarker() => AdvancedMarker(
    markerId: const MarkerId('anchor-topleft'),
    position: _origin,
    anchorPx: Offset.zero,
    webOverlay: const WebMarkerOverlay(
      className: 'fd-anchor-demo fd-anchor-demo--topleft',
      label: WebMarkerLabel(
        text: 'top-left\n(0, 0)',
        className: 'fd-anchor-demo__label',
      ),
    ),
  );

  AdvancedMarker _bottomRightMarker() => AdvancedMarker(
    markerId: const MarkerId('anchor-bottomright'),
    position: _origin,
    anchorPx: const Offset(80, 80),
    webOverlay: const WebMarkerOverlay(
      className: 'fd-anchor-demo fd-anchor-demo--bottomright',
      label: WebMarkerLabel(
        text: 'bottom-right\n(80, 80)',
        className: 'fd-anchor-demo__label',
      ),
    ),
  );

  // Classic teardrop pin. The wrapper is 36×52: head circle (32×32 inside
  // a 36px slot, top of wrapper) plus a downward-pointing triangle whose
  // tip sits at pixel (18, 52). Setting anchorPx to that pixel makes the
  // tip land exactly on lat/lng — the typical "pin tip = location" idiom.
  AdvancedMarker _pinMarker() => AdvancedMarker(
    markerId: const MarkerId('anchor-pin'),
    position: _origin,
    anchorPx: const Offset(18, 52),
    webOverlay: const WebMarkerOverlay(
      className: 'fd-anchor-pin',
    ),
  );

  Set<Marker> _buildAnchorMarkers() {
    switch (_choice) {
      case _AnchorChoice.all:
        return <Marker>{
          _centerMarker(),
          _topLeftMarker(),
          _bottomRightMarker(),
          _pinMarker(),
        };
      case _AnchorChoice.center:
        return <Marker>{_centerMarker()};
      case _AnchorChoice.topLeft:
        return <Marker>{_topLeftMarker()};
      case _AnchorChoice.bottomRight:
        return <Marker>{_bottomRightMarker()};
      case _AnchorChoice.pin:
        return <Marker>{_pinMarker()};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mapId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Set localMapId in lib/local_keys.dart (Vector Map ID) to '
            'enable this demo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: SegmentedButton<_AnchorChoice>(
              segments: const <ButtonSegment<_AnchorChoice>>[
                ButtonSegment<_AnchorChoice>(
                  value: _AnchorChoice.all,
                  label: Text('All'),
                ),
                ButtonSegment<_AnchorChoice>(
                  value: _AnchorChoice.center,
                  label: Text('Center'),
                ),
                ButtonSegment<_AnchorChoice>(
                  value: _AnchorChoice.topLeft,
                  label: Text('Top-left'),
                ),
                ButtonSegment<_AnchorChoice>(
                  value: _AnchorChoice.bottomRight,
                  label: Text('Bottom-right'),
                ),
                ButtonSegment<_AnchorChoice>(
                  value: _AnchorChoice.pin,
                  label: Text('Pin'),
                ),
              ],
              selected: <_AnchorChoice>{_choice},
              onSelectionChanged: (Set<_AnchorChoice> next) {
                setState(() => _choice = next.first);
              },
            ),
          ),
        ),
        Expanded(
          child: GoogleMap(
            mapId: widget.mapId,
            markerType: GoogleMapMarkerType.advancedMarker,
            initialCameraPosition: const CameraPosition(
              target: _origin,
              zoom: 3,
            ),
            markers: _buildAnchorMarkers(),
            polylines: _buildCrossPolylines(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Equator and prime meridian cross at LatLng(0, 0). Each 80×80 '
            'marker carries a different anchorPx; the coloured dot painted '
            'at that pixel sits on the intersection. Toggle one marker at a '
            'time to inspect.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
