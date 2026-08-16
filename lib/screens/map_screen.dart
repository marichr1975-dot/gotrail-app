
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/map_models.dart';
import '../models/map_package.dart';
import '../models/saved_route.dart';
import '../services/gps_service.dart';
import '../services/hiking_router.dart';
import '../services/local_router.dart';
import '../services/map_package_manager.dart';
import '../services/offline_map_service.dart';
import '../services/saved_routes_service.dart';
import 'navigation_screen.dart';


enum _WalkKind {
  children,
  dog,
  woods,
  adventure,
}

extension _WalkKindUi on _WalkKind {
  String get label => switch (this) {
        _WalkKind.children => 'Passeggiata bambini',
        _WalkKind.dog => 'Passeggiata con il cane',
        _WalkKind.woods => 'Passeggiata nel bosco',
        _WalkKind.adventure => 'Sentiero avventuroso',
      };

  IconData get icon => switch (this) {
        _WalkKind.children => Icons.family_restroom_rounded,
        _WalkKind.dog => Icons.pets_rounded,
        _WalkKind.woods => Icons.forest_rounded,
        _WalkKind.adventure => Icons.terrain_rounded,
      };
}

class _PlannerChoice {
  final _WalkKind kind;
  final double distanceKm;
  final bool loop;

  const _PlannerChoice({
    required this.kind,
    required this.distanceKm,
    required this.loop,
  });
}

class _RouteCandidate {
  final LatLng point;
  final double meters;
  final double bearing;
  final double aiPenalty;

  const _RouteCandidate({
    required this.point,
    required this.meters,
    required this.bearing,
    required this.aiPenalty,
  });
}

class _PlannerSheet extends StatefulWidget {
  const _PlannerSheet();

  @override
  State<_PlannerSheet> createState() => _PlannerSheetState();
}

class _PlannerSheetState extends State<_PlannerSheet> {
  _WalkKind _kind = _WalkKind.children;
  double _distanceKm = 4;
  bool _loop = true;

  static const _distances = <double>[2, 4, 6];
  static const _visibleKinds = <_WalkKind>[
    _WalkKind.children,
    _WalkKind.dog,
    _WalkKind.woods,
  ];

