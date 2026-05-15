// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web/web.dart' as web;

import 'page.dart';

/// Demonstrates a richer HTML ↔ Dart bridge for advanced markers:
///
/// * Hovering a marker fires a Dart handler that initiates an async load of
///   mock detail data.
/// * While the load is in-flight, the customHtml renders a loading state in
///   the hover popup.
/// * Results are cached per marker; subsequent hovers are instant.
/// * The loaded popup carries multiple action buttons (favourite, directions,
///   call, select, refresh) all wired through the same `data-fd-action`
///   delegation pattern.
///
/// The on-screen log shows every cross-boundary event:
///   `[HTML]` lines are emitted from the DOM event listeners installed by
///           [WebMarkerOverlay.customize].
///   `[Dart]` lines come from the Dart handlers reached through the bridge.
class ForkMarkerCustomDemoPage extends GoogleMapExampleAppPage {
  const ForkMarkerCustomDemoPage({super.key, required this.mapId})
      : super(
          const Icon(Icons.extension),
          'Fork: marker customHtml / customize',
        );

  final String? mapId;

  @override
  Widget build(BuildContext context) {
    return _ForkMarkerCustomDemoBody(mapId: mapId);
  }
}

class _ForkMarkerCustomDemoBody extends StatefulWidget {
  const _ForkMarkerCustomDemoBody({required this.mapId});

  final String? mapId;

  @override
  State<_ForkMarkerCustomDemoBody> createState() =>
      _ForkMarkerCustomDemoBodyState();
}

enum _Glyph { coffee, bolt, hospital }

class _Place {
  const _Place({
    required this.id,
    required this.pos,
    required this.label,
    required this.glyph,
  });

  final String id;
  final LatLng pos;
  final String label;
  final _Glyph glyph;
}

/// Result of the mock async load.
class _Details {
  const _Details({
    required this.rating,
    required this.address,
    required this.hours,
    required this.phone,
    required this.tags,
  });

  final double rating;
  final String address;
  final String hours;
  final String phone;
  final List<String> tags;
}

class _LogEntry {
  _LogEntry(this.side, this.message) : at = DateTime.now();
  final String side;
  final String message;
  final DateTime at;
}

class _ForkMarkerCustomDemoBodyState extends State<_ForkMarkerCustomDemoBody> {
  static const LatLng _center = LatLng(59.9139, 10.7522);

  static const List<_Place> _places = <_Place>[
    _Place(
      id: 'p-coffee',
      pos: LatLng(59.9180, 10.7480),
      label: 'Tim Wendelboe',
      glyph: _Glyph.coffee,
    ),
    _Place(
      id: 'p-bolt',
      pos: LatLng(59.9120, 10.7600),
      label: 'Charge point',
      glyph: _Glyph.bolt,
    ),
    _Place(
      id: 'p-hospital',
      pos: LatLng(59.9210, 10.7580),
      label: 'Ullevål',
      glyph: _Glyph.hospital,
    ),
  ];

  final List<_LogEntry> _log = <_LogEntry>[];
  // Hover and selection state.
  String? _hoveredId;
  String? _selectedId;
  final Set<String> _favs = <String>{};
  // `null` value means "fetch in flight"; absent key means "never loaded".
  final Map<String, _Details?> _cache = <String, _Details?>{};

  // Debounce timer so a brief DOM swap (caused by the marker wrapper being
  // rebuilt during a state change) does not flicker the popup off and back on.
  Timer? _leaveTimer;

  @override
  void dispose() {
    _leaveTimer?.cancel();
    super.dispose();
  }

  void _appendLog(String side, String message) {
    setState(() {
      _log.insert(0, _LogEntry(side, message));
      if (_log.length > 16) {
        _log.removeLast();
      }
    });
  }

