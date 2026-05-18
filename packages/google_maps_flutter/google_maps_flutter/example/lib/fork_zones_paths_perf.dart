// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

/// Stress test combining animated zones, animated paths, and a dense layer
/// of `WebMarkerOverlay` custom-HTML advanced markers on the same map.
///
/// Each "zone" is a [Polygon] rendered as an SVG `<path>` with a
/// [WebGradientPaint] fill that slides along its own axis. Each "path" is a
/// [Polyline] rendered with [WebPolylineGradient]'s `dashArray` + animated
/// `dashOffsetSpeedPxPerSecond` so the dashes follow the polyline's curves.
/// Each "marker" is an [AdvancedMarker] with a [WebMarkerOverlay.customHtml]
/// payload (label + svg glyph) — the per-marker DOM cost typical of
/// real app workloads.
///
/// Toggles per category isolate cost: animate one channel only, animate
/// both, drop a category entirely, or freeze everything to see the
/// static-overhead baseline. The FPS meter is driven by a Flutter [Ticker]
/// independent of the map, so its updates don't add to the workload being
/// measured.
class ForkZonesPathsPerfPage extends GoogleMapExampleAppPage {
  const ForkZonesPathsPerfPage({super.key, required this.mapId})
      : super(
          const Icon(Icons.speed),
          'Fork: zones + paths + markers perf',
        );

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _Body(mapId: mapId);
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.mapId});

  final String? mapId;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  static const LatLng _center = LatLng(59.9139, 10.7522);

  int _count = 100;
  int _markerCount = 500;
  bool _zonesOn = true;
  bool _pathsOn = true;
  bool _markersOn = true;
  bool _animateZones = true;
  bool _animatePaths = true;
  int _seed = 1;
  // Most recently hovered path (set by gmaps onMouseOver, cleared by
  // onMouseOut). Used by `_buildPaths` to bump the matching polyline's
  // stroke width — confirms hover events fire even on animated, gradient-
  // stroked, dashed paths.
  String? _hoveredPathId;

  // ---- Geometry generation -------------------------------------------------

  /// One random pentagon around a centre offset from [_center].
  List<LatLng> _pentagon(Random rng, int index) {
    final double clat =
        _center.latitude + (rng.nextDouble() - 0.5) * 0.06;
    final double clng =
        _center.longitude + (rng.nextDouble() - 0.5) * 0.06;
    final double rad = 0.0015 + rng.nextDouble() * 0.0025;
    final double phase = rng.nextDouble() * pi * 2;
    return List<LatLng>.generate(5, (int i) {
      final double a = phase + i * 2 * pi / 5;
      return LatLng(clat + sin(a) * rad, clng + cos(a) * rad);
    });
  }

  /// One meandering polyline with [pointsPerLine] points.
  List<LatLng> _meander(Random rng, int pointsPerLine) {
    final double dirLat = (rng.nextDouble() - 0.5) * 0.0008;
    final double dirLng = (rng.nextDouble() - 0.5) * 0.0008;
    double lat = _center.latitude + (rng.nextDouble() - 0.5) * 0.06;
    double lng = _center.longitude + (rng.nextDouble() - 0.5) * 0.06;
    final List<LatLng> pts = <LatLng>[];
    for (int k = 0; k < pointsPerLine; k++) {
      pts.add(LatLng(lat, lng));
      lat += dirLat + (rng.nextDouble() - 0.5) * 0.0005;
      lng += dirLng + (rng.nextDouble() - 0.5) * 0.0005;
    }
    return pts;
  }

  Color _hsl(double h, double s, double l) {
    final double c = (1 - (2 * l - 1).abs()) * s;
    final double hp = h / 60.0;
    final double x = c * (1 - (hp.remainder(2) - 1).abs());
    double r;
    double g;
    double b;
    if (hp < 1) {
      r = c; g = x; b = 0;
    } else if (hp < 2) {
      r = x; g = c; b = 0;
    } else if (hp < 3) {
      r = 0; g = c; b = x;
    } else if (hp < 4) {
      r = 0; g = x; b = c;
    } else if (hp < 5) {
      r = x; g = 0; b = c;
    } else {
      r = c; g = 0; b = x;
    }
    final double m = l - c / 2;
    int to255(double v) => ((v + m).clamp(0, 1) * 255).round();
    return Color.fromARGB(255, to255(r), to255(g), to255(b));
  }

  // ---- Build sets ----------------------------------------------------------

  Set<Polygon> _buildZones() {
    if (!_zonesOn) {
      return const <Polygon>{};
    }
    final Random rng = Random(_seed);
    final Set<Polygon> out = <Polygon>{};
    for (int i = 0; i < _count; i++) {
      final double hue = (i * 37) % 360;
      final Color a = _hsl(hue, 0.85, 0.55);
      final Color b = _hsl((hue + 60) % 360, 0.85, 0.45);
      out.add(
        Polygon(
          polygonId: PolygonId('z-$i'),
          points: _pentagon(rng, i),
          strokeWidth: 1,
          strokeColor: const Color(0xFF0f172a),
          fillColor: a.withAlpha(120),
          webOverlay: WebPolygonOverlay(
            fill: WebGradientPaint.linear(
              stops: <Color>[
                a.withAlpha(180),
                b.withAlpha(180),
                a.withAlpha(180),
              ],
              angleDegrees: hue,
              repeatCount: 2,
              animationSpeedPercentPerSecond: _animateZones ? 25 : null,
            ),
            stroke: WebGradientPaint.linear(
              stops: <Color>[a, b, a],
              angleDegrees: hue,
              repeatCount: 2,
              animationSpeedPercentPerSecond: _animateZones ? 25 : null,
            ),
            strokeWidth: 2,
          ),
        ),
      );
    }
    return out;
  }

  static const String _pinSvg =
      "<svg viewBox='0 0 16 16' width='10' height='10' aria-hidden='true'>"
      "<circle cx='8' cy='8' r='6' fill='white' fill-opacity='0.9'/>"
      '</svg>';

  Set<Marker> _buildMarkers() {
    if (!_markersOn || widget.mapId == null) {
      return const <Marker>{};
    }
    final Random rng = Random(_seed + 1009);
    final Set<Marker> out = <Marker>{};
    for (int i = 0; i < _markerCount; i++) {
      final double lat =
          _center.latitude + (rng.nextDouble() - 0.5) * 0.07;
      final double lng =
          _center.longitude + (rng.nextDouble() - 0.5) * 0.07;
      final double hue = (i * 23) % 360;
      final Color a = _hsl(hue, 0.85, 0.55);
      // Inline-style className so we don't depend on demo-specific CSS.
      final String style =
          "background:${_rgba(a)};color:white;font:600 10px system-ui,"
          "sans-serif;padding:2px 6px;border-radius:9999px;"
          "box-shadow:0 1px 2px rgba(0,0,0,.3);"
          "display:inline-flex;align-items:center;gap:4px;"
          "white-space:nowrap";
      final String html =
          "<span style=\"$style\">"
          "$_pinSvg"
          "<span>M$i</span>"
          '</span>';
      out.add(
        AdvancedMarker(
          markerId: MarkerId('m-$i'),
          position: LatLng(lat, lng),
          webOverlay: WebMarkerOverlay(customHtml: html),
        ),
      );
    }
    return out;
  }

  String _rgba(Color c) =>
      'rgba(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()},${c.a})';

  Set<Polyline> _buildPaths() {
    if (!_pathsOn) {
      return const <Polyline>{};
    }
    final Random rng = Random(_seed + 7919);
    final Set<Polyline> out = <Polyline>{};
    for (int i = 0; i < _count; i++) {
      final String id = 'p-$i';
      final bool hovered = _hoveredPathId == id;
      final double hue = (i * 53) % 360;
      final Color a = _hsl(hue, 0.85, 0.55);
      final Color b = _hsl((hue + 90) % 360, 0.85, 0.5);
      final Color c = _hsl((hue + 200) % 360, 0.85, 0.55);
      final double strokeW = hovered ? 9 : 4;
      out.add(
        Polyline(
          polylineId: PolylineId(id),
          points: _meander(rng, 60),
          // gmaps native polyline stays invisible but keeps the hit
          // geometry, which is what fires the mouseover/mouseout events
          // even though the visible stroke is the SVG overlay above.
          width: 4,
          color: const Color(0xFF000000),
          webGradient: WebPolylineGradient(
            stops: <Color>[a, b, c, a],
            strokeWidth: strokeW,
            repeatCount: 2,
            dashArray: const <double>[12, 8],
            dashOffsetSpeedPxPerSecond: _animatePaths ? 60.0 : null,
          ),
          onMouseOver: (LatLng _) {
            if (_hoveredPathId != id) {
              setState(() => _hoveredPathId = id);
            }
          },
          onMouseOut: (LatLng _) {
            if (_hoveredPathId == id) {
              setState(() => _hoveredPathId = null);
            }
          },
        ),
      );
    }
    return out;
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Controls(
          count: _count,
          markerCount: _markerCount,
          zonesOn: _zonesOn,
          pathsOn: _pathsOn,
          markersOn: _markersOn,
          markersAvailable: widget.mapId != null,
          animateZones: _animateZones,
          animatePaths: _animatePaths,
          onCount: (int v) => setState(() => _count = v),
          onMarkerCount: (int v) => setState(() => _markerCount = v),
          onZones: (bool v) => setState(() => _zonesOn = v),
          onPaths: (bool v) => setState(() => _pathsOn = v),
          onMarkers: (bool v) => setState(() => _markersOn = v),
          onAnimZones: (bool v) => setState(() => _animateZones = v),
          onAnimPaths: (bool v) => setState(() => _animatePaths = v),
          onShake: () => setState(() => _seed++),
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              GoogleMap(
                mapId: widget.mapId,
                markerType: widget.mapId != null
                    ? GoogleMapMarkerType.advancedMarker
                    : GoogleMapMarkerType.marker,
                initialCameraPosition: const CameraPosition(
                  target: _center,
                  zoom: 13,
                ),
                polygons: _buildZones(),
                polylines: _buildPaths(),
                markers: _buildMarkers(),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: _FpsBadge(),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0f172a),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _hoveredPathId == null
                        ? 'Hover a path to highlight it'
                        : 'hovered: $_hoveredPathId',
                    style: TextStyle(
                      color: _hoveredPathId == null
                          ? Colors.white70
                          : const Color(0xFFfacc15),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Controls strip --------------------------------------------------------

class _Controls extends StatelessWidget {
  const _Controls({
    required this.count,
    required this.markerCount,
    required this.zonesOn,
    required this.pathsOn,
    required this.markersOn,
    required this.markersAvailable,
    required this.animateZones,
    required this.animatePaths,
    required this.onCount,
    required this.onMarkerCount,
    required this.onZones,
    required this.onPaths,
    required this.onMarkers,
    required this.onAnimZones,
    required this.onAnimPaths,
    required this.onShake,
  });

  final int count;
  final int markerCount;
  final bool zonesOn;
  final bool pathsOn;
  final bool markersOn;
  final bool markersAvailable;
  final bool animateZones;
  final bool animatePaths;
  final ValueChanged<int> onCount;
  final ValueChanged<int> onMarkerCount;
  final ValueChanged<bool> onZones;
  final ValueChanged<bool> onPaths;
  final ValueChanged<bool> onMarkers;
  final ValueChanged<bool> onAnimZones;
  final ValueChanged<bool> onAnimPaths;
  final VoidCallback onShake;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFf1f5f9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _slider(
              label: 'Zones/Paths:',
              value: count,
              min: 10,
              max: 500,
              divisions: 49,
              onChanged: onCount,
            ),
            _slider(
              label: 'Markers:',
              value: markerCount,
              min: 0,
              max: 2000,
              divisions: 40,
              onChanged: onMarkerCount,
            ),
            _toggle('Zones', zonesOn, onZones),
            _toggle('  · animate', animateZones, onAnimZones),
            _toggle('Paths', pathsOn, onPaths),
            _toggle('  · animate', animatePaths, onAnimPaths),
            _toggle(
              'Markers',
              markersOn,
              markersAvailable ? onMarkers : null,
            ),
            if (!markersAvailable)
              const Text(
                '(set mapId to enable markers)',
                style: TextStyle(fontSize: 11, color: Color(0xFFef4444)),
              ),
            TextButton.icon(
              onPressed: onShake,
              icon: const Icon(Icons.shuffle, size: 16),
              label: const Text('Shake'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 260,
      child: Row(
        children: <Widget>[
          Text(label),
          Expanded(
            child: Slider(
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: divisions,
              value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
              label: '$value',
              onChanged: (double v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool>? onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ---- FPS badge --------------------------------------------------------------

/// Self-contained FPS readout driven by a Flutter [Ticker]. Lives outside
/// the map's rebuild path so updating it doesn't add to the workload being
/// measured. Reports rolling mean over the last ~60 frames plus the worst
/// frame in the same window — the worst-frame number is the one that
/// reveals jank that the average smooths over.
class _FpsBadge extends StatefulWidget {
  const _FpsBadge();

  @override
  State<_FpsBadge> createState() => _FpsBadgeState();
}

class _FpsBadgeState extends State<_FpsBadge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _last;
  final List<double> _samples = <double>[];
  static const int _windowFrames = 60;
  double _fps = 0;
  double _worstFrameMs = 0;
  int _ticksSinceUpdate = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final Duration? last = _last;
    _last = elapsed;
    if (last == null) {
      return;
    }
    final double deltaMs = (elapsed - last).inMicroseconds / 1000.0;
    _samples.add(deltaMs);
    if (_samples.length > _windowFrames) {
      _samples.removeAt(0);
    }
    // Throttle setState to ~6 Hz so the rebuild isn't itself a perf cost.
    _ticksSinceUpdate++;
    if (_ticksSinceUpdate < 10) {
      return;
    }
    _ticksSinceUpdate = 0;
    double sum = 0;
    double worst = 0;
    for (final double d in _samples) {
      sum += d;
      if (d > worst) worst = d;
    }
    final double avg = sum / _samples.length;
    setState(() {
      _fps = avg > 0 ? 1000.0 / avg : 0;
      _worstFrameMs = worst;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = _fps >= 55
        ? const Color(0xFF10b981)
        : _fps >= 30
            ? const Color(0xFFf59e0b)
            : const Color(0xFFef4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC0f172a),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 12,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${_fps.toStringAsFixed(1)} fps',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            ),
            Text('worst ${_worstFrameMs.toStringAsFixed(1)} ms'),
          ],
        ),
      ),
    );
  }
}
