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
