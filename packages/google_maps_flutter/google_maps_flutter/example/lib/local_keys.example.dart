// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// TEMPLATE FILE. This file IS committed and serves as a starter for
// `local_keys.dart` (which is .gitignored).
//
// Setup:
//   1. Copy this file to `lib/local_keys.dart` in the same directory.
//   2. Fill in your own Google Maps Map ID (and any other future secrets).
//   3. Do NOT commit `lib/local_keys.dart` — it is excluded via .gitignore.
//
// You can also override at build/run time via:
//   --dart-define=GMAPS_MAP_ID=your_map_id
// in which case `local_keys.dart` is only used as a fallback.

/// Google Maps "Map ID" used by Advanced Marker example pages.
///
/// Set this to `null` if you do not have a Map ID; the Advanced Marker pages
/// will then fall back to default styling (and some features will be
/// unavailable).
const String? localMapId = null;
