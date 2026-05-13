// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show immutable;

import 'web_polyline_gradient.dart' show WebOverlayPane;
import 'web_shape_paint.dart';

/// Web-only SVG overlay for a [Polygon]. When set, the polygon renders as
/// an SVG `<path>` with optional gradient/pattern fill + stroke + glow,
/// painted on top of the (transparent) native gmaps polygon. Hit
/// testing on the native polygon is unchanged, so `onTap`, `onEnter`,
/// `onExit` continue to fire.
///
/// Mobile platforms ignore this field.
@immutable
class WebPolygonOverlay {
  const WebPolygonOverlay({
    this.fill,
    this.stroke,
    this.strokeWidth,
    this.glow,
    this.pane = WebOverlayPane.overlayLayer,
  });

  /// Paint for the polygon interior.
  final WebShapePaint? fill;

  /// Paint for the polygon outline.
  final WebShapePaint? stroke;

  /// Stroke width in CSS pixels. Defaults to the polygon's [strokeWidth].
  final double? strokeWidth;

  /// Optional drop-shadow / glow rendered via SVG `<filter>`.
  final WebGlow? glow;

  /// Which gmaps pane the SVG attaches to. See [WebOverlayPane].
  final WebOverlayPane pane;

  @override
  bool operator ==(Object other) =>
      other is WebPolygonOverlay &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.strokeWidth == strokeWidth &&
      other.glow == glow &&
      other.pane == pane;

  @override
  int get hashCode => Object.hash(fill, stroke, strokeWidth, glow, pane);
}
