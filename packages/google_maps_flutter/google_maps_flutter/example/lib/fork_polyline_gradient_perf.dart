// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Stress test for [WebPolylineGradient]: a slider-controllable number of
/// long polylines, each painted as an SVG `<path>` with an animated
/// `<linearGradient>` filling its stroke. Useful for eyeballing how the
/// pure-SVG approach scales relative to gmaps-native polylines.
class ForkPolylineGradientPerfPage extends GoogleMapExampleAppPage {
  const ForkPolylineGradientPerfPage({super.key})
      : super(
          const Icon(Icons.show_chart),
          'Fork: gradient polylines (perf)',
        );

  @override
  Widget build(BuildContext context) {
    return const _ForkPolylineGradientPerfBody();
  }
}

class _ForkPolylineGradientPerfBody extends StatefulWidget {
  const _ForkPolylineGradientPerfBody();

  @override
  State<_ForkPolylineGradientPerfBody> createState() =>
      _ForkPolylineGradientPerfBodyState();
}

class _ForkPolylineGradientPerfBodyState
    extends State<_ForkPolylineGradientPerfBody> {
  static const LatLng _center = LatLng(59.9139, 10.7522);

  // Tunables driven by the on-screen sliders.
  int _count = 40;
  int _pointsPerLine = 80;
  bool _animated = true;
  bool _useGradient = true;

  // Seeded so the test geometry is stable across rebuilds, but a fresh
  // shake mixes in different colours/jitter so the eye can tell that
  // every rebuild actually went through the platform diff.
  int _seed = 1;

  /// Builds [_count] polylines, each with [_pointsPerLine] points sprawled
  /// around [_center]. Hue-shifted gradient stops give every line a
  /// distinct colour ramp.
  Set<Polyline> _build() {
    final Random rng = Random(_seed);
    final Set<Polyline> out = <Polyline>{};
    for (int i = 0; i < _count; i++) {
      // Random walk anchored near the centre, with a per-line direction
      // bias so each polyline is roughly linear rather than a tangle.
      final double dirX = (rng.nextDouble() - 0.5) * 0.0006;
      final double dirY = (rng.nextDouble() - 0.5) * 0.0006;
      double lat = _center.latitude + (rng.nextDouble() - 0.5) * 0.05;
      double lng = _center.longitude + (rng.nextDouble() - 0.5) * 0.05;
      final List<LatLng> pts = <LatLng>[];
      for (int k = 0; k < _pointsPerLine; k++) {
        pts.add(LatLng(lat, lng));
        lat += dirY + (rng.nextDouble() - 0.5) * 0.0004;
        lng += dirX + (rng.nextDouble() - 0.5) * 0.0004;
      }

      // Per-line hue rotation just to make the wall-of-lines visually
      // legible — actual gradient cost is dominated by point count, not
      // colour stop count.
      final double hue = (i * 37) % 360;
      final Color a = _hsl(hue, 0.85, 0.55);
      final Color b = _hsl((hue + 120) % 360, 0.85, 0.55);
      final Color c = _hsl((hue + 240) % 360, 0.85, 0.55);

      out.add(
        Polyline(
          polylineId: PolylineId('p-$i'),
          points: pts,
          width: 4,
          color: _useGradient ? const Color(0xFF000000) : a,
          webGradient: _useGradient
              ? WebPolylineGradient(
                  stops: <Color>[a, b, c, a],
                  strokeWidth: 4,
                  repeatCount: 3,
                  animationSpeedPercentPerSecond: _animated ? 30 : null,
                )
              : null,
        ),
      );
    }
    return out;
  }

  Color _hsl(double h, double s, double l) {
    // Quick HSL -> RGB so we don't add a new dependency. Inputs in 0..1
    // ranges except hue which is 0..360.
    final double c = (1 - (2 * l - 1).abs()) * s;
    final double hp = h / 60.0;
    final double x = c * (1 - (hp.remainder(2) - 1).abs());
    double r;
    double g;
    double b;
    if (hp < 1) {
      r = c;
      g = x;
      b = 0;
    } else if (hp < 2) {
      r = x;
      g = c;
      b = 0;
    } else if (hp < 3) {
      r = 0;
      g = c;
      b = x;
    } else if (hp < 4) {
      r = 0;
      g = x;
      b = c;
    } else if (hp < 5) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    final double m = l - c / 2;
    final int ri = ((r + m) * 255).round().clamp(0, 255);
    final int gi = ((g + m) * 255).round().clamp(0, 255);
    final int bi = ((b + m) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, ri, gi, bi);
  }

  @override
  Widget build(BuildContext context) {
    final Set<Polyline> lines = _build();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _LabeledSlider(
                label: 'Lines',
                value: _count.toDouble(),
                min: 1,
                max: 400,
                divisions: 80,
                onChanged: (double v) => setState(() => _count = v.round()),
                trailing: '$_count',
              ),
              _LabeledSlider(
                label: 'Points / line',
                value: _pointsPerLine.toDouble(),
                min: 2,
                max: 500,
                divisions: 50,
                onChanged: (double v) =>
                    setState(() => _pointsPerLine = v.round()),
                trailing: '$_pointsPerLine',
              ),
              FilterChip(
                label: const Text('Gradient'),
                selected: _useGradient,
                onSelected: (bool v) => setState(() => _useGradient = v),
              ),
              FilterChip(
                label: const Text('Animated'),
                selected: _animated,
                onSelected: (bool v) => setState(() => _animated = v),
              ),
              FilledButton.icon(
                onPressed: () => setState(() => _seed++),
                icon: const Icon(Icons.refresh),
                label: const Text('Shake'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 11,
            ),
            polylines: lines,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${lines.length} polylines · ${_pointsPerLine * lines.length} '
            'total points · ${_useGradient ? "SVG gradient" : "gmaps native"}'
            '${_animated && _useGradient ? " · animated" : ""}',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.trailing,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        SizedBox(
          width: 200,
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
        Text(trailing),
      ],
    );
  }
}
