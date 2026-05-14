# Migration guide — `google_maps_flutter-fd-v2.13.1+14` → `google_maps_flutter-fd-v2.17.0+15`

This release rolls the fork onto upstream `2.17.0` and adds a batch of
web-only fork extensions: pure-DOM AdvancedMarker composition, flowing
polyline overlays, animated circles, colour-cycling polygons, hover
events on every map object, and zoom-aware marker classes.

All new fields are opt-in and additive. Existing apps continue to work
unchanged unless they choose to adopt the new APIs.

---

## 1. Upstream bump `2.13.1` → `2.17.0`

The most consequential upstream additions now landed in the fork:

- **AdvancedMarker API** — `gmaps.AdvancedMarkerElement`-backed marker
  class. Enabled per map via
  `markerType: GoogleMapMarkerType.advancedMarker` plus a non-empty
  `mapId`. On the web side this requires a **Vector** Map ID (a Raster
  Map ID will silently render nothing).
- **MarkerCollisionBehavior** — `required`,
  `optionalAndHidesLowerPriority`, `requiredAndHidesOptional`.
- **AdvancedMarker clustering** — same `ClusterManager` API surface,
  cluster manager aware of advanced markers.
- **GroundOverlay** — separate first-class type, no longer faked via
  marker bitmaps.
- Various rolls: `zIndex` deprecation in tests, web style fix
  (`#11629`), Pigeon-driven channels on iOS/Android, stream-subscription
  hygiene.

Mobile callers that stay on legacy `Marker` will see no API changes.

---

## 2. New fork plugin APIs (opt-in, additive, web-only)

Every field below is web-only. Mobile platforms ignore them at runtime
with no allocation cost.

### 2.1 Marker DOM composition — `WebMarkerOverlay`

```dart
AdvancedMarker(
  markerId: const MarkerId('driver-1'),
  position: pos,
  webOverlay: WebMarkerOverlay(
    label: WebMarkerLabel(
      text: 'Anna\n2 min',
      className: 'fd-card__label',
    ),
    badge: WebMarkerBadge(
      text: '3',
      className: 'fd-card__badge',
    ),
    className: 'fd-card is-live',
    rotation: 47.3,
    zoomTiers: const <WebZoomTier>[
      WebZoomTier(minZoom: 13.5, className: 'is-near'),
    ],
  ),
)
```

Semantics:

- `className` is applied to the marker wrapper `<div>`. App stylesheet
  owns shape, gradient, pulse, hover-lift, selected state — no Flutter
  rebuild required to flip visuals.
- `label.className` and `badge.className` style child slots
  independently.
- `rotation` is exposed as the CSS custom property `--fd-rotate` on
  the wrapper. App CSS references `var(--fd-rotate)` on a specific
  glyph (e.g. an `::before` chevron) so labels and badges stay upright
  while the directional element turns.
- `zoomTiers` registers the marker with a per-map manager that listens
  once to `gmaps.Map.onZoomChanged` and applies the highest-matching
  `className` to the wrapper. App code does not wire `onCameraMove` to
  drive zoom-aware visuals.

### 2.2 Marker hover events on AdvancedMarker

Legacy `Marker` already had `onEnter` / `onExit`. The fork now wires
them for AdvancedMarker too, via DOM `mouseenter` / `mouseleave` on the
`marker.element` node.

```dart
AdvancedMarker(
  ...
  onEnter: () => setState(() => _hoveredId = id),
  onExit:  () => setState(() => _hoveredId = null),
)
```

### 2.3 Flowing-symbol polyline overlay — `WebPolylineAnimation`

```dart
Polyline(
  polylineId: const PolylineId('route'),
  points: ...,
  color: const Color(0x551E40AF), // translucent rail under the flow
  width: 6,
  webAnimation: const WebPolylineAnimation(
    symbol: WebFlowSymbol.arrow,           // .arrow / .dot / .dash / .chevron
    customSvgPath: null,                   // escape hatch for arbitrary glyph
    spacing: '30px',
    speedPercentPerSecond: 8,
    direction: WebFlowDirection.forward,
    color: Color(0xFF1E40AF),
    size: 4,
    rotation: null,
  ),
)
```

Single shared `requestAnimationFrame` loop drives all animated
polylines. Self-stops when the registration list empties; auto-pauses
when the page is hidden (`document.hidden`).

`customSvgPath` covers static patterns previously available through
`WebPatternItem.custom`, but flowing along the path.

### 2.4 Circle interactions

