// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Anchor positions for a [WebMarkerLabel] relative to the marker icon bounds.
enum WebLabelAnchor { center, top, bottom, left, right }

/// Anchor positions for a [WebMarkerBadge] relative to the marker icon bounds.
enum WebBadgeAnchor { topLeft, topRight, bottomLeft, bottomRight }

/// Text label rendered as DOM on top of an Advanced Marker icon (web only).
///
/// Use either inline style fields (color/fontSize/fontFamily/fontWeight) or a
/// [className] referencing a CSS class — not both.
@immutable
class WebMarkerLabel {
  const WebMarkerLabel({
    required this.text,
    this.color,
    this.fontSize,
    this.fontFamily,
    this.fontWeight,
    this.anchor = WebLabelAnchor.center,
    this.className,
  });

  final String text;
  final Color? color;

  /// CSS font-size value (e.g. `'12px'`).
  final String? fontSize;
  final String? fontFamily;

  /// CSS font-weight value (e.g. `'600'`, `'bold'`).
  final String? fontWeight;
  final WebLabelAnchor anchor;
  final String? className;

  @override
  bool operator ==(Object other) =>
      other is WebMarkerLabel &&
      other.text == text &&
      other.color == color &&
      other.fontSize == fontSize &&
      other.fontFamily == fontFamily &&
      other.fontWeight == fontWeight &&
      other.anchor == anchor &&
      other.className == className;

  @override
  int get hashCode =>
      Object.hash(text, color, fontSize, fontFamily, fontWeight, anchor, className);
}

/// Small overlay rendered as DOM on top of an Advanced Marker icon (web only).
@immutable
class WebMarkerBadge {
  const WebMarkerBadge({
    this.text,
    this.color,
    this.anchor = WebBadgeAnchor.topRight,
    this.className,
  });

  final String? text;
  final Color? color;
  final WebBadgeAnchor anchor;
  final String? className;

  @override
  bool operator ==(Object other) =>
      other is WebMarkerBadge &&
      other.text == text &&
      other.color == color &&
      other.anchor == anchor &&
      other.className == className;

  @override
  int get hashCode => Object.hash(text, color, anchor, className);
}

/// A single zoom-class tier used by [WebMarkerOverlay.zoomTiers]. When the
/// current map zoom is greater than or equal to [minZoom], [className] is
/// appended to the marker wrapper's CSS class list. The active tier is the
/// one with the highest matching [minZoom].
@immutable
class WebZoomTier {
  const WebZoomTier({required this.minZoom, required this.className});

  final double minZoom;
  final String className;

  @override
  bool operator ==(Object other) =>
      other is WebZoomTier &&
      other.minZoom == minZoom &&
      other.className == className;

  @override
  int get hashCode => Object.hash(minZoom, className);
}

/// Web-only DOM overlay composed on top of an Advanced Marker icon.
///
/// Mobile platforms ignore this field. Bake any label or badge directly into
/// the marker's [BitmapDescriptor] for mobile rendering.
///
/// Apps drive hover/selection visuals by toggling [className] on rebuild;
/// CSS `:hover`, `.is-selected`, etc. live in the app's stylesheet.
@immutable
class WebMarkerOverlay {
  const WebMarkerOverlay({
    this.label,
    this.badge,
    this.className,
    this.rotation,
    this.zoomTiers,
  });

  final WebMarkerLabel? label;
  final WebMarkerBadge? badge;

  /// CSS class applied to the marker wrapper element.
  final String? className;

  /// Rotation in degrees exposed to the marker wrapper as the
  /// `--fd-rotate` CSS custom property. Application stylesheets reference
  /// `var(--fd-rotate)` on the specific glyph that should turn (e.g. an
  /// `::before` chevron), keeping labels and badges upright.
  final double? rotation;

  /// Zoom-tier classes appended to the wrapper based on the current map
  /// zoom level. The plugin tracks zoom changes and re-applies the highest
  /// matching tier without requiring app code to wire `onCameraMove`.
  final List<WebZoomTier>? zoomTiers;

  @override
  bool operator ==(Object other) {
    if (other is! WebMarkerOverlay) {
      return false;
    }
    final List<WebZoomTier>? a = zoomTiers;
    final List<WebZoomTier>? b = other.zoomTiers;
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
    return other.label == label &&
        other.badge == badge &&
        other.className == className &&
        other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(
        label,
        badge,
        className,
        rotation,
        zoomTiers == null ? null : Object.hashAll(zoomTiers!),
      );
}
