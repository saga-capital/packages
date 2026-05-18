// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$WebPolylineGradient equality', () {
    const Color a = Color(0xFFff0000);
    const Color b = Color(0xFF00ff00);

    test('identical fields are equal', () {
      const x = WebPolylineGradient(stops: <Color>[a, b], strokeWidth: 4);
      const y = WebPolylineGradient(stops: <Color>[a, b], strokeWidth: 4);
      expect(x, equals(y));
      expect(x.hashCode, equals(y.hashCode));
    });

    test('dashArray participates in equality', () {
      const x = WebPolylineGradient(
        stops: <Color>[a, b],
        dashArray: <double>[10, 5],
      );
      const y = WebPolylineGradient(
        stops: <Color>[a, b],
        dashArray: <double>[10, 5],
      );
      const z = WebPolylineGradient(
        stops: <Color>[a, b],
        dashArray: <double>[10, 6],
      );
      expect(x, equals(y));
      expect(x, isNot(equals(z)));
    });

    test('dashOffsetSpeedPxPerSecond participates in equality', () {
      const x = WebPolylineGradient(
        stops: <Color>[a, b],
        dashArray: <double>[10, 5],
        dashOffsetSpeedPxPerSecond: 30,
      );
      const y = WebPolylineGradient(
        stops: <Color>[a, b],
        dashArray: <double>[10, 5],
        dashOffsetSpeedPxPerSecond: -30,
      );
      expect(x, isNot(equals(y)));
    });

    test('null dashArray vs set is not equal', () {
      const x = WebPolylineGradient(stops: <Color>[a, b]);
      const y = WebPolylineGradient(
        stops: <Color>[a, b],
        dashArray: <double>[10, 5],
      );
      expect(x, isNot(equals(y)));
    });

    test('pane participates in equality', () {
      const x = WebPolylineGradient(stops: <Color>[a, b]);
      const y = WebPolylineGradient(
        stops: <Color>[a, b],
        pane: WebOverlayPane.markerLayer,
      );
      expect(x, isNot(equals(y)));
    });
  });
}
