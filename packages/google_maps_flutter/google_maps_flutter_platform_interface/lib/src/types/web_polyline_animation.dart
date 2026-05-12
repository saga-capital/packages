// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Preset symbol shapes for a [WebPolylineAnimation].
enum WebFlowSymbol {
  /// Forward-open arrow, like `>`.
  arrow,

  /// Solid dot.
  dot,

  /// Short line segment, useful as a marching dash.
  dash,

  /// Stacked forward arrows, like `>>`.
  chevron,
}

/// Travel direction of the flowing symbols along the polyline path.
enum WebFlowDirection { forward, backward }

/// Web-only animation overlay on a [Polyline]. Renders flowing symbols
/// (arrows, dashes, dots, chevrons) along the path via google.maps
/// IconSequence with an RAF-driven offset shift.
///
/// Mobile ignores this field. Apps that want a static dashed appearance on
/// mobile should set a regular [Polyline.patterns] instead.
@immutable
class WebPolylineAnimation {
  const WebPolylineAnimation({
    this.symbol = WebFlowSymbol.arrow,
    this.spacing = '24px',
    this.speedPercentPerSecond = 8,
    this.direction = WebFlowDirection.forward,
    this.color,
    this.size = 4,
    this.customSvgPath,
    this.rotation,
  });

  /// Which preset symbol to repeat along the path.
  final WebFlowSymbol symbol;

  /// CSS-style repeat distance between symbols (e.g. `'24px'`, `'5%'`).
  final String spacing;

  /// Path traversal speed expressed as percentage of the total path per
  /// second. `8` means the symbol completes one trip in ~12.5 seconds
  /// regardless of physical path length.
  final double speedPercentPerSecond;

  /// Flow direction along the path.
  final WebFlowDirection direction;

  /// Override symbol color. Defaults to the polyline's own color.
  final Color? color;

  /// Symbol scale (passed through to google.maps Symbol.scale).
  final double size;

  /// Custom SVG path for the flowing symbol. When set, overrides [symbol].
  /// Coordinates are typically in the [-1, 1] range; google.maps applies
  /// [size] as the scale factor. Example: `'M -1 0 L 0 -1 L 1 0 L 0 1 Z'`
  /// for a diamond.
  final String? customSvgPath;

  /// Initial rotation in degrees applied to the symbol. The polyline tangent
  /// rotation is still added on top per icon position.
  final double? rotation;

  @override
  bool operator ==(Object other) =>
      other is WebPolylineAnimation &&
      other.symbol == symbol &&
      other.spacing == spacing &&
      other.speedPercentPerSecond == speedPercentPerSecond &&
      other.direction == direction &&
      other.color == color &&
      other.size == size &&
      other.customSvgPath == customSvgPath &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(
        symbol,
        spacing,
        speedPercentPerSecond,
        direction,
        color,
        size,
        customSvgPath,
        rotation,
      );
}