  // Pretend we're calling an API. Returns canned data after 2s.
  Future<_Details> _fetchMockDetails(String id) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    switch (id) {
      case 'p-coffee':
        return const _Details(
          rating: 4.8,
          address: 'Grüners gate 1, 0552 Oslo',
          hours: 'Open · closes 18:00',
          phone: '+47 22 00 00 01',
          tags: <String>['speciality', 'wifi', 'oat milk'],
        );
      case 'p-bolt':
        return const _Details(
          rating: 4.2,
          address: 'Storgata 12, 0184 Oslo',
          hours: '24/7 · 4 of 6 stalls free',
          phone: '+47 22 00 00 02',
          tags: <String>['ccs', '150 kW', 'roofed'],
        );
      case 'p-hospital':
        return const _Details(
          rating: 4.0,
          address: 'Kirkeveien 166, 0450 Oslo',
          hours: 'Emergency · open 24h',
          phone: '+47 22 11 80 80',
          tags: <String>['emergency', 'level-1', 'helipad'],
        );
      default:
        return const _Details(
          rating: 0,
          address: '',
          hours: '',
          phone: '',
          tags: <String>[],
        );
    }
  }

  /// Called from the JS `mouseenter` listener installed by [customize].
  void _onHover(String placeId) {
    _leaveTimer?.cancel();
    if (_hoveredId == placeId) {
      // Wrapper just rebuilt under the cursor — mouseenter re-fired but the
      // hover state already matches. No-op.
      return;
    }
    _appendLog('Dart', 'hover → $placeId');
    setState(() {
      _hoveredId = placeId;
    });
    if (!_cache.containsKey(placeId)) {
      _appendLog('Dart', 'cache miss · fetching details for $placeId');
      setState(() {
        _cache[placeId] = null; // mark as loading
      });
      unawaited(_fetchMockDetails(placeId).then((_Details d) {
        if (!mounted) {
          return;
        }
        _appendLog('Dart', 'fetch done · cached $placeId');
        setState(() {
          _cache[placeId] = d;
        });
      }));
    } else if (_cache[placeId] != null) {
      _appendLog('Dart', 'cache hit · $placeId');
    }
  }

  /// Called from the JS `mouseleave` listener. Debounced so the brief DOM
  /// swap caused by a marker rebuild (e.g. cache fill) does not collapse the
  /// popup.
  void _onLeave(String placeId) {
    _leaveTimer?.cancel();
    _leaveTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) {
        return;
      }
      if (_hoveredId == placeId) {
        _appendLog('Dart', 'leave · $placeId');
        setState(() {
          _hoveredId = null;
        });
      }
    });
  }

  /// Called from the click listener. Switches on the `data-fd-action` string.
  void _onAction(String placeId, String action) {
    _appendLog('Dart', 'action → marker=$placeId action=$action');
    switch (action) {
      case 'select':
        setState(() {
          _selectedId = _selectedId == placeId ? null : placeId;
        });
      case 'fav':
        setState(() {
          if (!_favs.add(placeId)) {
            _favs.remove(placeId);
          }
        });
      case 'directions':
        // Pure side-effect demo — log only.
        _appendLog('Dart', '  → would open directions to $placeId');
      case 'call':
        final phone = _cache[placeId]?.phone ?? '<unknown>';
        _appendLog('Dart', '  → tel:$phone');
      case 'refresh':
        _appendLog('Dart', '  → evict cache + refetch');
        setState(() {
          _cache.remove(placeId);
        });
        if (_hoveredId == placeId) {
          // Still hovering — kick off a fresh fetch immediately so the popup
          // shows the loading state rather than the "never loaded" state.
          setState(() {
            _cache[placeId] = null;
          });
          unawaited(_fetchMockDetails(placeId).then((_Details d) {
            if (!mounted) {
              return;
            }
            _appendLog('Dart', 'fetch done · cached $placeId');
            setState(() {
              _cache[placeId] = d;
            });
          }));
        }
      default:
        break;
    }
  }

  // ---- HTML helpers -------------------------------------------------------

  static const String _coffeeSvg =
      "<svg viewBox='0 0 16 16' width='16' height='16' aria-hidden='true'>"
      "<path fill='currentColor' d='M3 4h8a1 1 0 0 1 1 1v3h1.5a2.5 2.5 0 0 1 0 5H12v.5a1.5 1.5 0 0 1-1.5 1.5h-6A1.5 1.5 0 0 1 3 13.5V4Zm9 5v3h1.5a1.5 1.5 0 0 0 0-3H12Z'/>"
      '</svg>';
  static const String _boltSvg =
      "<svg viewBox='0 0 16 16' width='16' height='16' aria-hidden='true'>"
      "<path fill='currentColor' d='M9 1 3 9h4l-1 6 6-8H8l1-6Z'/>"
      '</svg>';
  static const String _hospitalSvg =
      "<svg viewBox='0 0 16 16' width='16' height='16' aria-hidden='true'>"
      "<path fill='currentColor' d='M7 2h2v3h3v2H9v3H7V7H4V5h3V2Zm-4 9h10v3H3v-3Z'/>"
      '</svg>';

  String _glyphSvg(_Glyph g) => switch (g) {
        _Glyph.coffee => _coffeeSvg,
        _Glyph.bolt => _boltSvg,
        _Glyph.hospital => _hospitalSvg,
      };

  /// Renders the popup as a string. Returned as part of [customHtml]; the
  /// plugin appends it inside the wrapper so hover state survives moving the
  /// cursor from the pill onto the popup buttons (no `mouseleave` because
  /// the popup is a descendant of the wrapper).
  String _popupHtml(_Place p) {
    if (_hoveredId != p.id) {
      return '';
    }
    final _Details? cached = _cache[p.id];
    if (!_cache.containsKey(p.id) || cached == null) {
      return "<div class='fd-popup fd-popup--loading'>"
          "<div class='fd-popup__spinner' aria-hidden='true'></div>"
          'Loading details…'
          '</div>';
    }
    final String tagsHtml = cached.tags
        .map((String t) => "<span class='fd-popup__tag'>$t</span>")
        .join();
    final bool isFav = _favs.contains(p.id);
    final bool isSelected = _selectedId == p.id;
    return "<div class='fd-popup'>"
        "<div class='fd-popup__head'>"
        "<span class='fd-popup__title'>${p.label}</span>"
        "<span class='fd-popup__rating'>★ ${cached.rating.toStringAsFixed(1)}</span>"
        '</div>'
        "<div class='fd-popup__row'>${cached.address}</div>"
        "<div class='fd-popup__row fd-popup__row--muted'>${cached.hours}</div>"
        "<div class='fd-popup__tags'>$tagsHtml</div>"
        "<div class='fd-popup__actions'>"
        "<button class='fd-popup__btn' data-fd-action='directions'>🧭 Directions</button>"
        "<button class='fd-popup__btn' data-fd-action='call'>📞 Call</button>"
        "<button class='fd-popup__btn${isFav ? ' is-on' : ''}' data-fd-action='fav'>"
        "${isFav ? '★' : '☆'} Fav</button>"
        "<button class='fd-popup__btn${isSelected ? ' is-on' : ''}' data-fd-action='select'>"
        "${isSelected ? '◉' : '○'} Pin</button>"
        "<button class='fd-popup__btn' data-fd-action='refresh'>⟳ Refresh</button>"
        '</div>'
        '</div>';
  }

  String _customHtmlFor(_Place p) {
    return "<span class='fd-custom-demo__glyph'>${_glyphSvg(p.glyph)}</span>"
        '${_popupHtml(p)}';
  }

  // ---- Bridge setup -------------------------------------------------------

  /// Builds the [customize] closure for one marker. The closure attaches
  /// `mouseenter`, `mouseleave` and delegated `click` listeners on the
  /// wrapper, all of which forward into Dart.
  ///
  /// Closure identity changes every rebuild because it captures the latest
  /// `this`. That's intentional: the plugin only fires `customize` when the
  /// overlay snapshot differs (via [customizeKey]), so the listener set is
  /// re-installed on a freshly-built wrapper element after every state-driven
  /// rebuild rather than every Flutter frame.
  void Function(Object wrapper) _bridgeFor(String placeId) {
    return (Object wrapperObj) {
      final wrapper = wrapperObj as web.HTMLElement;
      wrapper.addEventListener(
        'mouseenter',
        ((web.Event _) {
          web.console.log('[HTML] mouseenter $placeId'.toJS);
          _appendLog('HTML', 'mouseenter → $placeId');
          _onHover(placeId);
        }).toJS,
      );
      wrapper.addEventListener(
        'mouseleave',
        ((web.Event _) {
          web.console.log('[HTML] mouseleave $placeId'.toJS);
          _appendLog('HTML', 'mouseleave → $placeId');
          _onLeave(placeId);
        }).toJS,
      );
      wrapper.addEventListener(
        'click',
        ((web.Event event) {
          final target = event.target;
          if (target == null || !target.isA<web.HTMLElement>()) {
            return;
          }
          final el = target as web.HTMLElement;
          final String? action = el.getAttribute('data-fd-action');
          if (action == null) {
            return;
          }
          event.stopPropagation();
          web.console.log('[HTML] $placeId click action="$action"'.toJS);
          _appendLog('HTML', 'click → marker=$placeId action=$action');
          _onAction(placeId, action);
        }).toJS,
      );
    };
  }

  /// Encodes every piece of state the overlay snapshot depends on. When the
  /// returned value changes, the plugin rebuilds the wrapper and re-fires
  /// `customize`. When it stays the same, the wrapper is preserved as-is.
  String _customizeKeyFor(_Place p) {
    final bool hovered = _hoveredId == p.id;
    final String cacheState = !_cache.containsKey(p.id)
        ? 'none'
        : _cache[p.id] == null
            ? 'loading'
            : 'loaded';
    final bool fav = _favs.contains(p.id);
    final bool sel = _selectedId == p.id;
    return 'h=$hovered;c=$cacheState;f=$fav;s=$sel';
  }

  Set<Marker> _buildMarkers() {
    return _places.map((_Place p) {
      final String tone = switch (p.glyph) {
        _Glyph.coffee => 'tone-coffee',
        _Glyph.bolt => 'tone-bolt',
        _Glyph.hospital => 'tone-hospital',
      };
      final bool isSelected = _selectedId == p.id;
      final bool isFav = _favs.contains(p.id);
      final bool isHovered = _hoveredId == p.id;
      final String className = <String>[
        'fd-custom-demo',
        tone,
        if (isSelected) 'is-selected',
        if (isFav) 'is-fav',
        if (isHovered) 'is-hovered',
      ].join(' ');
      return AdvancedMarker(
        markerId: MarkerId(p.id),
        position: p.pos,
        webOverlay: WebMarkerOverlay(
          label: WebMarkerLabel(
            text: p.label,
            className: 'fd-custom-demo__label',
          ),
          className: className,
          customHtml: _customHtmlFor(p),
          customizeKey: _customizeKeyFor(p),
          customize: kIsWeb ? _bridgeFor(p.id) : null,
        ),
      );
    }).toSet();
  }

  // ---- UI -----------------------------------------------------------------

  Widget _logPanel() {
    return Container(
      width: 360,
      color: const Color(0xFF111827),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'HTML ↔ Dart bridge log',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'hovered=${_hoveredId ?? "none"} · selected=${_selectedId ?? "none"} · '
            'fav=${_favs.length} · cache=${_cache.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Divider(color: Colors.white24, height: 16),
          Expanded(
            child: _log.isEmpty
                ? const Text(
                    'Hover a marker · click ★/♥/⟳ in the popup',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  )
                : ListView.builder(
                    itemCount: _log.length,
                    itemBuilder: (BuildContext context, int i) {
                      final entry = _log[i];
                      final isHtml = entry.side == 'HTML';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: '[${entry.side}] ',
                                style: TextStyle(
                                  color: isHtml
                                      ? const Color(0xFFf472b6)
                                      : const Color(0xFF60a5fa),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: entry.message),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mapId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Set localMapId in lib/local_keys.dart (or pass '
            '--dart-define=GMAPS_MAP_ID=...) to enable this demo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: GoogleMap(
            mapId: widget.mapId,
            markerType: GoogleMapMarkerType.advancedMarker,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 13,
            ),
            markers: _buildMarkers(),
          ),
        ),
        _logPanel(),
      ],
    );
  }
}
