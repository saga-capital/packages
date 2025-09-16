// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Colors, Color;

/// Enumeration of types of pattern items.
enum PatternItemType {
  /// A dot used in the stroke pattern for a [Polyline].
  dot,

  /// A dash used in the stroke pattern for a [Polyline].
  dash,

  /// A gap used in the stroke pattern for a [Polyline].
  gap,
}

String _patternItemTypeToJson(PatternItemType itemType) =>
    switch (itemType) {
      PatternItemType.dot => 'dot',
      PatternItemType.dash => 'dash',
      PatternItemType.gap => 'gap',
    };

/// Item used in the stroke pattern for a Polyline.
@immutable
class PatternItem {
  const PatternItem._(this.type);

  /// A dot used in the stroke pattern for a [Polyline].
  static const PatternItem dot = PatternItem._(PatternItemType.dot);

  /// A dash used in the stroke pattern for a [Polyline].
  ///
  /// [length] has to be non-negative.
  static PatternItem dash(double length) {
    assert(length >= 0.0);
    return VariableLengthPatternItem._(
      patternItemType: PatternItemType.dash,
      length: length,
    );
  }

  /// A gap used in the stroke pattern for a [Polyline].
  ///
  /// [length] has to be non-negative.
  static PatternItem gap(double length) {
    assert(length >= 0.0);
    return VariableLengthPatternItem._(
      patternItemType: PatternItemType.gap,
      length: length,
    );
  }

  /// The type of rendering used for an item in a pattern.
  final PatternItemType type;

  /// Converts this object to something serializable in JSON.
  Object toJson() =>
      <Object>[_patternItemTypeToJson(type)];
}

/// A pattern item with a length, i.e. a dash or gap.
@immutable
class VariableLengthPatternItem extends PatternItem {
  const VariableLengthPatternItem._({
    required PatternItemType patternItemType,
    required this.length,
  }) : super._(patternItemType);

  /// The length in pixels of a dash or gap.
  final double length;

  /// Converts this object to something serializable in JSON.
  @override
  Object toJson() =>
      <Object>[_patternItemTypeToJson(type), length];
}


@immutable
class WebPatternItem extends VariableLengthPatternItem {
  static const String linePath = 'M 0,-1 0,1';
  //todo change dot to symbol usage
  static const String dotPath = 'M -1,-1 -1,1 1,1 1,-1z';

  final String path;
  final num offset;
  final num repeat;
  final PatternRepeatMode repeatMode;
  final Color strokeColor;
  final int? strokeWeight;
  final Color? fillColor;
  final num scale;
  final num opacity;
  final num? rotation;

  /// Private constructor for all WebPatternItem variants.
  const WebPatternItem._({
    required PatternItemType patternItemType,
    required double length,
    required this.path,
    required this.offset,
    required this.repeat,
    required this.repeatMode,
    required this.strokeColor,
    required this.strokeWeight,
    required this.fillColor,
    required this.opacity,
    required this.scale,
    required this.rotation,
  }) : super._(patternItemType: patternItemType, length: length);

  /// Dot pattern item (fixed, minimal params).
  factory WebPatternItem.dot({
    num offset = 0,
    num repeat = 20,
    PatternRepeatMode repeatMode = PatternRepeatMode.pixels,
    Color strokeColor = Colors.black,
    int? strokeWeight,
    Color? fillColor,
    num opacity = 1,
    num scale = 1,
    num? rotation,
  }) {
    return WebPatternItem._(
      patternItemType: PatternItemType.dot,
      length: 0,
      path: dotPath,
      offset: offset,
      repeat: repeat,
      repeatMode: repeatMode,
      strokeColor: strokeColor,
      strokeWeight: strokeWeight,
      fillColor: fillColor,
      opacity: opacity,
      scale: scale,
      rotation: rotation,
    );
  }

  /// Dash pattern item (with length).
  factory WebPatternItem.dash({
    required double length,
    String path = linePath,
    num offset = 0,
    num repeat = 20,
    PatternRepeatMode repeatMode = PatternRepeatMode.pixels,
    Color strokeColor = Colors.black,
    int? strokeWeight,
    Color? fillColor,
    num opacity = 1,
    num scale = 1,
    num? rotation,
  }) {
    return WebPatternItem._(
      patternItemType: PatternItemType.dash,
      length: length,
      path: path,
      offset: offset,
      repeat: repeat,
      repeatMode: repeatMode,
      strokeColor: strokeColor,
      strokeWeight: strokeWeight,
      fillColor: fillColor,
      opacity: opacity,
      scale: scale,
      rotation: rotation,
    );
  }

  /// Gap pattern item (with length).
  factory WebPatternItem.gap({
    required double length,
    String path = linePath,
    num offset = 0,
    num repeat = 20,
    PatternRepeatMode repeatMode = PatternRepeatMode.pixels,
    Color strokeColor = Colors.black,
    int? strokeWeight,
    Color? fillColor,
    num opacity = 1,
    num scale = 1,
    num? rotation,
  }) {
    return WebPatternItem._(
      patternItemType: PatternItemType.gap,
      length: length,
      path: path,
      offset: offset,
      repeat: repeat,
      repeatMode: repeatMode,
      strokeColor: strokeColor,
      strokeWeight: strokeWeight,
      fillColor: fillColor,
      opacity: opacity,
      scale: scale,
      rotation: rotation,
    );
  }

  /// Custom pattern item (all params exposed).
  factory WebPatternItem.custom({
    /// SVG path string, e.g. 'M 0,-1 0,1' for a vertical line
    required String path,
    required double length,
    num offset = 0,
    num repeat = 20,
    PatternRepeatMode repeatMode = PatternRepeatMode.pixels,
    Color strokeColor = Colors.black,
    int? strokeWeight,
    Color? fillColor,
    num opacity = 1,
    num scale = 1,
    num? rotation,
  }) {
    return WebPatternItem._(
      patternItemType: PatternItemType.dash,
      length: length,
      path: path,
      offset: offset,
      repeat: repeat,
      repeatMode: repeatMode,
      strokeColor: strokeColor,
      strokeWeight: strokeWeight,
      fillColor: fillColor,
      opacity: opacity,
      scale: scale,
      rotation: rotation,
    );
  }

  @override
  Object toJson() {
    return <Object?>[
      _patternItemTypeToJson(type),
      length,
      path,
      offset,
      repeat,
      repeatMode.name,
      strokeWeight,
      strokeColor.value.toRadixString(16),
      fillColor?.value.toRadixString(16) ?? '',
      opacity,
      scale,
      rotation,
    ];
  }
}

enum PatternRepeatMode {
  pixels,
  percentage,
  ;

  String get asString {
    switch (this) {
      case PatternRepeatMode.pixels:
        return 'px';
      case PatternRepeatMode.percentage:
        return '%';
    }
  }
}
