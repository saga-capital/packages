# `WebMarkerOverlay` — custom HTML & DOM customization

Web-only escape hatches for `AdvancedMarker.webOverlay`. They let you put
arbitrary markup and arbitrary listeners on the marker wrapper without
forking the plugin. Mobile platforms ignore all three fields; bake equivalent
visuals into the `BitmapDescriptor` for mobile.

| Field | Type | What it does |
|-------|------|--------------|
| `customHtml` | `String?` | Raw HTML appended into the wrapper after `label` / `badge` |
| `customize` | `void Function(Object wrapper)?` | DOM mutator invoked with the wrapper element after everything else is in place |
| `customizeKey` | `Object?` | Equality key — controls when the wrapper is rebuilt and `customize` re-fires |
| `portal` | `WebMarkerPortal?` | Companion popup rendered outside the map container — escapes `overflow: hidden`, optionally enters the browser top layer |

---

## Rule 1 — `customHtml` is unsanitized

```dart
WebMarkerOverlay(
  customHtml: "<svg viewBox='0 0 16 16'>…</svg>",
)
```

Inserted with `element.insertAdjacentHTML('beforeend', ...)`. **Never
interpolate untrusted input** — use it for static markup (SVG glyphs,
decorative spans, prebuilt templates).

Use `label` / `badge` for dynamic text; they go through `textContent`,
which is XSS-safe.

## Rule 2 — `customize` is web-only

```dart
WebMarkerOverlay(
  customize: (Object wrapper) {
    final el = wrapper as web.HTMLElement; // package:web
    el.addEventListener('click', myHandler.toJS);
  },
)
```

The parameter type is `Object` so `WebMarkerOverlay` stays pure Dart and
compiles on mobile. Inside the closure, cast to `web.HTMLElement`. The
closure never runs on mobile, but its **body still has to compile**, so
either gate it with `kIsWeb` or use a conditional import.

It runs last — after `label`, `badge`, `customHtml`, and `rotation` have
been applied. The wrapper is fully built.

## Rule 3 — `customizeKey` controls refire

The plugin caches a snapshot of `(webOverlay, anchorPx, icon)` per
`MarkerId`. When `changeMarkers` produces an equal snapshot, the wrapper
element is preserved and `customize` does **not** refire.

The `customize` closure itself is excluded from `==`. Two overlays with
different closure refs but the same `customizeKey` are equal:

```dart
WebMarkerOverlay(customize: () { … }, customizeKey: 'v1') ==
WebMarkerOverlay(customize: () { … }, customizeKey: 'v1')   // true
```

Bump `customizeKey` whenever the closure's captured state changes and you
need it to refire:

```dart
customizeKey: '${marker.id}:hovered=$isHovered:loaded=$isLoaded',
```

Treat it like a React `key`.

## Rule 4 — Listeners survive across rebuilds when the snapshot is stable

When the wrapper element is preserved, every listener attached by
`customize` is preserved too. You can rely on this for hover / drag /
scroll state inside the marker.

When the snapshot changes, the wrapper is **replaced**, not mutated.
`customize` re-runs on the new element — re-attach your listeners every
time. Don't try to keep references to inner DOM nodes across rebuilds.

---

## Pattern A — Static decoration

Inline SVG, badges, decorative spans. No listeners needed. Static string
means the snapshot stays equal across all rebuilds; the wrapper is built
once.

```dart
WebMarkerOverlay(
  className: 'pill tone-blue',
  customHtml: "<span class='glyph'><svg …/></span>",
)
```

## Pattern B — Event delegation bridge

One listener on the wrapper. Buttons in `customHtml` carry
`data-fd-action="..."`; the listener reads the attribute and forwards to
Dart.

```dart
WebMarkerOverlay(
  customHtml:
      "<button data-fd-action='edit'>Edit</button>"
      "<button data-fd-action='delete'>Delete</button>",
  customizeKey: 'bridge:${marker.id}',
  customize: kIsWeb
      ? (Object wrapper) {
          (wrapper as web.HTMLElement).addEventListener(
            'click',
            ((web.Event e) {
              final t = e.target;
              if (t == null || !t.isA<web.HTMLElement>()) return;
              final action =
                  (t as web.HTMLElement).getAttribute('data-fd-action');
              if (action == null) return;
              e.stopPropagation(); // don't fire marker tap
              onAction(marker.id, action);
            }).toJS,
          );
        }
      : null,
)
```

