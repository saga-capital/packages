// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Web-only colour-cycling animation for a [Polygon]. The plugin drives a
/// shared requestAnimationFrame loop that lerps fill and/or stroke colours
/// between the configured endpoints on a sine wave every [periodMs]
/// milliseconds.
///
/// Either pair can be omitted to leave that channel unanimated. Mobile
/// platforms ignore this field.
@immutable
class WebPolygonAnimation {
  const WebPolygonAnimation({
    this.fillColorA,
    this.fillColorB,
    this.strokeColorA,
    this.strokeColorB,
    this.periodMs = 2400,
  }) : assert(periodMs > 0, 'periodMs must be positive');

  /// First fill endpoint. When both [fillColorA] and [fillColorB] are set,
  /// the fill colour oscillates between them.
  final Color? fillColorA;

  /// Second fill endpoint.
  final Color? fillColorB;

  /// First stroke endpoint. When both [strokeColorA] and [strokeColorB] are
  /// set, the stroke colour oscillates between them.
  final Color? strokeColorA;

  /// Second stroke endpoint.
  final Color? strokeColorB;

  /// Full breathing cycle duration in milliseconds.
  final double periodMs;

  bool get animatesFill => fillColorA != null && fillColorB != null;
  bool get animatesStroke => strokeColorA != null && strokeColorB != null;

  @override
  bool operator ==(Object other) =>
      other is WebPolygonAnimation &&
      other.fillColorA == fillColorA &&
      other.fillColorB == fillColorB &&
      other.strokeColorA == strokeColorA &&
      other.strokeColorB == strokeColorB &&
      other.periodMs == periodMs;

  @override
  int get hashCode => Object.hash(
        fillColorA,
        fillColorB,
        strokeColorA,
        strokeColorB,
        periodMs,
      );
}
