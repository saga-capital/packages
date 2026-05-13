// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show immutable;

import 'web_polyline_gradient.dart' show WebOverlayPane;
import 'web_shape_paint.dart';

/// Web-only SVG overlay for a [Circle]. The circle renders as an SVG
/// `<circle>` with optional gradient/pattern fill + stroke + glow,
/// painted on top of the (transparent) native gmaps circle. Hit testing
/// on the native circle is unchanged so `onTap` / `onEnter` / `onExit`
/// continue to fire.
///
/// Mobile platforms ignore this field.
@immutable
class WebCircleOverlay {
  const WebCircleOverlay({
    this.fill,
    this.stroke,
    this.strokeWidth,
    this.glow,
    this.pane = WebOverlayPane.overlayLayer,
  });

  final WebShapePaint? fill;
  final WebShapePaint? stroke;
  final double? strokeWidth;
  final WebGlow? glow;
  final WebOverlayPane pane;

  @override
  bool operator ==(Object other) =>
      other is WebCircleOverlay &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.strokeWidth == strokeWidth &&
      other.glow == glow &&
      other.pane == pane;

  @override
  int get hashCode => Object.hash(fill, stroke, strokeWidth, glow, pane);
}
