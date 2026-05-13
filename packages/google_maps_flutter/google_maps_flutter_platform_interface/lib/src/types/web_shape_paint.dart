// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Shared "paint" abstraction used by web-only SVG overlays for polygons
/// and circles. Each subclass describes how to fill or stroke an SVG
/// `<path>` / `<circle>`. Mobile platforms ignore overlays entirely.
@immutable
sealed class WebShapePaint {
  const WebShapePaint();
}

enum WebGradientKind { linear, radial }

/// Linear or radial gradient paint.
class WebGradientPaint extends WebShapePaint {
  /// Linear gradient defined by direction angle (`0°` = left→right, `90°`
  /// = top→bottom in SVG screen coords).
  const WebGradientPaint.linear({
    required this.stops,
    this.angleDegrees = 0,
    this.repeatCount = 1,
    this.animationSpeedPercentPerSecond,
  })  : kind = WebGradientKind.linear,
        centerX = 0.5,
        centerY = 0.5,
        radius = 0.5;

  /// Radial gradient centred at `(centerX, centerY)` in the shape's
  /// bounding-box (0..1) extending out to `radius`.
  const WebGradientPaint.radial({
    required this.stops,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.radius = 0.5,
    this.repeatCount = 1,
    this.animationSpeedPercentPerSecond,
  })  : kind = WebGradientKind.radial,
        angleDegrees = 0;

  final WebGradientKind kind;
  final List<Color> stops;
  final double angleDegrees;
  final double centerX;
  final double centerY;
  final double radius;
  final int repeatCount;
  final double? animationSpeedPercentPerSecond;

  @override
  bool operator ==(Object other) {
    if (other is! WebGradientPaint) {
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
    return other.kind == kind &&
        other.angleDegrees == angleDegrees &&
        other.centerX == centerX &&
        other.centerY == centerY &&
        other.radius == radius &&
        other.repeatCount == repeatCount &&
        other.animationSpeedPercentPerSecond ==
            animationSpeedPercentPerSecond;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        Object.hashAll(stops),
        angleDegrees,
        centerX,
        centerY,
        radius,
        repeatCount,
        animationSpeedPercentPerSecond,
      );
}

/// Repeating-stripe pattern paint. `colorA` and `colorB` alternate every
/// `stripeWidthPx + gapWidthPx` along the perpendicular of [angleDegrees].
class WebStripesPaint extends WebShapePaint {
  const WebStripesPaint({
    required this.colorA,
    required this.colorB,
    this.stripeWidthPx = 8,
    this.gapWidthPx = 0,
    this.angleDegrees = 45,
    this.animationSpeedPxPerSecond,
  });

  final Color colorA;
  final Color colorB;
  final double stripeWidthPx;
  final double gapWidthPx;
  final double angleDegrees;

  /// When set, the stripe pattern slides at this many CSS pixels per
  /// second along the stripe-perpendicular axis. Positive → forward,
  /// negative → reverse.
  final double? animationSpeedPxPerSecond;

  @override
  bool operator ==(Object other) =>
      other is WebStripesPaint &&
      other.colorA == colorA &&
      other.colorB == colorB &&
      other.stripeWidthPx == stripeWidthPx &&
      other.gapWidthPx == gapWidthPx &&
      other.angleDegrees == angleDegrees &&
      other.animationSpeedPxPerSecond == animationSpeedPxPerSecond;

  @override
  int get hashCode => Object.hash(
        colorA,
        colorB,
        stripeWidthPx,
        gapWidthPx,
        angleDegrees,
        animationSpeedPxPerSecond,
      );
}

/// Polka-dot pattern paint. Dots of [color] (`dotRadiusPx`) on a
/// [backgroundColor] field at `spacingPx` centres.
class WebDotsPaint extends WebShapePaint {
  const WebDotsPaint({
    required this.color,
    this.backgroundColor = const Color(0x00000000),
    this.dotRadiusPx = 2,
    this.spacingPx = 12,
    this.animationSpeedPxPerSecond,
  });

  final Color color;
  final Color backgroundColor;
  final double dotRadiusPx;
  final double spacingPx;
  final double? animationSpeedPxPerSecond;

  @override
  bool operator ==(Object other) =>
      other is WebDotsPaint &&
      other.color == color &&
      other.backgroundColor == backgroundColor &&
      other.dotRadiusPx == dotRadiusPx &&
      other.spacingPx == spacingPx &&
      other.animationSpeedPxPerSecond == animationSpeedPxPerSecond;

  @override
  int get hashCode => Object.hash(
        color,
        backgroundColor,
        dotRadiusPx,
        spacingPx,
        animationSpeedPxPerSecond,
      );
}

/// Soft glow / drop-shadow applied to the rendered shape via SVG
/// `<filter>` + `feGaussianBlur`.
@immutable
class WebGlow {
  const WebGlow({
    required this.color,
    this.blurPx = 6,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final Color color;
  final double blurPx;
  final double offsetX;
  final double offsetY;

  @override
  bool operator ==(Object other) =>
      other is WebGlow &&
      other.color == color &&
      other.blurPx == blurPx &&
      other.offsetX == offsetX &&
      other.offsetY == offsetY;

  @override
  int get hashCode => Object.hash(color, blurPx, offsetX, offsetY);
}