```dart
Circle(
  circleId: const CircleId('zone-1'),
  center: ...,
  radius: 50000,
  // NEW — hover events parity with Marker and Polygon.
  onEnter: () => ...,
  onExit:  () => ...,
  // NEW — breathing radius via shared RAF loop.
  webAnimation: const WebCircleAnimation(
    minRadiusPercent: 95,
    maxRadiusPercent: 115,
    periodMs: 1800,
  ),
)
```

Hover events flow through the new `CircleEnterEvent` /
`CircleExitEvent` stream classes. Mobile platforms emit empty streams
for these events to keep the subscription contract uniform across
platforms.

### 2.5 Polygon colour cycling — `WebPolygonAnimation`

```dart
Polygon(
  polygonId: const PolygonId('geofence'),
  points: ...,
  webAnimation: WebPolygonAnimation(
    fillColorA:   Colors.green.withValues(alpha: 0.25),
    fillColorB:   Colors.purple.withValues(alpha: 0.5),
    strokeColorA: Colors.orange,
    strokeColorB: Colors.pinkAccent,
    periodMs: 2400,
  ),
)
```

Lerps fill and/or stroke colour (with alpha) per RAF tick on a sine
curve. Both pairs are optional, so apps can animate only the fill,
only the stroke, or both. Bypass the field entirely to keep the
polygon static.

---

## 3. Bug fixes and behaviour changes

- **Polyline mouse hover** — `Polyline.onMouseOver` / `onMouseOut`
  wired through to gmaps mouse events.
- **Marker label cleared on hide** — no ghost label residue when a
  marker becomes invisible.
- **Marker event handlers** no longer throw on unknown IDs; rapid
  marker churn no longer crashes.
- **Stream subscription leaks** fixed.
- **WebPatternItem** — gained factory constructors for variable-length
  patterns.
- **Polygon `clickable`** parameter exposed alongside
  `consumeTapEvents` (orthogonal concepts: `clickable` toggles hit
  testing, `consumeTapEvents` decides propagation).
- **iOS** — small fix in event forwarding.

---

## 4. Migrating to AdvancedMarker

Opt in per map:

```dart
GoogleMap(
  mapId: '<vector-map-id>',            // REQUIRED for web AdvancedMarker
  markerType: GoogleMapMarkerType.advancedMarker,
  markers: <Marker>{ advMarker1, advMarker2 },
  ...
)
```

Field correspondence when replacing `Marker` with `AdvancedMarker`:

| Legacy `Marker` field | `AdvancedMarker` equivalent |
| --- | --- |
| `icon: BitmapDescriptor` | `icon: BitmapDescriptor` (mobile bakes label into bitmap as before; web can ignore it when `webOverlay.className` covers visuals) |
| `markerLabel: MarkerLabel` | Drop. On web set `webOverlay.label` (and optionally `webOverlay.className` for the wrapper). On mobile bake the label into the bitmap. |
| `animate: bool` (BOUNCE) | No direct equivalent on AdvancedMarker (`gmaps.Animation.BOUNCE` is not supported by `AdvancedMarkerElement`). On web toggle `webOverlay.className` + CSS keyframes. On mobile swap the bitmap. |
| `infoWindow.title` / `infoWindow.snippet` | Still works (uses `gmaps.InfoWindow` under AdvancedMarker). For rich interactive popups keep your existing Flutter overlay — gmaps `InfoWindow` cannot host Flutter widgets. |
| `flat` | Not supported on web AdvancedMarker. |
| `rotation` | On web use `webOverlay.rotation` (CSS variable, only the chosen glyph rotates). On mobile bake into bitmap. |
| `zIndexInt` | `zIndex` |
| `onTap`, `onDragStart`, `onDrag`, `onDragEnd`, `onEnter`, `onExit` | Identical fields and semantics. |
| _new_ | `collisionBehavior: MarkerCollisionBehavior.*` |
| _new_ | `webOverlay: WebMarkerOverlay(...)` — label/badge slots, `className`, `rotation`, `zoomTiers`. When non-null on web the bitmap `icon` is **not** rendered; mobile still uses `icon` as the visible marker. |
| _new_ | `anchorPx: Offset?` — web-only pixel anchor. Lat/lng falls at `(anchorPx.dx, anchorPx.dy)` inside the wrapper. Supersedes the ratio `anchor`. Mobile ignores. |

### Web-only enhancements available through `webOverlay`

- `label` / `badge` slots with their own `className` for pure-DOM
  positioning. No Flutter rebuild on hover or selection.
- `className` on the wrapper drives shape, gradient, pulse, hover
  lift, selected state via your stylesheet.
- `rotation` exposed as `--fd-rotate` so labels and badges remain
  upright while a directional glyph turns.
