// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Showcases [WebPolylineAnimation] — flowing-symbol overlays on polylines
/// powered by google.maps IconSequence with an RAF-driven offset shift.
///
/// Five polylines cross the Oslo map, each demonstrating a different effect:
///   1. Blue arrows flowing forward at the default speed
///   2. Red double-chevrons flowing fast
///   3. Green dots crawling slowly (live tracking feel)
///   4. Orange dashes flowing BACKWARDS at medium speed
///   5. Purple custom diamond glyph — proves customSvgPath escape hatch
///
/// Controls at the top let you pause all animations, flip directions, and
/// boost speed globally.
class ForkPolylineAnimationPage extends GoogleMapExampleAppPage {
  const ForkPolylineAnimationPage({super.key})
    : super(
        const Icon(Icons.timeline),
        'Fork: animated polylines',
      );

  @override
  Widget build(BuildContext context) {
    return const _ForkPolylineAnimationBody();
  }
}

class _ForkPolylineAnimationBody extends StatefulWidget {
  const _ForkPolylineAnimationBody();

  @override
  State<_ForkPolylineAnimationBody> createState() =>
      _ForkPolylineAnimationBodyState();
}

class _ForkPolylineAnimationBodyState
    extends State<_ForkPolylineAnimationBody> {
  static const LatLng _center = LatLng(59.9139, 10.7522);

  static const List<LatLng> _route1 = <LatLng>[
    LatLng(59.9075, 10.7270),
    LatLng(59.9139, 10.7400),
    LatLng(59.9200, 10.7522),
    LatLng(59.9260, 10.7600),
  ];
  static const List<LatLng> _route2 = <LatLng>[
    LatLng(59.9320, 10.7300),
    LatLng(59.9240, 10.7430),
    LatLng(59.9180, 10.7600),
    LatLng(59.9120, 10.7780),
  ];
  static const List<LatLng> _route3 = <LatLng>[
    LatLng(59.9000, 10.7600),
    LatLng(59.9080, 10.7700),
    LatLng(59.9170, 10.7800),
    LatLng(59.9260, 10.7780),
  ];
  static const List<LatLng> _route4 = <LatLng>[
    LatLng(59.9050, 10.7900),
    LatLng(59.9150, 10.7820),
    LatLng(59.9230, 10.7700),
    LatLng(59.9300, 10.7550),
  ];
  static const List<LatLng> _route5 = <LatLng>[
    LatLng(59.9200, 10.7100),
    LatLng(59.9120, 10.7250),
    LatLng(59.9050, 10.7400),
    LatLng(59.9020, 10.7600),
  ];
  // Long, undulating route used to showcase the SVG gradient overlay.
  static const List<LatLng> _route6 = <LatLng>[
    LatLng(59.8980, 10.7080),
    LatLng(59.9020, 10.7220),
    LatLng(59.9080, 10.7360),
    LatLng(59.9140, 10.7500),
    LatLng(59.9210, 10.7640),
    LatLng(59.9290, 10.7790),
    LatLng(59.9360, 10.7920),
  ];

  bool _running = true;
  bool _reversed = false;
  double _speedMul = 1.0;

  // Hover-segment demo state — set when the cursor enters polyline `p6`'s
  // hit area, cleared on exit. Drives the bright overlay polyline that
  // highlights the closest edge.
  int? _hoveredSegmentIndex;

  WebFlowDirection _dir(WebFlowDirection base) {
    if (!_reversed) {
      return base;
    }
    return base == WebFlowDirection.forward
        ? WebFlowDirection.backward
        : WebFlowDirection.forward;
  }

  WebPolylineAnimation? _maybe(WebPolylineAnimation a) {
    if (!_running) {
      return null;
    }
    return WebPolylineAnimation(
      symbol: a.symbol,
      spacing: a.spacing,
      speedPercentPerSecond: a.speedPercentPerSecond * _speedMul,
      direction: _dir(a.direction),
      color: a.color,
      size: a.size,
      customSvgPath: a.customSvgPath,
      rotation: a.rotation,
    );
  }

  Set<Polyline> _polylines() {
    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('p1'),
        points: _route1,
        color: const Color(0x551E40AF),
        width: 6,
        webAnimation: _maybe(
          const WebPolylineAnimation(
            symbol: WebFlowSymbol.arrow,
            spacing: '40px',
            speedPercentPerSecond: 8,
            size: 4,
            color: Color(0xFF1E40AF),
          ),
        ),
      ),
      Polyline(
        polylineId: const PolylineId('p2'),
        points: _route2,
        color: const Color(0x55B91C1C),
        width: 6,
        webAnimation: _maybe(
          const WebPolylineAnimation(
            symbol: WebFlowSymbol.chevron,
            spacing: '32px',
            speedPercentPerSecond: 18,
            size: 5,
            color: Color(0xFFB91C1C),
          ),
        ),
      ),
      Polyline(
        polylineId: const PolylineId('p3'),
        points: _route3,
        color: const Color(0x55047857),
        width: 6,
        webAnimation: _maybe(
          const WebPolylineAnimation(
            symbol: WebFlowSymbol.dot,
            spacing: '20px',
            speedPercentPerSecond: 4,
            size: 3,
            color: Color(0xFF047857),
          ),
        ),
      ),
      Polyline(
        polylineId: const PolylineId('p4'),
        points: _route4,
        color: const Color(0x55EA580C),
        width: 6,
        webAnimation: _maybe(
          const WebPolylineAnimation(
            symbol: WebFlowSymbol.dash,
            spacing: '28px',
            speedPercentPerSecond: 10,
            direction: WebFlowDirection.backward,
            size: 4,
            color: Color(0xFFEA580C),
          ),
        ),
      ),
      Polyline(
        polylineId: const PolylineId('p5'),
        points: _route5,
        color: const Color(0x557C3AED),
        width: 6,
        webAnimation: _maybe(
          const WebPolylineAnimation(
            // Diamond glyph via customSvgPath — matches WebPatternItem.custom
            // capability for static patterns, but flowing along the path.
            customSvgPath: 'M 0,-1 1,0 0,1 -1,0 Z',
            spacing: '36px',
            speedPercentPerSecond: 6,
            size: 5,
            color: Color(0xFF7C3AED),
          ),
        ),
      ),
      // Gradient stroke demo — SVG OverlayView paints a rainbow along
      // the projected path. The underlying gmaps polyline becomes
      // transparent so the SVG carries the visuals but its hit geometry
      // is unchanged, which is what powers the onMouseOverEdge /
      // onMouseOutEdge callbacks below. Animation slides the stops along
      // the path at ~25% per second with the pattern tiling 4 times
      // across the line for a marching-rainbow effect.
      Polyline(
        polylineId: const PolylineId('p6'),
        points: _route6,
        width: 8,
        color: const Color(0xFF000000),
        zIndex: 5,
        consumeTapEvents: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gradient polyline tapped'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        onMouseOverEdge: (LatLng pos, int idx) {
          if (idx != _hoveredSegmentIndex) {
            setState(() => _hoveredSegmentIndex = idx);
          }
        },
        onMouseOutEdge: (LatLng pos, int idx) {
          if (_hoveredSegmentIndex != null) {
            setState(() => _hoveredSegmentIndex = null);
          }
        },
        webGradient: WebPolylineGradient(
          stops: const <Color>[
            Color(0xFFEF4444),
            Color(0xFFF59E0B),
            Color(0xFF10B981),
            Color(0xFF3B82F6),
            Color(0xFF8B5CF6),
            Color(0xFFEF4444),
          ],
          strokeWidth: 8,
          repeatCount: 4,
          animationSpeedPercentPerSecond: _running ? 25 * _speedMul : null,
        ),
      ),
      // Hover overlay — a separate, thicker, opaque polyline drawn over
      // just the segment closest to the cursor. Built from the same
      // _route6 points so it lines up exactly with the gradient layer
      // beneath it. zIndex above p6 so it visually wins.
      if (_hoveredSegmentIndex != null &&
          _hoveredSegmentIndex! + 1 < _route6.length)
        Polyline(
          polylineId: const PolylineId('p6-hover'),
          points: <LatLng>[
            _route6[_hoveredSegmentIndex!],
            _route6[_hoveredSegmentIndex! + 1],
          ],
          color: const Color(0xFFFFEB3B),
          width: 14,
          zIndex: 6,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => setState(() => _running = !_running),
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pause' : 'Play'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => setState(() => _reversed = !_reversed),
                icon: const Icon(Icons.swap_horiz),
                label: Text(_reversed ? 'Reversed' : 'Forward'),
              ),
              const SizedBox(width: 12),
              const Text('Speed'),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: Slider(
                  min: 0.25,
                  max: 4.0,
                  divisions: 15,
                  label: '${_speedMul.toStringAsFixed(2)}×',
                  value: _speedMul,
                  onChanged: (double v) => setState(() => _speedMul = v),
                ),
              ),
              Text('${_speedMul.toStringAsFixed(2)}×'),
            ],
          ),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 13,
            ),
            polylines: _polylines(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'arrow · chevron · dot · backward dash · custom diamond glyph '
            '(SVG path)  —  single shared RAF loop, auto-pauses on tab hide',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
