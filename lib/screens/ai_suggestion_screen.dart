import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/saved_route.dart';
import '../services/gemini_ai_service.dart';
import '../services/hiking_router.dart';
import '../services/saved_routes_service.dart';

class AiSuggestionScreen extends StatefulWidget {
  final AiTrailSuggestion suggestion;
  const AiSuggestionScreen({super.key, required this.suggestion});

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  static const _blue = Color(0xFF0B5FD7);
  static const _green = Color(0xFF20A85A);
  static const _ink = Color(0xFF112234);

  final MapController _mapController = MapController();
  List<LatLng> _route = const [];
  String? _routeError;
  bool _loadingRoute = true;
  bool _saving = false;
  bool _saved = false;

  AiTrailSuggestion get s => widget.suggestion;

  @override
  void initState() {
    super.initState();
    _buildRealRoute();
  }

  double _wantedKm() {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(s.distance);
    if (match == null) return 4;
    return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 4;
  }

  double _routeKm() {
    if (_route.length < 2) return _wantedKm();
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < _route.length; i++) {
      meters += distance.as(
        LengthUnit.Meter,
        _route[i - 1],
        _route[i],
      );
    }
    return meters / 1000.0;
  }

  Future<void> _saveRoute() async {
    if (_route.length < 2 || _saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final route = SavedRoute(
        id: 'ai_${now.microsecondsSinceEpoch}',
        title: s.title.trim().isEmpty ? 'Percorso GoTr-AI' : s.title.trim(),
        savedAt: now,
        points: List<LatLng>.from(_route),
        distanceKm: _routeKm(),
      );
      await SavedRoutesService.instance.save(route);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Percorso salvato in Salvati.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Non riesco a salvare il percorso: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _pointsKm(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(
        LengthUnit.Meter,
        points[i - 1],
        points[i],
      );
    }
    return meters / 1000.0;
  }

  bool _isAcceptableLoop(
    List<LatLng> points,
    LatLng start,
    double wantedKm,
  ) {
    if (points.length < 8) return false;

    const distance = Distance();
    final closureM = distance.as(
      LengthUnit.Meter,
      points.first,
      points.last,
    );
    if (closureM > 80) return false;

    final km = _pointsKm(points);
    if (km < wantedKm * 0.65 || km > wantedKm * 1.55) {
      return false;
    }

    // Rifiuta percorsi che tornano ripetutamente sugli stessi tratti:
    // quantizziamo a circa 35-45 m e contiamo i ritorni non consecutivi.
    final seen = <String, int>{};
    var repeated = 0;
    for (var i = 0; i < points.length; i += 3) {
      final p = points[i];
      final key =
          '${(p.latitude * 2500).round()}:${(p.longitude * 2500).round()}';
      final previous = seen[key];
      if (previous != null && i - previous > 8) {
        repeated++;
      } else {
        seen[key] = i;
      }
    }

    final sampled = (points.length / 3).ceil();
    if (sampled > 0 && repeated / sampled > 0.18) {
      return false;
    }

    return true;
  }

  LatLng _offsetKm(
    LatLng center,
    double northKm,
    double eastKm,
  ) {
    final dLat = northKm / 111.0;
    final cosLat =
        math.cos(center.latitude * math.pi / 180.0).abs().clamp(0.2, 1.0);
    final dLon = eastKm / (111.0 * cosLat);
    return LatLng(
      center.latitude + dLat,
      center.longitude + dLon,
    );
  }

  Future<void> _buildRealRoute() async {
    final lat = s.latitude;
    final lon = s.longitude;
    if (lat == null || lon == null) {
      setState(() {
        _routeError = 'Coordinate della località non disponibili.';
        _loadingRoute = false;
      });
      return;
    }

    final start = LatLng(lat, lon);
    final wantedKm = _wantedKm().clamp(2.0, 10.0);

    // Il vecchio algoritmo metteva START al centro e creava una "stella".
    // Qui START è un punto della circonferenza del giro.
    final radiusKm =
        math.max(0.30, wantedKm / (2 * math.pi));

    final attempts = <List<LatLng>>[];

    // Quattro orientamenti diversi: se BRouter forza una strada già usata
    // proviamo un anello ruotato.
    for (final rotation in [0.0, 45.0, 90.0, 135.0]) {
      final r = rotation * math.pi / 180.0;

      // centro spostato rispetto allo start: start resta sulla circonferenza
      final center = _offsetKm(
        start,
        radiusKm * math.cos(r),
        radiusKm * math.sin(r),
      );

      LatLng ringPoint(double deg) {
        final ang = (deg + rotation) * math.pi / 180.0;
        return _offsetKm(
          center,
          radiusKm * math.cos(ang),
          radiusKm * math.sin(ang),
        );
      }

      attempts.add([
        start,
        ringPoint(45),
        ringPoint(135),
        ringPoint(225),
        ringPoint(315),
        start,
      ]);
    }

    HikingRouteResult? best;
    double bestScore = double.infinity;

    for (final waypoints in attempts) {
      final result =
          await HikingRouter.instance.routeThrough(waypoints);
      if (!result.available) continue;
      if (!_isAcceptableLoop(
        result.points,
        start,
        wantedKm,
      )) {
        continue;
      }

      final km = _pointsKm(result.points);
      final score = (km - wantedKm).abs();
      if (score < bestScore) {
        best = result;
        bestScore = score;
      }
    }

    if (!mounted) return;

    if (best == null) {
      setState(() {
        _route = const [];
        _routeError =
            'Non trovo un vero percorso ad anello di circa '
            '${wantedKm.toStringAsFixed(0)} km in questa zona. '
            'Prova a cambiare distanza o difficoltà.';
        _loadingRoute = false;
      });
      return;
    }

    setState(() {
      _route = best!.points;
      _routeError = null;
      _loadingRoute = false;
    });

    if (_route.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(_route),
              padding: const EdgeInsets.all(22),
            ),
          );
        } catch (_) {}
      });
    }
  }

  void _openFullScreenMap() {
    if (_route.isEmpty) return;
    final center = LatLng(s.latitude ?? 45.75, s.longitude ?? 11.85);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'Mappa percorso',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: _blue,
            foregroundColor: Colors.white,
          ),
          body: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.8,
              minZoom: 7,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gotr_ai',
              ),
              TileLayer(
                urlTemplate: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gotr_ai',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route,
                    strokeWidth: 6,
                    color: _blue,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(s.latitude ?? 45.75, s.longitude ?? 11.85);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        toolbarHeight: 54,
        title: const Text(
          'Percorso proposto',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapHeight = (constraints.maxHeight * .29).clamp(178.0, 225.0);
            return Column(
              children: [
                SizedBox(
                  height: mapHeight,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14.8,
                          minZoom: 7,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.gotr_ai',
                          ),
                          if (_route.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _route,
                                  strokeWidth: 6,
                                  color: _blue,
                                  borderStrokeWidth: 2,
                                  borderColor: Colors.white,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: center,
                                width: 46,
                                height: 46,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _green,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 27,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          elevation: 2,
                          child: IconButton(
                            onPressed:
                                _route.isEmpty ? null : _openFullScreenMap,
                            icon: const Icon(Icons.fullscreen_rounded),
                            color: _blue,
                            tooltip: 'Apri mappa a schermo intero',
                          ),
                        ),
                      ),
                      if (_loadingRoute)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x55000000),
                            child: Center(
                              child:
                                  CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                      if (!_loadingRoute && _routeError != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _routeError!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 20,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _CompactInfo(
                                icon: Icons.route_rounded,
                                text: s.routeType,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CompactInfo(
                                icon: Icons.straighten_rounded,
                                text: s.distance,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CompactInfo(
                                icon: Icons.trending_up_rounded,
                                text: s.difficulty,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              s.summary.trim().isEmpty
                                  ? 'Percorso pronto.'
                                  : s.summary,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF526574),
                                fontSize: 13.2,
                                height: 1.28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _route.length >= 2 ? _saveRoute : null,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _saved
                                            ? Icons.bookmark_added_rounded
                                            : Icons.bookmark_add_outlined,
                                      ),
                                label: Text(
                                  _saved ? 'SALVATO' : 'SALVA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  foregroundColor: _blue,
                                  side:
                                      const BorderSide(color: _blue, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _route.length >= 2 ? () {} : null,
                                icon: const Icon(Icons.navigation_rounded),
                                label: const Text(
                                  'INIZIA PERCORSO',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: _green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8EE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0B5FD7), size: 18),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF112234),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

