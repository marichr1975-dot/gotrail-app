import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/gps_service.dart';
import '../services/location_search_service.dart';
import '../services/organic_maps_search_bridge.dart';
import 'v8_choice_screen.dart';

class StartOverviewMapScreen extends StatefulWidget {
  final LatLng initialPosition;
  final String regionLabel;

  const StartOverviewMapScreen({
    super.key,
    required this.initialPosition,
    required this.regionLabel,
  });

  @override
  State<StartOverviewMapScreen> createState() =>
      _StartOverviewMapScreenState();
}

class _UiSearchResult {
  final String name;
  final String subtitle;
  final LatLng point;

  const _UiSearchResult(this.name, this.subtitle, this.point);
}

class _StartOverviewMapScreenState
    extends State<StartOverviewMapScreen> {
  static const _green = Color(0xFF20A85A);
  static const _blue = Color(0xFF0B5FD7);

  final _mapController = MapController();
  final _searchController = TextEditingController();

  Timer? _debounce;
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;

  late LatLng _position;
  double? _rawPhoneHeading;
  double? _trueNorthHeading;
  double? _gpsCourse;

  bool _searching = false;
  List<_UiSearchResult> _results = const [];
  LatLng? _selectedTarget;
  String? _selectedTargetLabel;

  // Le mappe sono orientate al Nord vero; il sensore del telefono restituisce
  // il Nord magnetico. Nell'area Veneto/Trentino/Friuli la correzione è circa +4°.
  static const double _magneticDeclinationCorrection = 4.0;

  // Calibrazione del sensore del Galaxy J6 usato nei test.
  // La freccia blu rappresenta la testa del telefono, non il Nord magnetico.
  static const double _deviceHeadingCalibration = -7.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;

    _gpsSub = GpsService.stream().listen((p) {
      if (!mounted) return;
      setState(() {
        _position = LatLng(p.latitude, p.longitude);

        // La direzione GPS è affidabile solo quando ci si sta muovendo.
        if (p.heading.isFinite && p.speed > 0.7) {
          _gpsCourse = (p.heading + 360) % 360;
        }
      });
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (!mounted || h == null || !h.isFinite) return;

      setState(() {
        // Freccia GPS: usa il valore RAW del sensore, quindi segue
        // direttamente la testa del telefono senza aggiungere declinazione.
        _rawPhoneHeading =
            (h + _deviceHeadingCalibration + 360) % 360;

        // Bussola: mantiene invece la correzione verso il Nord vero.
        _trueNorthHeading =
            (h + _magneticDeclinationCorrection + 360) % 360;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  double get _phoneDirection =>
      _rawPhoneHeading ?? _gpsCourse ?? 0.0;

  bool _looksLikePoiQuery(String value) {
    final q = value.trim().toLowerCase();
    const poiWords = [
      'rifugio',
      'ristorante',
      'malga',
      'baita',
      'hotel',
      'bar',
      'fontana',
      'cascata',
      'parcheggio',
      'sentiero',
      'lago',
    ];
    return poiWords.any((w) => q == w || q.startsWith('$w ') || q.contains(' $w '));
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();

    if (q.length < 2) {
      setState(() {
        _searching = false;
        _results = const [];
      });
      return;
    }

    final poiQuery = _looksLikePoiQuery(q);

    final localResults = poiQuery
        ? <_UiSearchResult>[]
        : LocationSearchService.instance
            .suggestions(q, limit: 6)
            .map(
              (r) => _UiSearchResult(
                r.label,
                'Località',
                r.point,
              ),
            )
            .toList(growable: false);

    setState(() {
      _results = localResults;
    });

    // Se l'utente ha scritto esattamente una località nota
    // (es. "Auronzo"), la mappa si sposta subito lì.
    final exact = poiQuery
        ? null
        : LocationSearchService.instance.exactLocalMatch(q);
    if (exact != null) {
      _selectedTarget = exact.point;
      _selectedTargetLabel = exact.label;
      _mapController.move(exact.point, 16.8);
    } else if (_selectedTargetLabel != q) {
      _selectedTarget = null;
      _selectedTargetLabel = null;
    }

    // Organic resta la sorgente principale quando il bridge nativo sarà attivo.
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _organicSearch(q, localResults),
    );
  }

  Future<void> _organicSearch(
    String query,
    List<_UiSearchResult> local,
  ) async {
    if (!mounted) return;
    setState(() => _searching = true);

    final organic =
        await OrganicMapsSearchBridge.instance.search(
      query: query,
      center: _position,
      radiusKm: 10,
    );

    if (!mounted ||
        query != _searchController.text.trim()) {
      return;
    }

    final converted = organic
        .map(
          (r) => _UiSearchResult(
            r.name,
            r.subtitle.isEmpty ? r.type : r.subtitle,
            r.point,
          ),
        )
        .toList(growable: false);

    if (converted.isNotEmpty) {
      setState(() {
        _searching = false;
        _results = converted;
      });
      return;
    }

    if (_looksLikePoiQuery(query)) {
      final aiPlaces =
          await LocationSearchService.instance.intelligentSuggestions(
        query,
        limit: 6,
      );
      if (!mounted ||
          query != _searchController.text.trim()) {
        return;
      }
      setState(() {
        _searching = false;
        _results = aiPlaces
            .map(
              (r) => _UiSearchResult(
                r.label,
                'Punto di interesse',
                r.point,
              ),
            )
            .toList(growable: false);
      });
      return;
    }

    setState(() {
      _searching = false;
      _results = local;
    });
  }

  Future<void> _submit(String value) async {
    final q = value.trim();
    if (q.isEmpty) return;

    final exact = _looksLikePoiQuery(q)
        ? null
        : LocationSearchService.instance.exactLocalMatch(q);
    if (exact != null) {
      _select(
        _UiSearchResult(
          exact.label,
          'Località',
          exact.point,
        ),
      );
      return;
    }

    if (_results.isNotEmpty) {
      _select(_results.first);
      return;
    }

    setState(() => _searching = true);
    try {
      final result =
          await LocationSearchService.instance.search(q);

      if (!mounted) return;
      if (result != null) {
        _select(
          _UiSearchResult(
            result.label,
            'Località',
            result.point,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nessun risultato per "$q".',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _select(_UiSearchResult result) {
    FocusScope.of(context).unfocus();

    _searchController.text = result.name;
    _searchController.selection =
        TextSelection.collapsed(
      offset: _searchController.text.length,
    );

    _mapController.move(result.point, 16.8);

    setState(() {
      _selectedTarget = result.point;
      _selectedTargetLabel = result.name;
      _results = const [];
    });
  }

  void _centerGps() {
    _mapController.move(_position, 16.5);
  }

  void _continueFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V8ChoiceScreen(
          mode: V8Mode.start,
          targetPoint: _selectedTarget,
          targetLabel: _selectedTargetLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneRad =
        _phoneDirection * math.pi / 180.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _position,
                initialZoom: 16.2,
                minZoom: 7,
                maxZoom: 18.8,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.example.gotr_ai',
                ),
                TileLayer(
                  urlTemplate:
                      'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.example.gotr_ai',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _position,
                      width: 62,
                      height: 62,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x44000000),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Transform.rotate(
                            angle: phoneRad,
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 8,
                  child: _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),

                // Pulsante INIZIA più piccolo.
                Positioned(
                  top: 10,
                  left: 106,
                  right: 106,
                  child: SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: _continueFlow,
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(
                        Icons.directions_walk_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'INIZIA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  right: 10,
                  top: 8,
                  child: _CompassWidget(
                    heading: _trueNorthHeading,
                  ),
                ),

                Positioned(
                  right: 12,
                  bottom: 84,
                  child: _RoundButton(
                    icon: Icons.my_location_rounded,
                    onTap: _centerGps,
                  ),
                ),

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_results.isNotEmpty)
                        Container(
                          constraints:
                              const BoxConstraints(
                            maxHeight: 230,
                          ),
                          margin:
                              const EdgeInsets.only(
                            bottom: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(17),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 5,
                            ),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final r = _results[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.place_rounded,
                                  color: _green,
                                ),
                                title: Text(
                                  r.name,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                                subtitle:
                                    r.subtitle.isEmpty
                                        ? null
                                        : Text(
                                            r.subtitle,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                onTap: () => _select(r),
                              );
                            },
                          ),
                        ),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onChanged,
                          onSubmitted: _submit,
                          textInputAction:
                              TextInputAction.search,
                          decoration: InputDecoration(
                            hintText:
                                'Cerca località',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _blue,
                            ),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding:
                                        EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassWidget extends StatelessWidget {
  final double? heading;

  const _CompassWidget({
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    // Se il sensore non ha ancora dato un valore, la N resta verso l'alto.
    // Quando arriva l'heading, la freccia rossa ruota in senso opposto
    // all'orientamento del telefono e indica fisicamente il Nord.
    final h = heading ?? 0.0;
    final northRad = -h * math.pi / 180.0;

    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 5,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: northRad,
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.red,
                size: 29,
              ),
            ),
            const Positioned(
              bottom: 2,
              child: Text(
                'N',
                style: TextStyle(
                  color: Color(0xFF172C43),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: const Color(0xFF12314A),
            size: 25,
          ),
        ),
      ),
    );
  }
}
