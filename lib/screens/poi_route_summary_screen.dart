import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/elevation_service.dart';
import '../services/hiking_router.dart';
import '../services/nearby_poi_service.dart';
import 'navigation_screen.dart';

class PoiRouteSummaryScreen extends StatefulWidget {
  final NearbyPoi destination;

  const PoiRouteSummaryScreen({
    super.key,
    required this.destination,
  });

  @override
  State<PoiRouteSummaryScreen> createState() => _PoiRouteSummaryScreenState();
}

class _PoiRouteSummaryScreenState extends State<PoiRouteSummaryScreen> {
  static const _blue = Color(0xFF0B5FD7);
  static const _green = Color(0xFF20A85A);

  final MapController _mapController = MapController();

  NearbyPoi? _parking;
  List<LatLng> _route = const [];
  ElevationProfile? _elevation;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final parking = await NearbyPoiService.instance.nearestParking(
        widget.destination.point,
        maxRadiusKm: 15,
      );

      if (parking == null) {
        throw Exception(
          'Non trovo un parcheggio pubblico utilizzabile vicino alla meta.',
        );
      }

      final route = await HikingRouter.instance.route(
        start: parking.point,
        destination: widget.destination.point,
      );

      if (!route.available || route.points.length < 2) {
        throw Exception(route.message);
      }

      final elevation = await ElevationService.instance.profile(route.points);

      if (!mounted) return;

      setState(() {
        _parking = parking;
        _route = route.points;
        _elevation = elevation;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _route.length < 2) return;
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(_route),
              padding: const EdgeInsets.all(32),
            ),
          );
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double get _routeKm {
    if (_route.length < 2) return 0;
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

  String get _estimatedTime {
    // Stima semplice da trekking:
    // circa 4 km/h su piano + 1 h ogni 600 m di salita.
    final ascent = _elevation?.ascent ?? 0.0;
    final hours = (_routeKm / 4.0) + (ascent / 600.0);
    final totalMinutes = (hours * 60).round().clamp(1, 24 * 60);
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h ${m.toString().padLeft(2, '0')}';
  }

  Future<void> _startNavigation() async {
    final parking = _parking;
    if (parking == null || _route.length < 2) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          route: _route,
          destinationName: widget.destination.name,
          initialPosition: parking.point,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parking = _parking;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1153D8),
        foregroundColor: Colors.white,
        title: const Text(
          'Percorso pronto',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text(
                    'Preparo percorso e altimetria…',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 52,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _prepare();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('RIPROVA'),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 650;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: compact ? 205 : 232,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: widget.destination.point,
                                  initialZoom: 13,
                                  minZoom: 6,
                                  maxZoom: 19,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.gotrai.app',
                                    maxZoom: 19,
                                    errorTileCallback: (_, __, ___) {},
                                  ),
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.gotrai.app',
                                  ),
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: _route,
                                        strokeWidth: 7,
                                        color: const Color(0xFF1557E5),
                                        borderStrokeWidth: 2,
                                        borderColor: Colors.white,
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      if (parking != null)
                                        Marker(
                                          point: parking.point,
                                          width: 44,
                                          height: 44,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1557E5),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'P',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Marker(
                                        point: widget.destination.point,
                                        width: 46,
                                        height: 46,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                          child: Icon(
                                            widget.destination.category ==
                                                    NearbyPoiCategory.hut
                                                ? Icons.cabin_rounded
                                                : Icons.water_drop_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.destination.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 19 : 21,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricBox(
                                  icon: Icons.route_rounded,
                                  label: 'Distanza',
                                  value: '${_routeKm.toStringAsFixed(1)} km',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  icon: Icons.schedule_rounded,
                                  label: 'Tempo stimato',
                                  value: _estimatedTime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: compact ? 104 : 116,
                            child: _elevation == null
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE0E6ED),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Altimetria non disponibile',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  )
                                : _ElevationCard(
                                    profile: _elevation!,
                                    distanceKm: _routeKm,
                                  ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 47,
                            child: FilledButton.icon(
                              onPressed: _startNavigation,
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.navigation_rounded),
                              label: const Text(
                                'INIZIA',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0E6ED)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0B5FD7), size: 23),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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

class _ElevationCard extends StatelessWidget {
  final ElevationProfile profile;
  final double distanceKm;

  const _ElevationCard({
    required this.profile,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6ED)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.terrain_rounded,
                color: Color(0xFF0B5FD7),
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Altimetria',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '+${profile.ascent.round()} m',
                style: const TextStyle(
                  color: Color(0xFF20A85A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '-${profile.descent.round()} m',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: CustomPaint(
              painter: _ElevationPainter(profile.elevations),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                '${profile.minElevation.round()} m',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${(distanceKm / 2).toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${profile.maxElevation.round()} m · ${distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final List<double> values;

  _ElevationPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1 ? 1.0 : maxV - minV;

    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Paint()
      ..color = const Color(0xFF1684F8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fill = Paint()
      ..color = const Color(0x221684F8)
      ..style = PaintingStyle.fill;

    final path = ui.Path();

    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minV) / span;
      final y = size.height - (normalized * (size.height - 6)) - 3;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final area = ui.Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
