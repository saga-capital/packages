// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Web-only gradient stroke overlay for a [Polyline]. Renders the stroke
/// as an SVG `<path>` inside a custom `gmaps.OverlayView`, with an SVG
/// `<linearGradient>` fed by [stops] and oriented along the polyline's
/// projected start->end direction.
///
/// When set, the underlying gmaps polyline is rendered with zero stroke
/// opacity so the SVG layer carries all the visuals; hover events still
/// fire because the gmaps polyline retains its hit geometry.
///
/// Mobile platforms ignore this field.
@immutable
class WebPolylineGradient {
  const WebPolylineGradient({
    required this.stops,
    this.strokeWidth,
    this.strokeLinecap = WebStrokeLinecap.round,
    this.strokeLinejoin = WebStrokeLinejoin.round,
    this.animationSpeedPercentPerSecond,
    this.repeatCount = 1,
    this.pane = WebOverlayPane.overlayLayer,
    this.dashArray,
    this.dashOffsetSpeedPxPerSecond,
  });

  /// Colour stops evenly spaced from 0% to 100% along the polyline.
  final List<Color> stops;

  /// Stroke width in CSS pixels. Defaults to the polyline's own [Polyline.width].
  final double? strokeWidth;

  /// SVG `stroke-linecap` for the gradient stroke.
  final WebStrokeLinecap strokeLinecap;

  /// SVG `stroke-linejoin` for the gradient stroke.
  final WebStrokeLinejoin strokeLinejoin;

  /// When set, the colour stops slide along the path at this speed,
  /// expressed as a percentage of the polyline's projected length per
  /// second. Positive values flow start→end; negative values flow
  /// end→start. Implemented by translating the gradient's coordinate
  /// system via a shared RAF loop and `spreadMethod="repeat"`. Null →
  /// static gradient.
  final double? animationSpeedPercentPerSecond;

  /// How many times the [stops] sequence tiles across the polyline. Only
  /// meaningful when [animationSpeedPercentPerSecond] is set (the tile
  /// boundary repeats seamlessly). `1` = single ramp from first stop to
  /// last; higher values pack `repeatCount` ramps along the line.
  final int repeatCount;

  /// Which gmaps pane the SVG overlay attaches to. Defaults to
  /// `overlayLayer` — same level as native gmaps polylines/polygons, so
  /// the gradient stacks among other shapes via the underlying
  /// [Polyline.zIndex] and stays below markers. Pick `markerLayer` or
  /// `floatPane` to render above markers.
  final WebOverlayPane pane;

  /// Dash pattern applied to the gradient stroke, in CSS pixels. Maps
  /// straight to SVG `stroke-dasharray` — odd-length arrays implicitly
  /// repeat (`[5, 10, 15]` paints as `[5, 10, 15, 5, 10, 15]`). Null →
  /// solid stroke. The browser computes dash offsets along the path's
  /// arc length, so dashes follow polyline curves natively.
  final List<double>? dashArray;

  /// Animates the dash pattern by advancing `stroke-dashoffset` over time.
  /// Positive values flow from path start → end; negative values flow
  /// end → start. Speed is signed pixels of dash-pattern advance per
  /// second. Null or zero → static dashes. Requires [dashArray] to be set
  /// (an animated offset on a solid stroke has no visible effect).
  final double? dashOffsetSpeedPxPerSecond;

  @override
  bool operator ==(Object other) {
    if (other is! WebPolylineGradient) {
      return false;
    }
    if (other.stops.length != stops.length) {
      return false;
    }
    for (int i = 0; i < stops.length; i++) {
      if (other.stops[i] != stops[i]) {
        return false;
      }
    }
    final List<double>? a = dashArray;
    final List<double>? b = other.dashArray;
    if (a == null || b == null) {
      if (a != null || b != null) {
        return false;
      }
    } else {
      if (a.length != b.length) {
        return false;
      }
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) {
          return false;
        }
      }
    }
    return other.strokeWidth == strokeWidth &&
        other.strokeLinecap == strokeLinecap &&
        other.strokeLinejoin == strokeLinejoin &&
        other.animationSpeedPercentPerSecond ==
            animationSpeedPercentPerSecond &&
        other.repeatCount == repeatCount &&
        other.pane == pane &&
        other.dashOffsetSpeedPxPerSecond == dashOffsetSpeedPxPerSecond;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(stops),
        strokeWidth,
        strokeLinecap,
        strokeLinejoin,
        animationSpeedPercentPerSecond,
        repeatCount,
        pane,
        dashArray == null ? null : Object.hashAll(dashArray!),
        dashOffsetSpeedPxPerSecond,
      );
}

enum WebStrokeLinecap { butt, round, square }

enum WebStrokeLinejoin { miter, round, bevel }

/// Which gmaps pane an SVG-backed overlay attaches to.
enum WebOverlayPane {
  /// Same layer as native gmaps polylines/polygons/circles. Below markers.
  overlayLayer,

  /// Same layer as markers — gradient sits above the base shape layer.
  markerLayer,

  /// Same layer as InfoWindows. Highest of the standard panes.
  floatPane,
}
