// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'page.dart';

class PlaceCirclePage extends GoogleMapExampleAppPage {
  const PlaceCirclePage({super.key})
    : super(const Icon(Icons.linear_scale), 'Place circle');

  @override
  Widget build(BuildContext context) {
    return const PlaceCircleBody();
  }
}

class PlaceCircleBody extends StatefulWidget {
  const PlaceCircleBody({super.key});

  @override
  State<StatefulWidget> createState() => PlaceCircleBodyState();
}

class PlaceCircleBodyState extends State<PlaceCircleBody> {
  PlaceCircleBodyState();

  GoogleMapController? controller;
  Map<CircleId, Circle> circles = <CircleId, Circle>{};
  int _circleIdCounter = 1;
  CircleId? selectedCircle;
  // Tracks circles the mouse is currently inside, fed by onEnter/onExit on
  // the Circle. Used to fade fill color while hovered (CSS-free hit-test).
  final Set<CircleId> _hoveredCircles = <CircleId>{};

  // Values when toggling circle color
  int fillColorsIndex = 0;
  int strokeColorsIndex = 0;
  List<Color> colors = <Color>[
    Colors.purple,
    Colors.red,
    Colors.green,
    Colors.pink,
  ];

  // Values when toggling circle stroke width
  int widthsIndex = 0;
  List<int> widths = <int>[10, 20, 5];

  // ignore: use_setters_to_change_properties
  void _onMapCreated(GoogleMapController controller) {
    this.controller = controller;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onCircleTapped(CircleId circleId) {
    setState(() {
      selectedCircle = circleId;
    });
  }

  void _remove(CircleId circleId) {
    setState(() {
      if (circles.containsKey(circleId)) {
        circles.remove(circleId);
      }
      if (circleId == selectedCircle) {
        selectedCircle = null;
      }
    });
  }

  void _add() {
    final int circleCount = circles.length;

    if (circleCount == 12) {
      return;
    }

    final circleIdVal = 'circle_id_$_circleIdCounter';
    _circleIdCounter++;
    final circleId = CircleId(circleIdVal);

    const Color initialFill = Colors.green;
    const Color initialStroke = Colors.orange;
    const int initialWidth = 5;
    final circle = Circle(
      circleId: circleId,
      consumeTapEvents: true,
      strokeColor: initialStroke,
      fillColor: initialFill,
      strokeWidth: initialWidth,
      center: _createCenter(),
      radius: 50000,
      onTap: () {
        _onCircleTapped(circleId);
      },
      // Web-only — mouse hover support and breathing-radius animation.
      // Other platforms ignore both fields.
      onEnter: () {
        setState(() => _hoveredCircles.add(circleId));
      },
      onExit: () {
        setState(() => _hoveredCircles.remove(circleId));
      },
      webAnimation: const WebCircleAnimation(
        minRadiusPercent: 95,
        maxRadiusPercent: 115,
        periodMs: 1800,
      ),
      webOverlay: _overlayFor(
        strokeWidth: initialWidth,
        strokeColor: initialStroke,
        fillColor: initialFill,
      ),
    );

    setState(() {
      circles[circleId] = circle;
    });
  }

  void _toggleVisible(CircleId circleId) {
    final Circle circle = circles[circleId]!;
    setState(() {
      circles[circleId] = circle.copyWith(visibleParam: !circle.visible);
    });
  }

  void _changeFillColor(CircleId circleId) {
    final Circle circle = circles[circleId]!;
    final Color next = colors[++fillColorsIndex % colors.length];
    setState(() {
      circles[circleId] = circle.copyWith(
        fillColorParam: next,
        webOverlayParam: _overlayFor(
          strokeWidth: circle.strokeWidth,
          strokeColor: circle.strokeColor,
          fillColor: next,
        ),
      );
    });
  }

  void _changeStrokeColor(CircleId circleId) {
    final Circle circle = circles[circleId]!;
    final Color next = colors[++strokeColorsIndex % colors.length];
    setState(() {
      circles[circleId] = circle.copyWith(
        strokeColorParam: next,
        webOverlayParam: _overlayFor(
          strokeWidth: circle.strokeWidth,
          strokeColor: next,
          fillColor: circle.fillColor,
        ),
      );
    });
  }

  void _changeStrokeWidth(CircleId circleId) {
    final Circle circle = circles[circleId]!;
    final int next = widths[++widthsIndex % widths.length];
    setState(() {
      circles[circleId] = circle.copyWith(
        strokeWidthParam: next,
        webOverlayParam: _overlayFor(
          strokeWidth: next,
          strokeColor: circle.strokeColor,
          fillColor: circle.fillColor,
        ),
      );
    });
  }

  /// Rebuilds a [WebCircleOverlay] reflecting the current [strokeWidth],
  /// [strokeColor], and [fillColor]. Called from `_add` and from every
  /// `_change*` toggle so the SVG overlay tracks the per-circle state.
  WebCircleOverlay _overlayFor({
    required int strokeWidth,
    required Color strokeColor,
    required Color fillColor,
  }) {
    return WebCircleOverlay(
      fill: WebGradientPaint.radial(
        stops: <Color>[
          Color.lerp(fillColor, Colors.white, 0.55)!,
          fillColor,
          Color.lerp(fillColor, Colors.black, 0.35)!,
        ],
      ),
      stroke: WebStripesPaint(
        colorA: strokeColor,
        colorB: const Color(0x00000000),
        stripeWidthPx: 8,
        gapWidthPx: 4,
        angleDegrees: 90,
        animationSpeedPxPerSecond: 12,
      ),
      strokeWidth: strokeWidth.toDouble(),
      glow: WebGlow(color: strokeColor.withValues(alpha: 0.7), blurPx: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CircleId? selectedId = selectedCircle;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 350.0,
            height: 300.0,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(52.4478, -3.5402),
                zoom: 7.0,
              ),
              circles: <Circle>{
                for (final Circle c in circles.values)
                  _hoveredCircles.contains(c.circleId)
                      ? c.copyWith(
                          fillColorParam: Colors.amberAccent.withValues(
                            alpha: 0.7,
                          ),
                          strokeWidthParam: 8,
                        )
                      : c,
              },
              onMapCreated: _onMapCreated,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        TextButton(onPressed: _add, child: const Text('add')),
                        TextButton(
                          onPressed: (selectedId == null)
                              ? null
                              : () => _remove(selectedId),
                          child: const Text('remove'),
                        ),
                        TextButton(
                          onPressed: (selectedId == null)
                              ? null
                              : () => _toggleVisible(selectedId),
                          child: const Text('toggle visible'),
                        ),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        TextButton(
                          onPressed: (selectedId == null)
                              ? null
                              : () => _changeStrokeWidth(selectedId),
                          child: const Text('change stroke width'),
                        ),
                        TextButton(
                          onPressed: (selectedId == null)
                              ? null
                              : () => _changeStrokeColor(selectedId),
                          child: const Text('change stroke color'),
                        ),
                        TextButton(
                          onPressed: (selectedId == null)
                              ? null
                              : () => _changeFillColor(selectedId),
                          child: const Text('change fill color'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LatLng _createCenter() {
    final double offset = _circleIdCounter.ceilToDouble();
    return _createLatLng(51.4816 + offset * 0.2, -3.1791);
  }

  LatLng _createLatLng(double lat, double lng) {
    return LatLng(lat, lng);
  }
}
