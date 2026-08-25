import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Theme;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../services/location_search_service.dart';
import '../services/mwm_map_service.dart';
import 'v8_choice_screen.dart';

class PlanningMapScreen extends StatefulWidget {
  const PlanningMapScreen({super.key});

  @override
  State<PlanningMapScreen> createState() => _PlanningMapScreenState();
}

class _PlanningMapScreenState extends State<PlanningMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();

  MbTiles? _mbtiles;
  bool _preparing = true;
  bool _downloading = false;
  bool _searching = false;
  List<LocationSearchResult> _suggestions = const [];
  Timer? _suggestionDebounce;
  int _suggestionRequestId = 0;
  String? _error;
  final int _receivedBytes = 0;
  final int _totalBytes = 0;
  String _activeMapName = 'mappa';
  LatLng _mapCenter = const LatLng(45.75, 11.85);

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    // 8.8: niente aggiornamenti/download automatici all'apertura di Pianifica.
    // Una MBTiles giÃ  presente (anche copiata via PowerShell) ha prioritÃ .
    if (mounted) setState(() => _preparing = false);
  }

  void _openMbTiles(File file) {
    _mbtiles?.dispose();
    _mbtiles = MbTiles(mbtilesPath: file.path, gzip: true);
  }

  Future<void> _goToPlace([LocationSearchResult? selected]) async {
    final text = _search.text.trim();
    if (text.isEmpty || _searching) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _suggestions = const [];
    });

    try {
      final found = selected ?? await LocationSearchService.instance.search(text);
      if (!mounted) return;

      if (found == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Non riesco a identificare "$text" nelle regioni disponibili. Controlla il nome e la connessione Internet.')),
        );
        return;
      }

      // V10.5 nuova: Pianifica NON scarica mappe.
      // Usa esclusivamente quelle scelte prima dall'utente nel menu Mappe.
      final mapSearchText = '${found.label} ${found.mapHint}'.trim();
      final mwm = await MwmMapService.instance.mapForTextAndPoint(
        mapSearchText,
        found.point,
      );
      if (!mounted) return;

      if (mwm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 7),
            content: Text(
              'Ho trovato ${found.label}, ma la mappa della sua provincia/regione non Ã¨ installata. '
              'Non userÃ² una mappa di unâ€™altra zona. Apri Mappe dalla Home e scarica la regione.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _activeMapName = mwm.regionLabel;
        _mapCenter = found.point;
        _downloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${mwm.regionLabel} MWM pronta Â· ${mwm.sizeLabel}')),
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => V8ChoiceScreen(
            mode: V8Mode.plan,
            initialPlace: found.label,
            targetPoint: found.point,
            targetLabel: found.label,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }


  void _updateSuggestions(String value) {
    _suggestionDebounce?.cancel();
    final query = value.trim();
    final requestId = ++_suggestionRequestId;

    if (query.length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      return;
    }

    _suggestionDebounce = Timer(const Duration(milliseconds: 650), () async {
      try {
        final results = await LocationSearchService.instance
            .intelligentSuggestions(query, limit: 5);
        if (!mounted || requestId != _suggestionRequestId) return;
        setState(() => _suggestions = results);
      } catch (_) {
        if (!mounted || requestId != _suggestionRequestId) return;
        setState(() => _suggestions = const []);
      }
    });
  }

  Future<void> _useSuggestion(LocationSearchResult result) async {
    _search.text = result.label;
    _search.selection = TextSelection.collapsed(offset: _search.text.length);
    setState(() => _suggestions = const []);
    await _goToPlace(result);
  }

  Theme _theme() => ThemeReader().read({
        'version': 8,
        'sources': {
          'openmaptiles': {'type': 'vector'}
        },
        'layers': [
          {'id': 'background', 'type': 'background', 'paint': {'background-color': '#f3f1e8'}},
          {'id': 'landcover', 'type': 'fill', 'source': 'openmaptiles', 'source-layer': 'landcover', 'paint': {'fill-color': '#dce9d2', 'fill-opacity': 0.78}},
          {'id': 'park', 'type': 'fill', 'source': 'openmaptiles', 'source-layer': 'park', 'paint': {'fill-color': '#cae4bf', 'fill-opacity': 0.80}},
          {'id': 'water', 'type': 'fill', 'source': 'openmaptiles', 'source-layer': 'water', 'paint': {'fill-color': '#9bcbea'}},
          {'id': 'waterway', 'type': 'line', 'source': 'openmaptiles', 'source-layer': 'waterway', 'paint': {'line-color': '#67acd7', 'line-width': 1.25}},
          {'id': 'buildings', 'type': 'fill', 'source': 'openmaptiles', 'source-layer': 'building', 'paint': {'fill-color': '#d8d1c8', 'fill-outline-color': '#bbb2a7'}},

          // Strade: base chiara, poi sentieri in evidenza sopra.
          {'id': 'roads-casing', 'type': 'line', 'source': 'openmaptiles', 'source-layer': 'transportation', 'paint': {'line-color': '#ffffff', 'line-width': 3.4}},
          {'id': 'roads', 'type': 'line', 'source': 'openmaptiles', 'source-layer': 'transportation', 'paint': {'line-color': '#ad9c85', 'line-width': 1.65}},
          {'id': 'trails', 'type': 'line', 'source': 'openmaptiles', 'source-layer': 'transportation', 'filter': ['in', 'class', 'path', 'track'], 'paint': {'line-color': '#b64a2e', 'line-width': 2.2, 'line-dasharray': [2, 1]}},

          // Numeri e nomi sentiero. Il layer transportation_name contiene ref/nome.
          {
            'id': 'trail-ref',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'transportation_name',
            'minzoom': 12,
            'filter': ['in', 'class', 'path', 'track'],
            'layout': {
              'symbol-placement': 'line',
              'text-field': '{ref}',
              'text-size': 11,
              'text-allow-overlap': false
            },
            'paint': {
              'text-color': '#7a2d1d',
              'text-halo-color': '#fffdf7',
              'text-halo-width': 1.5
            }
          },
          {
            'id': 'trail-name',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'transportation_name',
            'minzoom': 13,
            'filter': ['in', 'class', 'path', 'track'],
            'layout': {
              'symbol-placement': 'line',
              'text-field': '{name:latin}',
              'text-size': 10,
              'text-allow-overlap': false
            },
            'paint': {
              'text-color': '#5f3b2f',
              'text-halo-color': '#fffdf7',
              'text-halo-width': 1.3
            }
          },

          // LocalitÃ : finalmente nomi visibili sulla cartografia.
          {
            'id': 'place-labels',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'place',
            'minzoom': 8,
            'layout': {
              'text-field': '{name:latin}',
              'text-size': 13,
              'text-allow-overlap': false
            },
            'paint': {
              'text-color': '#263238',
              'text-halo-color': '#fffdf7',
              'text-halo-width': 1.8
            }
          },

          // Cime con nome e quota quando disponibile.
          {
            'id': 'peak-dot',
            'type': 'circle',
            'source': 'openmaptiles',
            'source-layer': 'mountain_peak',
            'minzoom': 11,
            'paint': {'circle-radius': 3.5, 'circle-color': '#5c5148', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 1.0}
          },
          {
            'id': 'peak-label',
            'type': 'symbol',
            'source': 'openmaptiles',
            'source-layer': 'mountain_peak',
            'minzoom': 11,
            'layout': {'text-field': '{name:latin}', 'text-size': 11, 'text-offset': [0, 1.0], 'text-allow-overlap': false},
            'paint': {'text-color': '#3f3934', 'text-halo-color': '#fffdf7', 'text-halo-width': 1.5}
          },

          // POI utili a GoTr-Ail. Usiamo simboli geometrici + testo, cosÃ¬ sono offline
          // e non dipendono da sprite esterni.
          {'id': 'hut-dot', 'type': 'circle', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 12, 'filter': ['in', 'subclass', 'alpine_hut', 'wilderness_hut'], 'paint': {'circle-radius': 5.2, 'circle-color': '#2f7d32', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 1.5}},
          {'id': 'hut-name', 'type': 'symbol', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 12, 'filter': ['in', 'subclass', 'alpine_hut', 'wilderness_hut'], 'layout': {'text-field': '{name:latin}', 'text-size': 11, 'text-offset': [0, 1.2], 'text-allow-overlap': false}, 'paint': {'text-color': '#155a1b', 'text-halo-color': '#ffffff', 'text-halo-width': 1.5}},

          {'id': 'parking-dot', 'type': 'circle', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 13, 'filter': ['==', 'subclass', 'parking'], 'paint': {'circle-radius': 5.0, 'circle-color': '#2566b1', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 1.4}},
          {'id': 'parking-p', 'type': 'symbol', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 13, 'filter': ['==', 'subclass', 'parking'], 'layout': {'text-field': 'P', 'text-size': 10, 'text-allow-overlap': true}, 'paint': {'text-color': '#ffffff'}},

          {'id': 'water-dot', 'type': 'circle', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 13, 'filter': ['==', 'subclass', 'drinking_water'], 'paint': {'circle-radius': 4.6, 'circle-color': '#168ac4', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 1.3}},
          {'id': 'water-name', 'type': 'symbol', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 14, 'filter': ['==', 'subclass', 'drinking_water'], 'layout': {'text-field': '{name:latin}', 'text-size': 10, 'text-offset': [0, 1.0], 'text-allow-overlap': false}, 'paint': {'text-color': '#0f5e89', 'text-halo-color': '#ffffff', 'text-halo-width': 1.3}},

          // Tutti gli altri POI nominati, discreti e solo a zoom alto.
          {'id': 'poi-labels', 'type': 'symbol', 'source': 'openmaptiles', 'source-layer': 'poi', 'minzoom': 14, 'layout': {'text-field': '{name:latin}', 'text-size': 9, 'text-allow-overlap': false}, 'paint': {'text-color': '#4e4e4e', 'text-halo-color': '#ffffff', 'text-halo-width': 1.2}},
        ],
      });


  String get _downloadLabel {
    final received = (_receivedBytes / 1024 / 1024).toStringAsFixed(1);
    if (_totalBytes > 0) {
      final total = (_totalBytes / 1024 / 1024).toStringAsFixed(1);
      final pct = ((_receivedBytes / _totalBytes) * 100).clamp(0, 100).round();
      return 'Scarico $_activeMapNameâ€¦ $pct%  ($received / $total MB)';
    }
    return 'Scarico $_activeMapNameâ€¦ $received MB';
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _search.dispose();
    _mbtiles?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_mbtiles != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 13.5,
                minZoom: 7,
                maxZoom: 18,
              ),
              children: [
                VectorTileLayer(
                  theme: _theme(),
                  tileProviders: TileProviders({
                    'openmaptiles': MbTilesVectorTileProvider(
                      mbtiles: _mbtiles!,
                      silenceTileNotFound: true,
                    ),
                  }),
                  maximumZoom: 18,
                ),
              ],
            )
          else
            Container(
              color: const Color(0xFFF3F1E8),
              alignment: Alignment.center,
              child: _preparing
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_rounded, size: 62, color: Color(0xFF4F9448)),
                          const SizedBox(height: 15),
                          const Text(
                            'Dove vuoi andare?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cerca una localitÃ  o un punto noto. GoTr-AI userÃ  soltanto le mappe che hai giÃ  scaricato dal menu Mappe.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, height: 1.35),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: IconButton(
                      onPressed: (_downloading || _searching) ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.white,
                          elevation: 4,
                          borderRadius: BorderRadius.circular(18),
                          child: TextField(
                            controller: _search,
                            enabled: !_downloading && !_searching,
                            textInputAction: TextInputAction.search,
                            onChanged: _updateSuggestions,
                            onSubmitted: (_) => _goToPlace(),
                            decoration: InputDecoration(
                              hintText: 'Dove vuoi andare?',
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF18539A)),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.4),
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: _downloading ? null : _goToPlace,
                                      icon: const Icon(Icons.arrow_forward_rounded),
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        if (_suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.40,
                            ),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              children: _suggestions.map((result) {
                                return InkWell(
                                  onTap: () => _useSuggestion(result),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.place_rounded,
                                          color: Color(0xFF18539A),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            result.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 12,
            bottom: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ricerca localitÃ  offline Veneto',
                  style: TextStyle(fontSize: 9, color: Colors.black54),
                ),
              ),
            ),
          ),

          if (_downloading)
            Positioned.fill(
              child: Container(
                color: const Color(0xB3000000),
                alignment: Alignment.center,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Preparazione mappa offline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: _totalBytes > 0 ? (_receivedBytes / _totalBytes).clamp(0.0, 1.0) : null,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      const SizedBox(height: 12),
                      Text(_downloadLabel, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Non chiudere lâ€™app durante il download.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