`customizeKey` is constant per marker, so the listener attaches **once**
and survives subsequent `changeMarkers`.

## Pattern C — Async hover detail card

Hovering loads data; show loading, cache result, render details. The
detail card lives inside the wrapper so moving the cursor from the marker
to the card does not fire `mouseleave`.

```dart
// State
String? hoveredId;
final cache = <String, Details?>{}; // null = loading
Timer? leaveTimer;

void onHover(String id) {
  leaveTimer?.cancel();
  if (hoveredId == id) return;
  setState(() => hoveredId = id);
  if (!cache.containsKey(id)) {
    setState(() => cache[id] = null);          // loading
    fetchDetails(id).then((d) {
      if (!mounted) return;
      setState(() => cache[id] = d);            // loaded
    });
  }
}

void onLeave(String id) {
  // 60ms debounce absorbs the brief DOM swap when the wrapper rebuilds
  // (e.g. when the fetch resolves) under a stationary cursor.
  leaveTimer?.cancel();
  leaveTimer = Timer(const Duration(milliseconds: 60), () {
    if (mounted && hoveredId == id) {
      setState(() => hoveredId = null);
    }
  });
}

WebMarkerOverlay(
  customHtml: '<span class="glyph">…</span>${popupHtmlFor(marker)}',
  // Encodes every piece of state that affects the rendered HTML, so the
  // wrapper rebuilds exactly when the popup needs to change and not on
  // every Flutter frame.
  customizeKey: 'h=${hoveredId == id};c=${cacheState(id)}',
  customize: kIsWeb ? (Object w) {
    final el = w as web.HTMLElement;
    el.addEventListener('mouseenter', ((web.Event _) => onHover(id)).toJS);
    el.addEventListener('mouseleave', ((web.Event _) => onLeave(id)).toJS);
    // …plus click delegation as in Pattern B
  } : null,
)
```

Reference implementation:
[`example/lib/fork_marker_custom_demo.dart`](example/lib/fork_marker_custom_demo.dart).

---

## Gotchas

- **Don't put `transform` on the wrapper for rotation.** Use
  `WebMarkerOverlay.rotation`, which writes a `--fd-rotate` CSS variable
  the app references on the specific child that should turn. Rotating the
  wrapper rotates labels and badges too.
- **Don't measure DOM in `customize`.** It runs synchronously during
  marker build; layout is not finalized. Read DOM state from event
  listeners, not from the customize closure itself.
- **Tier classes win on the wrapper `className`.** If you set
  `zoomTiers`, the plugin overwrites `wrapper.className` on every zoom
  change with `'${baseClassName} ${activeTier}'`. Mutate child classes,
  not the wrapper, from `customize` if you also use tiers.
- **Use `event.stopPropagation()`** inside delegated button handlers if
  the marker also has an `onTap` — without it, clicks bubble up to the
  gmaps tap handler.
- **Mobile builds compile the closure body.** Either guard with
  `kIsWeb`, or move web-only imports behind a conditional import.

---

# `WebMarkerPortal` — popups outside the map

Marker DOM lives inside a clipped, transformed container (the gmaps map
element). Anything you append inside the wrapper is clipped at the map edge
and can't escape through `position: fixed`. `WebMarkerPortal` mounts a
separate DOM node on `document.body` (or the browser **top layer** via the
Popover API), and the plugin keeps its position in sync with the marker as
the camera moves.

| Field | Type | Default | What it does |
|-------|------|---------|--------------|
| `html` | `String` | required | Raw HTML for the portal element (unsanitized) |
| `className` | `String?` | `null` | CSS class on the portal element |
| `customize` | `void Function(Object portalEl)?` | `null` | DOM mutator on the portal element (event listeners, etc.) |
| `customizeKey` | `Object?` | `null` | Closure equality key — same semantics as on `WebMarkerOverlay` |
| `useTopLayer` | `bool` | `true` | Use Popover API top layer when available; falls back to plain portal |
| `placement` | `WebMarkerPortalPlacement` | `auto` | `above` / `below` / `left` / `right` / `auto` |
| `offset` | `double` | `8` | Gap between marker and popup, px |
| `viewportMargin` | `double` | `8` | Minimum gap from popup to viewport edge, px |

