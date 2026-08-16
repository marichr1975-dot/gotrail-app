import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/saved_route.dart';
import '../services/gps_service.dart';
import '../services/saved_routes_service.dart';
import 'navigation_screen.dart';

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  late Future<List<SavedRoute>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = SavedRoutesService.instance.loadAll();
  }

  Future<void> _delete(SavedRoute route) async {
    final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminare il percorso?'),
            content: Text(route.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ANNULLA'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ELIMINA'),
              ),
            ],
          ),
        ) ??
        false;

    if (!yes) return;
    await SavedRoutesService.instance.delete(route.id);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _open(SavedRoute route) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SavedRouteDetailScreen(route: route)),
    );
    if (!mounted) return;
    setState(_reload);
  }

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Percorsi salvati', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: FutureBuilder<List<SavedRoute>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data ?? const <SavedRoute>[];
          if (routes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 68, color: Color(0xFF18539A)),
                    SizedBox(height: 14),
                    Text(
                      'Nessun percorso salvato',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pianifica un percorso e premi SALVA per ritrovarlo qui.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: routes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final route = routes[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE4EEF9),
                    child: Icon(Icons.route_rounded, color: Color(0xFF18539A)),
                  ),
                  title: Text(route.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${route.distanceKm.toStringAsFixed(1)} km • ${_dateLabel(route.savedAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(route),
                  ),
                  onTap: () => _open(route),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SavedRouteDetailScreen extends StatefulWidget {
  final SavedRoute route;

  const SavedRouteDetailScreen({super.key, required this.route});

  @override
  State<SavedRouteDetailScreen> createState() => _SavedRouteDetailScreenState();
}

class _SavedRouteDetailScreenState extends State<SavedRouteDetailScreen> {
  final MapController _controller = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRoute();
    });
  }

  void _fitRoute() {
    if (widget.route.points.length < 2) return;
    var minLat = widget.route.points.first.latitude;
    var maxLat = minLat;
    var minLon = widget.route.points.first.longitude;
    var maxLon = minLon;
    for (final p in widget.route.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)),
        padding: const EdgeInsets.fromLTRB(28, 100, 28, 130),
      ),
    );
  }

  Future<void> _startNavigation() async {
    try {
      final gps = await GpsService.currentPosition();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NavigationScreen(
            route: widget.route.points,
            destinationName: widget.route.title,
            initialPosition: LatLng(gps.latitude, gps.longitude),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.route.points[widget.route.points.length ~/ 2];
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gotrai.app',
                maxZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.route.points,
                    strokeWidth: 6,
                    color: const Color(0xFF1565C0),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.route.points.first,
                    width: 34,
                    height: 34,
                    child: const Icon(Icons.trip_origin_rounded, color: Color(0xFF278234), size: 30),
                  ),
                  Marker(
                    point: widget.route.points.last,
                    width: 34,
                    height: 34,
                    child: const Icon(Icons.flag_rounded, color: Color(0xFFD84315), size: 30),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Text(widget.route.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF278234),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                onPressed: _startNavigation,
                icon: const Icon(Icons.navigation_rounded),
                label: Text(
                  'AVVIA NAVIGAZIONE • ${widget.route.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