  String get _hint => switch (_distanceKm.toInt()) {
        2 => 'Passeggiata tranquilla, senza sforzi.',
        4 => 'Passeggiata più impegnativa.',
        _ => 'Passeggiata più intensa.',
      };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.height < 700;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * .92),
        margin: const EdgeInsets.fromLTRB(10, 18, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAF7),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24)],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 10, 14, compact ? 10 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(99))),
              SizedBox(height: compact ? 8 : 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Che passeggiata vuoi?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              SizedBox(height: compact ? 8 : 12),
              Row(
                children: [
                  for (var i = 0; i < _visibleKinds.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(child: _PlannerKindCard(kind: _visibleKinds[i], selected: _visibleKinds[i] == _kind, onTap: () => setState(() => _kind = _visibleKinds[i]))),
                  ],
                ],
              ),
              SizedBox(height: compact ? 10 : 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Distanza desiderata', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  for (var i = 0; i < _distances.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(child: _DistanceCard(km: _distances[i], selected: _distanceKm == _distances[i], onTap: () => setState(() => _distanceKm = _distances[i]))),
                  ],
                ],
              ),
              SizedBox(height: compact ? 9 : 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 54,
                decoration: BoxDecoration(
                  color: _loop ? const Color(0xFFEAF4E8) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x18000000)),
                ),
                child: Row(children: [
                  const Icon(Icons.loop_rounded, color: Color(0xFF278234), size: 27),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('Giro ad anello', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                  Switch(value: _loop, activeTrackColor: const Color(0xFF278234), onChanged: (v) => setState(() => _loop = v)),
                ]),
              ),
              SizedBox(height: compact ? 9 : 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF278234), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.pop(context, _PlannerChoice(kind: _kind, distanceKm: _distanceKm, loop: _loop)),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Crea con Ai', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 9),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFFF0F5EF), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.psychology_alt_rounded, color: Color(0xFF278234), size: 21),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_hint, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final double km;
  final bool selected;
  final VoidCallback onTap;
  const _DistanceCard({required this.km, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = km.toInt();
    final icon = n == 2 ? Icons.location_on_rounded : n == 4 ? Icons.route_rounded : Icons.terrain_rounded;
    final subtitle = n == 2 ? 'Tranquilla' : n == 4 ? 'Più impegnativa' : 'Più intensa';
    final accent = n == 6 ? const Color(0xFFE56A00) : n == 4 ? const Color(0xFF18539A) : const Color(0xFF278234);
    return Material(
      color: selected ? accent.withValues(alpha: .12) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? accent : accent.withValues(alpha: .22), width: selected ? 1.7 : 1)),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: accent, size: 25),
                const SizedBox(height: 2),
                Text('$n km', style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(subtitle, style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerKindCard extends StatelessWidget {
  final _WalkKind kind;
  final bool selected;
  final VoidCallback onTap;

  const _PlannerKindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF347A3A) : const Color(0xFF465267);
    return Material(
      color: selected ? const Color(0xFFDFF0DD) : Colors.white,
      elevation: selected ? 0 : 1,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: SizedBox(
          height: 88,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(kind.icon, color: color, size: 29),
                const SizedBox(height: 5),
                Text(
                  kind.label.replaceFirst('Passeggiata ', ''),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, height: 1.05),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final MapPackage package;
  final LatLng initialPosition;
  final bool useGps;

  const MapScreen({
    super.key,
    required this.package,
    required this.initialPosition,
    this.useGps = true,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();

  OfflineArea? _area;
  OfflineArea? _nearbyArea;
  late LatLng _position;
  String? _error;
  bool _loading = true;
  bool _routing = false;
  List<LatLng> _route = const [];
  bool _routePreview = false;
  String _previewTitle = '';
  StreamSubscription? _gpsSub;
  int _plannerSeed = 0;

  static const double _radiusKm = 10.0;
  static const double _trailRadiusKm = 5.0;
  static const double _parkingRadiusKm = 2.0;
  static const double _fountainRadiusKm = 2.0;
  static const double _fountainFallbackRadiusKm = 5.0;
  static const double _refugeRadiusKm = 10.0;

  bool get _insidePackage => widget.package.contains(_position);

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _start();
  }

  Future<void> _start() async {
    try {
      // Le quattro funzioni della schermata operativa usano ancora
      // temporaneamente il pacchetto GeoJSON della zona.
      // Se manca, lo scarichiamo automaticamente in background.
      final installed =
          await MapPackageManager.instance.isInstalled(widget.package);

      if (!installed) {
        await MapPackageManager.instance.download(
          widget.package,
          onProgress: (_) {
            // Download silenzioso: la schermata mantiene il loader esistente.
          },
        );

        OfflineMapService.instance.clearCache();
      }

      final area = await OfflineMapService.instance.loadNearby(
        widget.package,
        center: _position,
        radiusKm: 10.5,
      );
      if (!mounted) return;

      setState(() {
        _area = area;
        _nearbyArea = _buildNearbyArea(area, _position);
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.move(_position, widget.useGps ? 15.5 : 13.8);
      });

      if (widget.useGps) {
        _gpsSub?.cancel();
        _gpsSub = GpsService.stream().listen((p) {
          if (!mounted) return;

          final next = LatLng(p.latitude, p.longitude);
          final moved = Geolocator.distanceBetween(
            _position.latitude,
            _position.longitude,
            next.latitude,
            next.longitude,
          );

          setState(() {
            _position = next;
            if (moved > 500 && _area != null) {
              _nearbyArea = _buildNearbyArea(_area!, next);
            }
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  OfflineArea _buildNearbyArea(OfflineArea source, LatLng center) {
    final latDelta = _radiusKm / 111.0;
    final lonDelta =
        _radiusKm / (111.0 * _cosDegrees(center.latitude).abs().clamp(.25, 1.0));

    bool inBox(LatLng p) {
      return p.latitude >= center.latitude - latDelta &&
          p.latitude <= center.latitude + latDelta &&
          p.longitude >= center.longitude - lonDelta &&
          p.longitude <= center.longitude + lonDelta;
    }

    final trails = source.trails.where((trail) {
      if (trail.points.isEmpty) return false;
      // Prova punti distribuiti lungo la geometria, non tutti:
      // riduce il lavoro sui telefoni meno recenti.
      final step = (trail.points.length / 8).ceil().clamp(1, 1000000);
      for (var i = 0; i < trail.points.length; i += step) {
        if (inBox(trail.points[i])) return true;
      }
      return inBox(trail.points.last);
    }).toList();

    final pois = source.pois.where((poi) => inBox(poi.point)).toList();

    return OfflineArea(
      name: source.name,
      trails: trails,
      pois: pois,
    );
  }

  double _cosDegrees(double value) {
    // Approssimazione sufficiente per il filtro di rendering locale.
    final x = value * 0.017453292519943295;
    final x2 = x * x;
    final x4 = x2 * x2;
    final x6 = x4 * x2;
    return 1 - x2 / 2 + x4 / 24 - x6 / 720;
  }

  void _centerGps() {
    _controller.move(_position, 15.5);
  }


  void _showWholeRoute(List<LatLng> points) {
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );

    _controller.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(26, 100, 26, 170),
      ),
    );
  }

  double _poiRadiusKm(PoiType type) => switch (type) {
        PoiType.parcheggio => _parkingRadiusKm,
        PoiType.fontana => _fountainRadiusKm,
        PoiType.rifugio => _refugeRadiusKm,
        PoiType.panorama => _radiusKm,
      };

  bool _poiWithinRadius(MapPoi poi, double radiusKm) {
    final meters = Geolocator.distanceBetween(
      _position.latitude,
      _position.longitude,
      poi.point.latitude,
      poi.point.longitude,
    );
    return meters <= radiusKm * 1000.0;
  }

  int _poiCountWithin(PoiType type) {
    final area = _nearbyArea;
    if (area == null) return 0;
    final radiusKm = _poiRadiusKm(type);
    return area.pois.where((p) => p.type == type && _poiWithinRadius(p, radiusKm)).length;
  }

  int _trailCountWithin(double radiusKm) {
    final area = _nearbyArea;
    if (area == null) return 0;

    final radiusMeters = radiusKm * 1000.0;
    var count = 0;
    for (final trail in area.trails) {
      if (trail.points.isEmpty) continue;
      final step = (trail.points.length / 8).ceil().clamp(1, 1000000);
      var nearby = false;
      for (var i = 0; i < trail.points.length; i += step) {
        final p = trail.points[i];
        if (Geolocator.distanceBetween(
              _position.latitude,
              _position.longitude,
              p.latitude,
              p.longitude,
            ) <=
            radiusMeters) {
          nearby = true;
          break;
        }
      }
      if (!nearby) {
        final p = trail.points.last;
        nearby = Geolocator.distanceBetween(
              _position.latitude,
              _position.longitude,
              p.latitude,
              p.longitude,
            ) <=
            radiusMeters;
      }
      if (nearby) count++;
    }
    return count;
  }

  List<MapPoi> _nearestPois(PoiType type, {double? radiusKm}) {
    final area = _nearbyArea;
    if (area == null) return const [];

    final effectiveRadiusKm = radiusKm ?? _poiRadiusKm(type);
    final result = area.pois
        .where((p) => p.type == type && _poiWithinRadius(p, effectiveRadiusKm))
        .toList();

    result.sort((a, b) {
      final da = Geolocator.distanceBetween(
        _position.latitude,
        _position.longitude,
        a.point.latitude,
        a.point.longitude,
      );
      final db = Geolocator.distanceBetween(
        _position.latitude,
        _position.longitude,
        b.point.latitude,
        b.point.longitude,
      );
      return da.compareTo(db);
    });

    return result;
  }

  String _distanceLabel(MapPoi poi) {
    final meters = Geolocator.distanceBetween(
      _position.latitude,
      _position.longitude,
      poi.point.latitude,
      poi.point.longitude,
    );

    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _showPoiList(PoiType type) async {
    final pois = _nearestPois(type);

    if (pois.isEmpty) {
      final label = switch (type) {
        PoiType.rifugio => 'rifugi',
        PoiType.fontana => 'fontane',
        PoiType.panorama => 'punti panoramici',
        PoiType.parcheggio => 'parcheggi',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nessun $label vicino alla tua posizione.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final title = switch (type) {
          PoiType.rifugio => 'Rifugi vicini',
          PoiType.fontana => 'Fontane vicine',
          PoiType.panorama => 'Panorami vicini',
          PoiType.parcheggio => 'Parcheggi vicini',
        };

        return DraggableScrollableSheet(
          initialChildSize: .65,
          minChildSize: .35,
          maxChildSize: .9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F6F2),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        itemCount: pois.length > 20 ? 20 : pois.length,
                        itemBuilder: (_, index) {
                          final poi = pois[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                type == PoiType.rifugio
                                    ? Icons.cottage_rounded
                                    : type == PoiType.fontana
                                        ? Icons.water_drop_rounded
                                        : type == PoiType.parcheggio
                                            ? Icons.local_parking_rounded
                                            : Icons.visibility_rounded,
                                color: const Color(0xFF4F9448),
                              ),
                              title: Text(
                                poi.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(_distanceLabel(poi)),
                              trailing: const Icon(Icons.navigation_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _routeTo(poi);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _routeTo(MapPoi poi) async {
    final area = _nearbyArea;
    if (area == null || _routing) return;

    setState(() => _routing = true);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final local = LocalRouter.route(
      start: _position,
      destination: poi.point,
      area: area,
    );

    List<LatLng> route = local.points;
    String message = local.message;

    if (!local.found) {
      final online = await HikingRouter.instance.route(
        start: _position,
        destination: poi.point,
      );

      if (online.available) {
        route = online.points;
        message = 'Percorso trovato usando il routing pedonale online.';
      } else {
        message = online.message;
      }
    }

    if (!mounted) return;

    setState(() {
      _routing = false;
      _route = route;
    });

    if (route.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    // PIANIFICA lavora sulle coordinate della localita scelta. Il GPS reale
    // non deve mai aprire la navigazione o produrre avvisi Fuori rotta.
    if (!widget.useGps) {
      setState(() {
        _routePreview = true;
        _previewTitle = poi.name;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWholeRoute(route);
      });
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          route: route,
          destinationName: poi.name,
          initialPosition: _position,
        ),
      ),
    );
  }

  Future<bool> _askNavigate(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('NO'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('SÌ, PORTAMI'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openNearestParking() async {
    final pois = _nearestPois(PoiType.parcheggio);
    if (pois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun parcheggio trovato entro 2 km.')),
      );
      return;
    }
    final poi = pois.first;
    final yes = await _askNavigate(
      'Parcheggio più vicino',
      '${poi.name} • ${_distanceLabel(poi)}\n\nVuoi che Google Maps ti porti al parcheggio?',
    );
    if (!yes || !mounted) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${poi.point.latitude},${poi.point.longitude}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNearestFountain() async {
    final walkingPois = _nearestPois(PoiType.fontana);

    if (walkingPois.isNotEmpty) {
      final poi = walkingPois.first;
      final yes = await _askNavigate(
        'Fontana più vicina',
        '${poi.name} • ${_distanceLabel(poi)}\n\nVuoi che GoTr-AI ti porti a piedi?',
      );
      if (yes && mounted) await _routeTo(poi);
      return;
    }

    final drivingPois = _nearestPois(
      PoiType.fontana,
      radiusKm: _fountainFallbackRadiusKm,
    );

    if (drivingPois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna fontana trovata entro 5 km.')),
      );
      return;
    }

    final poi = drivingPois.first;
    final yes = await _askNavigate(
      'Fontana più vicina',
      'Nessuna fontana entro 2 km.\n\n${poi.name} • ${_distanceLabel(poi)}\n\nVuoi che Google Maps ti porti in auto?',
    );
    if (!yes || !mounted) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${poi.point.latitude},${poi.point.longitude}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openRefuges() => _showPoiList(PoiType.rifugio);

  void _showExplore() {
    // Compatibilità con vecchi richiami: apre direttamente il planner AI.
    // La schermata legacy 'Cosa c’è qui?' è stata eliminata dalla 4.11.
    _showAssistant();
  }


  Future<void> _showAssistant() async {
    final choice = await showModalBottomSheet<_PlannerChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PlannerSheet(),
    );

    if (choice == null || !mounted) return;

    await _createSuggestedRoute(choice);
  }

  Future<void> _createSuggestedRoute(
    _PlannerChoice choice,
  ) async {
    final area = _nearbyArea;

    if (area == null || area.trails.isEmpty || _routing) return;

    setState(() => _routing = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _plannerSeed++;

    final targetMeters = choice.distanceKm * 1000.0;
    final candidates = <_RouteCandidate>[];

    for (final trail in area.trails) {
      if (trail.points.isEmpty) continue;
      if (choice.kind == _WalkKind.children && _isUnsafeForChildren(trail)) {
        continue;
      }

      final step = (trail.points.length / 6).ceil().clamp(1, 1000000);
      for (var i = 0; i < trail.points.length; i += step) {
        final point = trail.points[i];
        final meters = Geolocator.distanceBetween(
          _position.latitude,
          _position.longitude,
          point.latitude,
          point.longitude,
        );

        // Per un anello da 2-4 km non ha senso scegliere una meta a 3-6 km:
        // era una delle cause dei percorsi da 8-10 km.
        final maxCandidateMeters = choice.loop
            ? (targetMeters * .55).clamp(900.0, 2800.0)
            : (targetMeters * .70).clamp(1200.0, 5000.0);
        if (meters < 220 || meters > maxCandidateMeters) continue;

        candidates.add(
          _RouteCandidate(
            point: point,
            meters: meters,
            bearing: _bearingDegrees(_position, point),
            aiPenalty: _trailAiPenalty(choice, trail),
          ),
        );
      }
    }

    if (candidates.length < 4) {
      if (!mounted) return;
      setState(() => _routing = false);
      _plannerMessage(
        'Non trovo abbastanza percorsi adatti vicino al punto scelto.',
      );
      return;
    }

    final preferredBearing =
        (((_plannerSeed * 73) + choice.kind.index * 47) % 360).toDouble();

    double angularDistance(double a, double b) {
      final d = (a - b).abs();
      return d > 180 ? 360 - d : d;
    }

    // Per gli anelli la meta geometrica deve essere molto piu vicina della
    // meta usata in precedenza: l'andata + il ritorno laterale moltiplicano
    // rapidamente la distanza reale.
    final destinationTarget = choice.loop
        ? targetMeters * .28
        : switch (choice.kind) {
            _WalkKind.children => targetMeters * .40,
            _WalkKind.dog => targetMeters * .45,
            _WalkKind.woods => targetMeters * .48,
            _WalkKind.adventure => targetMeters * .52,
          };

    final destinationPool = [...candidates]
      ..sort((a, b) {
        double score(_RouteCandidate c) =>
            (c.meters - destinationTarget).abs() +
            angularDistance(c.bearing, preferredBearing) * 7 +
            c.aiPenalty;
        return score(a).compareTo(score(b));
      });

    List<LatLng>? bestRoute;
    LatLng? bestDestination;
    var bestScore = double.infinity;
    double? nearestRejectedKm;

    // Non accettiamo il primo risultato del router. Proviamo piu mete e
    // scegliamo il percorso che rispetta davvero distanza e forma richiesta.
    final attempts = destinationPool.take(choice.loop ? 5 : 4).toList();

    for (var index = 0; index < attempts.length; index++) {
      final destination = attempts[index];
      HikingRouteResult result;

      if (choice.loop) {
        final viaDistance = destination.meters * .62;

        _RouteCandidate pickSide(double wantedBearing, LatLng avoidPoint) {
          final pool = [...candidates]
            ..sort((a, b) {
              double score(_RouteCandidate c) {
                final sideBearing =
                    angularDistance(c.bearing, wantedBearing) * 15;
                final sideDistance = (c.meters - viaDistance).abs();
                final separation = Geolocator.distanceBetween(
                  c.point.latitude,
                  c.point.longitude,
                  avoidPoint.latitude,
                  avoidPoint.longitude,
                );
                final separationPenalty =
                    separation < 250 ? (250 - separation) * 9 : 0.0;
                return sideBearing + sideDistance + separationPenalty + c.aiPenalty;
              }
              return score(a).compareTo(score(b));
            });
          return pool.first;
        }

        final spread = 48.0 + (index * 8.0);
        final viaOut = pickSide(
          (destination.bearing + 360 - spread) % 360,
          destination.point,
        );
        final viaBack = pickSide(
          (destination.bearing + spread) % 360,
          viaOut.point,
        );

        result = await HikingRouter.instance.routeLoop(
          start: _position,
          destination: destination.point,
          viaOut: viaOut.point,
          viaBack: viaBack.point,
        );
      } else {
        result = await HikingRouter.instance.routeThrough([
          _position,
          destination.point,
        ]);
      }

      if (!result.available) continue;

      final actualKm = _routeLengthKm(result.points);
      final previousRejectedKm = nearestRejectedKm;
      nearestRejectedKm = previousRejectedKm == null ||
              (actualKm - choice.distanceKm).abs() <
                  (previousRejectedKm - choice.distanceKm).abs()
          ? actualKm
          : previousRejectedKm;

      // La distanza e un obiettivo, non un valore rigido. Accettiamo fino a
      // +30% (es. 5.2 km per una richiesta da 4), ma non 9 km.
      final minKm = choice.distanceKm * .70;
      final maxKm = choice.distanceKm * 1.30;
      if (actualKm < minKm || actualKm > maxKm) continue;

      if (choice.loop &&
          !_isUsefulLoop(result.points, _position, destination.point)) {
        continue;
      }

      final overlapPenalty = choice.loop ? _routeOverlapRatio(result.points) * 4 : 0.0;
      final score = (actualKm - choice.distanceKm).abs() + overlapPenalty;
      if (score < bestScore) {
        bestScore = score;
        bestRoute = result.points;
        bestDestination = destination.point;
      }
    }

    if (!mounted) return;
    setState(() => _routing = false);

    if (bestRoute == null || bestDestination == null) {
      final extra = nearestRejectedKm == null
          ? ''
          : ' Il piu vicino che ho trovato e ${nearestRejectedKm.toStringAsFixed(1)} km.';
      _plannerMessage(
        choice.loop
            ? 'Non trovo un vero anello adatto di circa ${choice.distanceKm.toStringAsFixed(0)} km.$extra Prova CAMBIA PERCORSO.'
            : 'Non trovo un percorso adatto di circa ${choice.distanceKm.toStringAsFixed(0)} km.$extra Prova CAMBIA PERCORSO.',
      );
      return;
    }

    setState(() {
      _route = bestRoute!;
      _routePreview = true;
      _previewTitle = choice.loop
          ? '${choice.kind.label} • anello'
          : choice.kind.label;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWholeRoute(bestRoute!);
    });
  }

  bool _isUsefulLoop(
    List<LatLng> route,
    LatLng start,
    LatLng destination,
  ) {
    if (route.length < 10) return false;

    final finishDistance = Geolocator.distanceBetween(
      route.last.latitude,
      route.last.longitude,
      start.latitude,
      start.longitude,
    );

    if (finishDistance > 80) return false;

    // Cerchiamo la posizione della meta all'interno della traccia.
    var destinationIndex = 0;
    var best = double.infinity;

    for (var i = 0; i < route.length; i++) {
      final d = Geolocator.distanceBetween(
        route[i].latitude,
        route[i].longitude,
        destination.latitude,
        destination.longitude,
      );

      if (d < best) {
        best = d;
        destinationIndex = i;
      }
    }

    if (destinationIndex < 2 ||
        destinationIndex > route.length - 3) {
      return false;
    }

    // Confrontiamo punti centrali di andata e ritorno:
    // se sono praticamente sovrapposti è ancora un avanti/indietro.
    final outMid = route[destinationIndex ~/ 2];
    final backMid =
        route[destinationIndex + ((route.length - destinationIndex) ~/ 2)];

    final separation = Geolocator.distanceBetween(
      outMid.latitude,
      outMid.longitude,
      backMid.latitude,
      backMid.longitude,
    );

    // Un vero anello deve avere anche poca sovrapposizione fra andata e ritorno.
    final overlap = _routeOverlapRatio(route);
    return separation >= 120 && overlap < .45;
  }

  bool _isUnsafeForChildren(TrailSegment trail) {
    final sac = (trail.tags['sac_scale']?.toString() ?? '').toLowerCase();
    final smoothness = (trail.tags['smoothness']?.toString() ?? '').toLowerCase();
    final incline = (trail.tags['incline']?.toString() ?? '').toLowerCase();
    final highway = (trail.tags['highway']?.toString() ?? '').toLowerCase();

    if (sac.contains('mountain') || sac.contains('alpine') || sac.contains('demanding')) return true;
    if (smoothness.contains('very_bad') || smoothness.contains('horrible') || smoothness.contains('impassable')) return true;
    if (incline == 'steep') return true;
    if (highway == 'steps') return true;
    final n = double.tryParse(incline.replaceAll('%', '').replaceAll('+', '').trim());
    if (n != null && n.abs() > 10) return true;
    return false;
  }

  Future<void> _saveCurrentRoute() async {
    if (_route.length < 2) return;

    final title = _previewTitle.trim().isEmpty
        ? 'Percorso pianificato'
        : _previewTitle.trim();

    final now = DateTime.now();
    final route = SavedRoute(
      id: 'route_${now.microsecondsSinceEpoch}',
      title: title,
      savedAt: now,
      points: List<LatLng>.from(_route),
      distanceKm: _routeLengthKm(_route),
    );

    await SavedRoutesService.instance.save(route);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Percorso salvato sul telefono.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startPreviewNavigation() async {
    if (_route.length < 2) return;

    // In PIANIFICA non si avvia mai il GPS reale. L'utente resta sulla
    // localita pianificata e torna alla mappa con le 4 funzioni.
    if (!widget.useGps) {
      setState(() {
        _routePreview = false;
      });
      return;
    }

    final title = _previewTitle;
    setState(() => _routePreview = false);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          route: _route,
          destinationName: title,
          initialPosition: _position,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _route = const [];
      _previewTitle = '';
    });
  }

  Future<void> _changePreviewRoute() async {
    setState(() {
      _routePreview = false;
      _route = const [];
      _previewTitle = '';
    });

    await Future<void>.delayed(const Duration(milliseconds: 80));
    _showAssistant();
  }

  double _trailAiPenalty(_PlannerChoice choice, TrailSegment trail) {
    final kind = choice.kind;
    final sac = (trail.tags['sac_scale']?.toString() ?? '').toLowerCase();
    final surface = (trail.tags['surface']?.toString() ?? '').toLowerCase();
    final highway = (trail.tags['highway']?.toString() ?? '').toLowerCase();
    final smoothness = (trail.tags['smoothness']?.toString() ?? '').toLowerCase();
    final inclineRaw = (trail.tags['incline']?.toString() ?? '').toLowerCase();
    final name = (trail.name ?? '').toLowerCase();

    double? inclinePercent() {
      final cleaned = inclineRaw.replaceAll('%', '').replaceAll('+', '').trim();
      final direct = double.tryParse(cleaned);
      if (direct != null) return direct.abs();
      if (inclineRaw == 'up' || inclineRaw == 'down') return 8;
      if (inclineRaw == 'steep') return 15;
      return null;
    }

    var penalty = 0.0;

    // La distanza scelta definisce anche l'intensità desiderata.
    // Quando OSM fornisce sac_scale/incline/smoothness, GoTr-AI li usa
    // per evitare pendenze e tratti tecnici nelle passeggiate più tranquille.
    final incline = inclinePercent();
    if (choice.distanceKm <= 2.1) {
      if (sac.contains('mountain') || sac.contains('alpine') || sac.contains('demanding')) {
        penalty += 5200;
      }
      if (incline != null && incline > 8) penalty += (incline - 8) * 260;
      if (smoothness.contains('bad') || smoothness.contains('horrible')) penalty += 1800;
      if (surface == 'asphalt' || surface == 'paved' || surface == 'compacted') penalty -= 450;
    } else if (choice.distanceKm <= 4.1) {
      if (sac.contains('alpine') || sac.contains('demanding')) penalty += 3000;
      if (incline != null && incline > 12) penalty += (incline - 12) * 170;
      if (smoothness.contains('very_bad') || smoothness.contains('horrible')) penalty += 1100;
    } else {
      if (sac.contains('demanding_alpine')) penalty += 2200;
      if (incline != null && incline > 18) penalty += (incline - 18) * 120;
    }

    switch (kind) {
      case _WalkKind.children:
        if (sac.contains('mountain') || sac.contains('alpine')) penalty += 5000;
        if (surface == 'asphalt' || surface == 'paved') penalty -= 500;
        if (highway == 'track' || highway == 'path') penalty += 150;
        break;
      case _WalkKind.dog:
        if (sac.contains('alpine') || sac.contains('demanding')) penalty += 4200;
        if (highway == 'path' || highway == 'track') penalty -= 350;
        break;
      case _WalkKind.woods:
        if (name.contains('bosco') || name.contains('forest')) penalty -= 1500;
        if (surface == 'ground' || surface == 'dirt' || surface == 'unpaved') {
          penalty -= 650;
        }
        if (highway == 'path' || highway == 'track') penalty -= 450;
        break;
      case _WalkKind.adventure:
        if (sac == 'mountain_hiking') penalty -= 1300;
        if (sac.contains('demanding')) penalty -= 900;
        if (highway == 'path') penalty -= 400;
        if (surface == 'asphalt' || surface == 'paved') penalty += 1800;
        break;
    }
    return penalty;
  }

  double _routeOverlapRatio(List<LatLng> points) {
    if (points.length < 4) return 1;
    final seen = <String>{};
    var repeated = 0;
    var total = 0;
    for (var i = 0; i < points.length - 1; i += 3) {
      final a = points[i];
      final j = i + 1 < points.length ? i + 1 : points.length - 1;
      final b = points[j];
      String q(LatLng p) =>
          '${(p.latitude * 10000).round()},${(p.longitude * 10000).round()}';
      final qa = q(a);
      final qb = q(b);
      final key = qa.compareTo(qb) < 0 ? '$qa|$qb' : '$qb|$qa';
      total++;
      if (!seen.add(key)) repeated++;
    }
    return total == 0 ? 1 : repeated / total;
  }

  double _routeLengthKm(List<LatLng> points) {
    var meters = 0.0;

    for (var i = 0; i < points.length - 1; i++) {
      meters += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }

    return meters / 1000;
  }

  double _bearingDegrees(LatLng a, LatLng b) {
    final lat1 = a.latitude * 0.017453292519943295;
    final lat2 = b.latitude * 0.017453292519943295;
    final dLon =
        (b.longitude - a.longitude) * 0.017453292519943295;

    final y = _sinApprox(dLon) * _cosApprox(lat2);
    final x = _cosApprox(lat1) * _sinApprox(lat2) -
        _sinApprox(lat1) *
            _cosApprox(lat2) *
            _cosApprox(dLon);

    var bearing = _atan2Approx(y, x) * 57.29577951308232;
    if (bearing < 0) bearing += 360;
    return bearing;
  }

  double _sinApprox(double x) {
    while (x > 3.141592653589793) {
      x -= 6.283185307179586;
    }
    while (x < -3.141592653589793) {
      x += 6.283185307179586;
    }

    final x2 = x * x;
    return x *
        (1 -
            x2 / 6 +
            x2 * x2 / 120 -
            x2 * x2 * x2 / 5040);
  }

  double _cosApprox(double x) {
    return _sinApprox(x + 1.5707963267948966);
  }

  double _atan2Approx(double y, double x) {
    // Sufficient for route-sector selection.
    if (x == 0) {
      if (y > 0) return 1.5707963267948966;
      if (y < 0) return -1.5707963267948966;
      return 0;
    }

    final absY = y.abs() + 1e-10;
    double angle;

    if (x >= 0) {
      final r = (x - absY) / (x + absY);
      angle = 0.7853981633974483 -
          0.7853981633974483 * r;
    } else {
      final r = (x + absY) / (absY - x);
      angle = 2.356194490192345 +
          0.7853981633974483 * r;
    }

    return y < 0 ? -angle : angle;
  }

  void _plannerMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4F9448)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoButton({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4F9448)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmExitApp() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uscire da GoTr-AI?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Vuoi chiudere l’app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('NO'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ESCI'),
          ),
        ],
      ),
    );
    if (exit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final area = _nearbyArea;
    final center = _insidePackage ? _position : widget.package.center;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_routePreview) {
          setState(() {
            _routePreview = false;
            _route = const [];
            _previewTitle = '';
          });
        } else {
          // Sia da INIZIA sia da PIANIFICA, indietro torna alla schermata
          // precedente. Solo la Home gestisce l'eventuale uscita dall'app.
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _insidePackage ? 15.5 : 11.8,
                backgroundColor: const Color(0xFFF1EFE7),
              ),
              children: [
                // Sfondo più semplice e leggero della precedente OpenTopoMap.
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gotrai.app',
                  maxZoom: 19,
                  errorTileCallback: (_, __, ___) {},
                ),
                if (area != null)
                  PolylineLayer(
                    polylines: [
                      for (final trail in area.trails)
                        Polyline(
                          points: trail.points,
                          strokeWidth: 2.6,
                          color: trail.color,
                        ),
                      if (_route.isNotEmpty)
                        Polyline(
                          points: _route,
                          strokeWidth: 6,
                          color: const Color(0xFF1565C0),
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                        ),
                    ],
                  ),
                if (area != null)
                  MarkerLayer(
                    markers: [
                      for (final poi in area.pois)
                        if (poi.type != PoiType.parcheggio)
                          Marker(
                            point: poi.point,
                            width: poi.type == PoiType.rifugio ? 34 : 25,
                            height: poi.type == PoiType.rifugio ? 34 : 25,
                            child: _poiIcon(poi),
                          ),
                      if (widget.useGps && _insidePackage)
                        Marker(
                          point: _position,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0x334285F4),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          if (!_routePreview)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cornerInfoButton(
                          icon: Icons.hiking_rounded,
                          title: 'Sentieri',
                          value: area == null ? '…' : '${_trailCountWithin(_trailRadiusKm)}',
                          color: const Color(0xFF4F9448),
                          onTap: area == null ? null : _showAssistant,
                        ),
                        const Spacer(),
                        _cornerInfoButton(
                          icon: Icons.local_parking_rounded,
                          title: 'Parcheggi',
                          value: area == null ? '…' : '${_poiCountWithin(PoiType.parcheggio)}',
                          color: const Color(0xFF1976D2),
                          onTap: area == null ? null : _openNearestParking,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _cornerInfoButton(
                          icon: Icons.water_drop_rounded,
                          title: 'Fontane',
                          value: area == null ? '…' : '${_poiCountWithin(PoiType.fontana)}',
                          color: const Color(0xFF1976D2),
                          onTap: area == null ? null : _openNearestFountain,
                        ),
                        const Spacer(),
                        _cornerInfoButton(
                          icon: Icons.cottage_rounded,
                          title: 'Rifugi',
                          value: area == null ? '…' : '${_poiCountWithin(PoiType.rifugio)}',
                          color: const Color(0xFFD84315),
                          onTap: area == null ? null : _openRefuges,
                        ),
                      ],
                    ),
                    if (widget.useGps) ...[
                      const SizedBox(height: 8),
                      _roundButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Centra GPS',
                        onTap: _centerGps,
                        size: 52,
                      ),
                    ] else
                      const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

          if (_routePreview)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white,
                          elevation: 4,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                            ),
                            onPressed: _changePreviewRoute,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _previewTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xEEFFFFFF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE7F2E5),
                                foregroundColor: const Color(0xFF2F6F35),
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: _changePreviewRoute,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text(
                                'CAMBIA',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF0F5FB),
                                foregroundColor: const Color(0xFF18539A),
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: const BorderSide(color: Color(0xFF18539A)),
                                ),
                              ),
                              onPressed: _saveCurrentRoute,
                              icon: const Icon(Icons.bookmark_add_rounded, size: 19),
                              label: const Text(
                                'SALVA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: widget.useGps
                                    ? const Color(0xFF3E8B44)
                                    : const Color(0xFF18539A),
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: _startPreviewNavigation,
                              icon: Icon(
                                widget.useGps
                                    ? Icons.navigation_rounded
                                    : Icons.check_rounded,
                                size: 19,
                              ),
                              label: Text(
                                widget.useGps ? 'AVVIA' : 'FINE',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
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
            ),

          if (_loading || _routing)
            Positioned.fill(
              child: ColoredBox(
                color: Color(0x44FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          if (_error != null)
            Positioned.fill(
              child: ColoredBox(
                color: Color(0x99FFFFFF),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _cornerInfoButton({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: color,
      elevation: 5,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 92,
          height: 104,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                SizedBox(
                  height: 28,
                  width: 78,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 50,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: .96),
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: const Color(0xFF2F6F35),
              size: size * .48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _poiIcon(MapPoi poi) {
    final color = switch (poi.type) {
      PoiType.rifugio => const Color(0xFFD84315),
      PoiType.panorama => const Color(0xFF7B1FA2),
      PoiType.fontana => const Color(0xFF1976D2),
      PoiType.parcheggio => const Color(0xFF546E7A),
    };

    final icon = switch (poi.type) {
      PoiType.rifugio => Icons.cottage_rounded,
      PoiType.panorama => Icons.visibility_rounded,
      PoiType.fontana => Icons.water_drop_rounded,
      PoiType.parcheggio => Icons.local_parking_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: poi.type == PoiType.rifugio ? 18 : 13,
      ),
    );
  }
}
