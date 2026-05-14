# AdvancedMarker `anchorPx` — positioning rules

Quick rules for web-only marker anchoring in `google_maps_flutter` fork.
`anchorPx` is the pixel inside the marker wrapper that sits on the map's
lat/lng. Mobile ignores this field — bake the visible anchor into the
`BitmapDescriptor`.

---

## Rule 1 — `anchorPx` is the pixel that lands on lat/lng

```
anchorPx: Offset(ax, ay)
```

Means: wrapper coordinate `(ax, ay)` sits on the marker's geographic
position. Everything else in the wrapper renders relative to that
single pixel.

```
+--------------------+
|                    |   wrapper top-left:  (lat-ax, lng-ay)
|        ▲           |   wrapper pixel (0,0) is up-left from lat/lng
|        |           |   wrapper pixel (ax,ay) IS lat/lng
|      (ax,ay) ◀━━ lat/lng pixel here
|                    |
+--------------------+
```

## Rule 2 — Pick `anchorPx` by shape

| Shape | Where the lat/lng should be | `anchorPx` |
| --- | --- | --- |
| Pin / teardrop | tip of the tail | `Offset(width/2, height)` |
| Circle / dot | geometric centre | `Offset(width/2, height/2)` |
| Card with arrow | base of the arrow | `Offset(arrow_x, arrow_y)` |
| Top-left badge | top-left corner | `Offset.zero` |
| Custom | anywhere | any pixel |

Wrapper width and height are whatever the wrapper's CSS class sizes it
to. The numbers in Dart and the numbers in CSS must agree.

## Rule 3 — Match the SVG / DOM to the anchor pixel

If the wrapper renders an inline SVG, the path's anchor vertex must be
drawn at the SAME pixel as `anchorPx`. A teardrop pin at
`Offset(18, 52)` needs an SVG path whose tip vertex is at `(18, 52)`
inside the SVG viewBox.

For a CSS-only marker (no SVG), the visible anchor pixel is wherever
the design naturally places it — e.g. a centred dot at 50%/50% lands on
lat/lng iff `anchorPx = Offset(width/2, height/2)`.

## Rule 4 — Use the CSS vars for transforms

The plugin publishes `anchorPx` as two custom properties on the
wrapper:

```
--fd-anchor-x: <ax>px;
--fd-anchor-y: <ay>px;
```

App stylesheets **must not** repeat the numbers. Reference the vars:

```css
.fd-pin {
  transform-origin: var(--fd-anchor-x) var(--fd-anchor-y);
  transition: transform 200ms ease-out;
}
.fd-pin:hover           { transform: scale(1.2); }     /* anchor planted */
.fd-pin.is-near         { transform: scale(1.4); }     /* tier-driven   */
.fd-pin.is-selected     { transform: scale(1.1) rotate(-2deg); }
```

Result: every `scale` / `rotate` / `translate` pivots around the lat/lng
pixel. The visible anchor never drifts off the map position.

## Rule 5 — Tier and hover transforms compose, not conflict

`WebZoomTier` flips classNames; CSS resolves the active rule. With
`transform-origin` set once on the base class, all variant rules inherit
the same pivot:

```css
.fd-pin            { transform-origin: var(--fd-anchor-x) var(--fd-anchor-y); }
.fd-pin.is-near    { transform: scale(1.4); }
.fd-pin:hover      { transform: scale(1.5); }      /* overrides is-near, same pivot */
```

Zoom in past the threshold → pin scales 1.0 → 1.4 around the anchor.
Hover at any zoom → bumps to 1.5 around the same anchor.

## Rule 6 — Anchored vs unanchored effects

Anchored effect (lat/lng stays glued):
- Apply transform to the **wrapper** (the element with the
  className from `webOverlay`).
- The wrapper carries the anchor vars.

Unanchored effect (independent ring pulse, drifting shadow, particle
spawn from a corner):
- Apply transform to a **child** (`::before` / `::after` or a
  nested element inside a label/badge slot).
- The child has its own `transform-origin`; set it explicitly.

```css
.fd-pin::after {                /* halo pulse — radiates from arbitrary point */
  content: '';
  position: absolute;
  inset: -8px;
  border-radius: 50%;
  border: 2px solid rgba(245, 158, 11, 0.7);
  transform-origin: center;      /* child decides its own pivot */
  animation: fd-halo 1.4s ease-out infinite;
}
```

## Rule 7 — When `anchorPx` is not set

Fallback: gmaps' default — content's bottom-centre sits on lat/lng.
That's usually fine for legacy `PinElement` markers. Custom DOM should
always declare `anchorPx` to keep behaviour predictable across:

- different content sizes (no DOM measurement),
- different gmaps releases (no reliance on internal anchor heuristics),
- hover/selection transforms (need a known pivot).

## Rule 8 — Mobile

`anchorPx` is web-only. Mobile uses the inherited ratio `anchor` field
to position the `BitmapDescriptor`. For visual parity, bake any
anchor offset into the bitmap itself.

---

## Checklist when adding a new web marker

- [ ] Decide wrapper size in CSS (`width`, `height`).
- [ ] Decide which pixel should sit on lat/lng → set `anchorPx`.
- [ ] If using SVG, draw the path so the anchor vertex matches.
- [ ] Add `transform-origin: var(--fd-anchor-x) var(--fd-anchor-y)`
      to the wrapper's class.
- [ ] Hover / zoom-tier / selected transforms now compose freely
      around the anchor.

See `example/lib/fork_anchor_px_demo.dart` for a four-variant demo
(centre, top-left, bottom-right, teardrop pin) verifying anchor
positioning against two crossing polylines through `LatLng(0, 0)`.
