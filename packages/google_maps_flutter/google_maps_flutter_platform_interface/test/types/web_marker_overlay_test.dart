// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$WebMarkerOverlay equality', () {
    test('two overlays with identical fields are equal', () {
      const a = WebMarkerOverlay(
        label: WebMarkerLabel(text: 'hi'),
        className: 'fd',
        rotation: 12,
      );
      const b = WebMarkerOverlay(
        label: WebMarkerLabel(text: 'hi'),
        className: 'fd',
        rotation: 12,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('customHtml participates in equality', () {
      const a = WebMarkerOverlay(customHtml: '<i>a</i>');
      const b = WebMarkerOverlay(customHtml: '<i>a</i>');
      const c = WebMarkerOverlay(customHtml: '<i>b</i>');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('customize closure identity is ignored, customizeKey decides', () {
      void closure1(Object _) {}
      void closure2(Object _) {}

      // Same key, different closure refs → still equal.
      final a = WebMarkerOverlay(customize: closure1, customizeKey: 'k1');
      final b = WebMarkerOverlay(customize: closure2, customizeKey: 'k1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      // Different key → not equal even if closure is the same instance.
      final c = WebMarkerOverlay(customize: closure1, customizeKey: 'k1');
      final d = WebMarkerOverlay(customize: closure1, customizeKey: 'k2');
      expect(c, isNot(equals(d)));
    });

    test('null customize with same other fields stays equal', () {
      const a = WebMarkerOverlay(className: 'x');
      const b = WebMarkerOverlay(className: 'x');
      expect(a, equals(b));
    });

    test('label/badge/className/rotation/zoomTiers still participate', () {
      const a = WebMarkerOverlay(
        label: WebMarkerLabel(text: 'a'),
        badge: WebMarkerBadge(text: '1'),
        className: 'x',
        rotation: 0,
        zoomTiers: <WebZoomTier>[
          WebZoomTier(minZoom: 12, className: 'near'),
        ],
      );
      const b = WebMarkerOverlay(
        label: WebMarkerLabel(text: 'a'),
        badge: WebMarkerBadge(text: '1'),
        className: 'x',
        rotation: 0,
        zoomTiers: <WebZoomTier>[
          WebZoomTier(minZoom: 12, className: 'near'),
        ],
      );
      const differentTier = WebMarkerOverlay(
        label: WebMarkerLabel(text: 'a'),
        badge: WebMarkerBadge(text: '1'),
        className: 'x',
        rotation: 0,
        zoomTiers: <WebZoomTier>[
          WebZoomTier(minZoom: 14, className: 'near'),
        ],
      );
      expect(a, equals(b));
      expect(a, isNot(equals(differentTier)));
    });
  });
}