- `zoomTiers` for zoom-aware visuals without `onCameraMove` plumbing.

### Mobile path unchanged

Mobile callers continue to bake label, badge, status, and rotation
into the `BitmapDescriptor`. `webOverlay` is ignored on mobile.

### Web marker transform recipe (`anchorPx` framework)

When `anchorPx` is set, the plugin also publishes two CSS custom
properties on the marker wrapper:

```
--fd-anchor-x: <dx>px;
--fd-anchor-y: <dy>px;
```

These mirror the `Offset` you passed in Dart. App stylesheets should
not repeat the numbers — read them via `var()`.

**One generic mixin handles every shape:**

```css
.fd-anchored {
  transform-origin: var(--fd-anchor-x) var(--fd-anchor-y);
  transition: transform 180ms ease-out, filter 180ms ease-out;
}
```

Add `fd-anchored` (or inline these two properties) to any marker class
and every `scale` / `rotate` / `translate` will pivot around the lat/lng
pixel — the visible anchor stays planted under hover/selection
animations.

| Marker shape | `anchorPx` | Hover effect example |
| --- | --- | --- |
| Pin (tip-anchored) | `Offset(w/2, h)` | `transform: scale(1.2)` grows from tip |
| Circle/dot (center-anchored) | `Offset(w/2, h/2)` | `transform: scale(1.3)` grows symmetrically around lat/lng |
| Card with arrow | wherever the arrow tip is drawn | `transform: translateY(-4px) scale(1.06)` lifts from arrow |
| Custom | any pixel | any transform pivots around that pixel |

**Effects that should NOT be anchored** — e.g. a halo ring pulsing
independently — should be applied to a child element (`::before` /
`::after`) with its own `transform-origin`. The wrapper is the
lat/lng-locked layer; children are free.

```css
.fd-pin             { width: 36px; height: 52px; background-image: url(...svg...); }
.fd-pin             { transform-origin: var(--fd-anchor-x) var(--fd-anchor-y); }
.fd-pin:hover       { transform: scale(1.2); }       /* tip planted */
.fd-pin.is-tapped   { animation: fd-bob 320ms ease-out; }

@keyframes fd-bob {
  0%, 100% { transform: scale(1); }
  50%      { transform: translateY(-8px) scale(1.08); }  /* lifts, settles back on tip */
}
```

---

## 5. Map setup gotchas

- **AdvancedMarker requires a Vector Map ID on web.** Verify in Google
  Cloud Console — a Raster Map ID renders nothing without a warning.
- **`mapId` cannot change** after the map widget mounts. To toggle
  between legacy `Marker` and `AdvancedMarker`, render two `GoogleMap`
  widgets side by side rather than swap one's `mapId`.
- **AdvancedMarker is DOM**, so app CSS must reach it. Link your
  stylesheet from `web/index.html`:

  ```html
  <link rel="stylesheet" href="fd_marker_styles.css">
  ```

  See `example/web/fd_marker_styles.css` for a complete demo set:
  `.fd-card`, `.fd-card__label`, `.fd-card__badge`, status modifiers
  (`.is-live`, `.is-busy`, `.is-offline`), selection state
  (`.is-selected`), and `@keyframes fd-pulse` / `fd-selected-bob` /
  `fd-courier-bob`.

---

## 6. New examples in this release

- `example/lib/fork_marker_features.dart` — side-by-side legacy vs
  AdvancedMarker, courier with heading rotation and a flowing-arrow
  polyline trail, zoom-tier reveal, hover-reveal truck pin.
- `example/lib/fork_polyline_animation.dart` — five polyline animation
  effects (arrow, chevron, dot, backward dash, custom diamond glyph).
- `example/lib/place_circle.dart` retrofit — hover-to-amber + breathing
  radius via `WebCircleAnimation`.
- `example/lib/place_polygon.dart` retrofit — fill and stroke colour
  cycling via `WebPolygonAnimation`.

---

## 7. Compatibility summary

- **No breaking changes.** Every new field is nullable or has a
  default; absent values reproduce pre-existing behaviour exactly.
- **Legacy `Marker`** continues to support `markerLabel`, `animate`,
  `onEnter`, `onExit`, all unchanged.
- **Cross-platform parity.** Web-only fields (`webOverlay`,
  `webAnimation`, polyline `webAnimation`, polygon `webAnimation`) are
  ignored on Android and iOS at runtime.
- **Tag** — `google_maps_flutter-fd-v2.17.0+15` (HEAD of
  `fd/main-05-2026-reapply` at the time of this guide).
