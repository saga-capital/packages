// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show immutable;

/// Web-only breathing-radius animation for a [Circle]. The plugin drives a
/// shared requestAnimationFrame loop that oscillates the circle's radius
/// between [minRadiusPercent] and [maxRadiusPercent] of its base [radius]
/// every [periodMs] milliseconds using a sine wave.
///
/// Mobile platforms ignore this field.
@immutable
class WebCircleAnimation {
  const WebCircleAnimation({
    this.minRadiusPercent = 90,
    this.maxRadiusPercent = 130,
    this.periodMs = 1600,
  })  : assert(periodMs > 0, 'periodMs must be positive'),
        assert(
          minRadiusPercent >= 0 && maxRadiusPercent > minRadiusPercent,
          'maxRadiusPercent must exceed minRadiusPercent',
        );

  /// Lower bound expressed as a percentage of the base [Circle.radius].
  final double minRadiusPercent;

  /// Upper bound expressed as a percentage of the base [Circle.radius].
  final double maxRadiusPercent;

  /// Full breathing cycle duration in milliseconds.
  final double periodMs;

  @override
  bool operator ==(Object other) =>
      other is WebCircleAnimation &&
      other.minRadiusPercent == minRadiusPercent &&
      other.maxRadiusPercent == maxRadiusPercent &&
      other.periodMs == periodMs;

  @override
  int get hashCode => Object.hash(minRadiusPercent, maxRadiusPercent, periodMs);
}
