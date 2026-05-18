// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Demonstrates `WebPolylineGradient.dashArray` +
/// `dashOffsetSpeedPxPerSecond` — true SVG `stroke-dasharray` with an
/// animated `stroke-dashoffset` so dashes follow polyline curves natively.
///
/// Unlike `animationSpeedPercentPerSecond` (which slides the gradient
/// along a straight start→end axis), dash offset is computed in arc length
/// by the browser. On a curved path the dashes flow around bends instead
/// of straight-lining across them.
///
/// Four parallel polylines show different dash configurations side-by-side:
/// solid (no dashes), dashed-static, dashed-forward, dashed-backward.
class ForkPolylineDashDemoPage extends GoogleMapExampleAppPage {
  const ForkPolylineDashDemoPage({super.key})
      : super(
          const Icon(Icons.linear_scale),
          'Fork: polyline dashed flow',
        );

  @override
  Widget build(BuildContext context) {
    return const _Body();
  }
}

class _Body extends StatelessWidget {
  const _Body();

  // A meandering path so the curve following is obvious.
  static const List<LatLng> _basePts = <LatLng>[
    LatLng(59.9100, 10.7300),
    LatLng(59.9150, 10.7400),
    LatLng(59.9110, 10.7500),
    LatLng(59.9170, 10.7600),
    LatLng(59.9130, 10.7700),
    LatLng(59.9180, 10.7800),
  ];

  /// Returns _basePts shifted south by `i * stepDeg` so the four variants
  /// stack as parallel rows.
  List<LatLng> _shifted(int i) {
    const double stepDeg = -0.004;
    return _basePts
        .map((p) => LatLng(p.latitude + stepDeg * i, p.longitude))
        .toList();
  }

  static const Color _a = Color(0xFFf472b6);
  static const Color _b = Color(0xFF60a5fa);
  static const Color _c = Color(0xFF34d399);

  Set<Polyline> _build() {
    final variants = <(String, WebPolylineGradient)>[
      (
        'solid',
        const WebPolylineGradient(
          stops: <Color>[_a, _b, _c, _a],
          strokeWidth: 6,
          repeatCount: 2,
        ),
      ),
      (
        'dashed-static',
        const WebPolylineGradient(
          stops: <Color>[_a, _b, _c, _a],
          strokeWidth: 6,
          repeatCount: 2,
          dashArray: <double>[14, 10],
        ),
      ),
      (
        'dashed-forward (+60 px/s)',
        const WebPolylineGradient(
          stops: <Color>[_a, _b, _c, _a],
          strokeWidth: 6,
          repeatCount: 2,
          dashArray: <double>[14, 10],
          dashOffsetSpeedPxPerSecond: 60,
        ),
      ),
      (
        'dashed-backward (−60 px/s)',
        const WebPolylineGradient(
          stops: <Color>[_a, _b, _c, _a],
          strokeWidth: 6,
          repeatCount: 2,
          dashArray: <double>[14, 10],
          dashOffsetSpeedPxPerSecond: -60,
        ),
      ),
    ];
    final out = <Polyline>{};
    for (int i = 0; i < variants.length; i++) {
      out.add(
        Polyline(
          polylineId: PolylineId('dash-$i'),
          points: _shifted(i),
          width: 6,
          color: const Color(0xFF000000),
          webGradient: variants[i].$2,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          color: const Color(0xFFf1f5f9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Text(
            'Top → bottom: solid, dashed-static, dashed-forward, dashed-backward. '
            'Dashes follow the curve (arc-length offset), unlike gradient slide '
            'which moves along the start→end axis.',
            style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(59.9090, 10.7550),
              zoom: 13,
            ),
            polylines: _build(),
          ),
        ),
      ],
    );
  }
}