## How positioning works

The plugin writes these CSS custom properties on the portal element each
time the map moves, the window resizes, or the marker is updated:

```
--fd-marker-x   marker wrapper left,   viewport coords
--fd-marker-y   marker wrapper top
--fd-marker-w   marker wrapper width
--fd-marker-h   marker wrapper height
--fd-viewport-w window.innerWidth
--fd-viewport-h window.innerHeight
--fd-popup-w    portal element width
--fd-popup-h    portal element height
--fd-popup-left final clamped popup left,  viewport coords
--fd-popup-top  final clamped popup top
```

It also sets a `data-fd-placement="above|below|left|right"` attribute
indicating the resolved side (after `auto` flip + edge clamping).

**Recommended app CSS** — let the plugin do the layout math:

```css
.my-portal {
  position: fixed;
  left: var(--fd-popup-left);
  top:  var(--fd-popup-top);
}
.my-portal[data-fd-placement='above']::after { /* tail pointing down */ }
.my-portal[data-fd-placement='below']::after { /* tail pointing up */ }
```

For hand-rolled layouts, ignore `--fd-popup-left/top` and use the
lower-level marker + viewport vars directly.

## Edge avoidance

Two layers:

1. **Side flip** — only applies to `placement: auto`. The plugin compares
   the available room on each side of the marker and picks the side with
   the most space.
2. **Viewport clamp** — applies to every placement. After computing the
   ideal popup top-left, the plugin clamps both coordinates inside the
   viewport with `viewportMargin` padding. Forced sides (`above` etc.) do
   not flip even when clamped, so the popup may overlap the marker if
   there's no room on the chosen side.

## Top layer vs plain portal

`useTopLayer: true` (default) tries `showPopover()` first. When supported,
the element enters the browser **top layer** — guaranteed to paint above
every stacking context, regardless of ancestor transforms or
`overflow: hidden`. This is the safest path for hover cards over a
clipped map.

Browser support: Chrome 114+, Safari 17.0+, Firefox 125+, Samsung
Internet 25+, Chrome Android 114+, Safari iOS 17+. The plugin
feature-detects `showPopover` and falls back to a plain `document.body`
mount with `z-index: 99999` on older browsers — same CSS vars, same
positioning math, same `data-fd-placement` attribute. Apps don't need to
branch.

## Lifecycle

* App sets `portal` to non-null on the overlay → plugin mounts the node,
  starts listening to `bounds_changed`, `zoom_changed`, and `resize`.
* App sets `portal` to `null` (or replaces with a different config) →
  plugin unmounts the previous node and remounts with the new config.
* Marker removed → portal unmounted.
* No portal active on any marker → event listeners detached.

The portal config participates in `WebMarkerOverlay.==`, so the existing
diff-skip system also covers it: same portal config + same other fields →
the plugin does nothing.

## Pattern D — Hover card outside the map

Drives portal mount via Dart state. The hover state itself is wired
through `customize` on the wrapper (mouseenter / mouseleave forwarders).

```dart
String? hoveredId;

WebMarkerOverlay(
  customizeKey: 'wrap:${marker.id}',
  customize: kIsWeb ? (Object w) {
    final el = w as web.HTMLElement;
    el.addEventListener('mouseenter', ((web.Event _) {
      setState(() => hoveredId = marker.id);
    }).toJS);
    el.addEventListener('mouseleave', ((web.Event _) {
      setState(() => hoveredId = null);
    }).toJS);
  } : null,
  portal: hoveredId == marker.id
      ? WebMarkerPortal(
          html: '<div class="card">…</div>',
          className: 'my-portal',
          placement: WebMarkerPortalPlacement.auto,
        )
      : null,
)
```

Reference implementations:
* [`example/lib/fork_marker_portal_demo.dart`](example/lib/fork_marker_portal_demo.dart)
  — baseline (clipped) vs portal vs popover.
* [`example/lib/fork_marker_placement_demo.dart`](example/lib/fork_marker_placement_demo.dart)
  — switches between the five placements and demonstrates edge clamping.
