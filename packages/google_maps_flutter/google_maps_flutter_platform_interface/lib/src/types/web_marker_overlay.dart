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

/// Placement of a [WebMarkerPortal] relative to its marker.
///
/// `auto` picks the side with the most viewport room. The four directional
/// values force a side and do not flip — the plugin still clamps the popup
/// inside the viewport, but the side is fixed.
enum WebMarkerPortalPlacement { above, below, left, right, auto }

/// Companion overlay rendered on `document.body` outside the map container.
///
/// Marker DOM lives inside a clipped, transformed container — popups that
/// extend past the map edge are clipped. A [WebMarkerPortal] is mounted on
/// `document.body` (or the browser's top layer via the Popover API when
/// available), and its position is kept in sync with the marker wrapper as
/// the camera moves.
///
/// The plugin writes four CSS custom properties on the portal element each
/// frame:
///
///   --fd-marker-x  · viewport-x of the marker wrapper's left edge
///   --fd-marker-y  · viewport-y of the marker wrapper's top edge
///   --fd-marker-w  · marker wrapper width
///   --fd-marker-h  · marker wrapper height
///
/// Application stylesheets reference them to position the popup, e.g.
///
///   .my-portal {
///     position: fixed;
///     left: calc(var(--fd-marker-x) + var(--fd-marker-w) / 2);
///     top:  var(--fd-marker-y);
///     transform: translate(-50%, -100%);
///   }
///
/// Web only. Ignored by mobile renderers.
@immutable
class WebMarkerPortal {
  const WebMarkerPortal({
    required this.html,
    this.className,
    this.customize,
    this.customizeKey,
    this.useTopLayer = true,
    this.placement = WebMarkerPortalPlacement.auto,
    this.offset = 8.0,
    this.viewportMargin = 8.0,
  });

  /// Raw HTML inserted into the portal element via `innerHTML`. Unsanitized
  /// — never interpolate untrusted input.
  final String html;

  /// CSS class applied to the portal element. Equivalent to
  /// [WebMarkerOverlay.className] but for the portal node.
  final String? className;

  /// Imperative DOM customizer invoked with the portal element after its
  /// HTML and CSS variables are in place. Typed as [Object] so this type
  /// stays pure Dart; cast to `web.HTMLElement` on the call site.
  final void Function(Object portalElement)? customize;

  /// Equality key for [customize]. Excluded from `==`. Bump it when the
  /// closure's captured state should cause a re-mount.
  final Object? customizeKey;

  /// When true and the browser supports the Popover API (`showPopover`),
  /// the portal element enters the browser's top layer — guaranteed to
  /// paint above everything regardless of stacking context, transforms, or
  /// `overflow: hidden` ancestors. When unsupported, falls back to
  /// `position: fixed` on `document.body`.
  final bool useTopLayer;

  /// Where the popup sits relative to the marker. `auto` picks the side
  /// with the most viewport room and flips when the chosen side would
  /// overflow.
  final WebMarkerPortalPlacement placement;

  /// Gap in pixels between the marker edge and the popup edge.
  final double offset;

  /// Minimum gap between the popup and the viewport edge. The plugin clamps
  /// the popup's final position so it never overflows the viewport by more
  /// than this margin.
  final double viewportMargin;

  @override
  bool operator ==(Object other) =>
      other is WebMarkerPortal &&
      other.html == html &&
      other.className == className &&
      other.customizeKey == customizeKey &&
      other.useTopLayer == useTopLayer &&
      other.placement == placement &&
      other.offset == offset &&
      other.viewportMargin == viewportMargin;

  @override
  int get hashCode => Object.hash(
        html,
        className,
        customizeKey,
        useTopLayer,
        placement,
        offset,
        viewportMargin,
      );
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
    this.customHtml,
    this.customize,
    this.customizeKey,
    this.portal,
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

  /// Raw HTML inserted into the wrapper after the typed slots (label, badge).
  /// Not sanitized — never interpolate untrusted input. Use for static SVG
  /// glyphs, decorative spans, or anything expressible as a markup snippet.
  final String? customHtml;

  /// Imperative DOM customizer invoked on the wrapper element after all typed
  /// slots and [customHtml] have been applied. The parameter is the
  /// `web.HTMLElement` wrapper (declared as [Object] so this type stays pure
  /// Dart); cast it on the call site in web code.
  ///
  /// Runs only on web; ignored on mobile. Re-fires only when the overlay
  /// snapshot (including [customizeKey]) differs from the last applied one,
  /// so the closure should treat each invocation as a fresh build against a
  /// new wrapper element.
  ///
  /// The closure itself is excluded from [==] / [hashCode]. Bump
  /// [customizeKey] when the captured state should trigger a refire.
  final void Function(Object wrapper)? customize;

  /// Equality key for [customize]. Treat like a React `key`: change it when
  /// captured state (selection, hover, dataset version) should cause a
  /// re-build. Compared via the value's own [==].
  final Object? customizeKey;

  /// Companion DOM overlay rendered outside the map container. See
  /// [WebMarkerPortal] for the positioning contract.
  final WebMarkerPortal? portal;

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
        other.rotation == rotation &&
        other.customHtml == customHtml &&
        other.customizeKey == customizeKey &&
        other.portal == portal;
  }

  @override
  int get hashCode => Object.hash(
        label,
        badge,
        className,
        rotation,
        zoomTiers == null ? null : Object.hashAll(zoomTiers!),
        customHtml,
        customizeKey,
        portal,
      );
}
