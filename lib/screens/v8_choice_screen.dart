import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/gps_service.dart';
import '../services/hiking_router.dart';
import '../services/nearby_poi_service.dart';
import 'fountain_map_screen.dart';
import 'home_screen.dart';
import 'navigation_screen.dart';
import 'nearby_poi_list_screen.dart';
import 'v8_preferences_screen.dart';

enum V8Mode { start, plan }

class V8ChoiceScreen extends StatefulWidget {
  final V8Mode mode;
  final String? initialPlace;
  final LatLng? targetPoint;
  final String? targetLabel;

  const V8ChoiceScreen({
    super.key,
    required this.mode,
    this.initialPlace,
    this.targetPoint,
    this.targetLabel,
  });

  @override
  State<V8ChoiceScreen> createState() => _V8ChoiceScreenState();
}

class _V8ChoiceScreenState extends State<V8ChoiceScreen> {
  static const _blue = Color(0xFF0B5FD7);
  static const _green = Color(0xFF20A85A);
  static const _ink = Color(0xFF112234);

  bool _scanning = true;
  LatLng? _center;
  NearbyPoiSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _scanArea();
  }

  Future<void> _scanArea() async {
    try {
      LatLng center;
      if (widget.targetPoint != null) {
        center = widget.targetPoint!;
      } else {
        center = await GpsService.currentPosition();
      }

      final snapshot = await NearbyPoiService.instance.scan(center, radiusKm: 10);
      if (!mounted) return;
      setState(() {
        _center = center;
        _snapshot = snapshot;
        _scanning = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
    }
  }

  void _home() => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

  void _openWalk() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V8PreferencesScreen(
          mode: widget.mode,
          activity: 'Passeggiata',
          place: widget.mode == V8Mode.plan ? widget.initialPlace : null,
          targetPoint: widget.targetPoint,
          targetLabel: widget.targetLabel,
        ),
      ),
    );
  }

  void _openPoi(NearbyPoiCategory category, String activity) {
    final center = _center;
    if (center == null || _scanning) return;
    final items = _snapshot?.forCategory(category) ?? const <NearbyPoi>[];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyPoiListScreen(
          mode: widget.mode,
          activity: activity,
          place: widget.initialPlace,
          center: center,
          items: items,
        ),
      ),
    );
  }

  Future<void> _openFountains() async {
    final center = _center;
    if (center == null || _scanning) return;

    final items = _snapshot?.forCategory(
          NearbyPoiCategory.drinkingWater,
        ) ??
        const <NearbyPoi>[];

    if (items.isEmpty) return;

    // PIANIFICA: mai avviare la navigazione.
    // Mostra soltanto la zona cercata con tutte le fontane.
    if (widget.mode == V8Mode.plan) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FountainMapScreen(
            place: widget.initialPlace,
            center: center,
            fountains: items,
          ),
        ),
      );
      return;
    }

    // INIZIA: il GPS reale deve essere DAVVERO nella zona che stiamo guardando.
    // Se l'utente ha cercato una località lontana (es. Auronzo mentre è a Mira),
    // niente "PORTAMI": apriamo solo la mappa della zona.
    LatLng realGps;
    try {
      realGps = await GpsService.currentPosition();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non riesco a leggere la posizione GPS reale.'),
        ),
      );
      return;
    }

    final distanceFromAreaKm = Geolocator.distanceBetween(
          realGps.latitude,
          realGps.longitude,
          center.latitude,
          center.longitude,
        ) /
        1000.0;

    if (distanceFromAreaKm > 10.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sei a ${distanceFromAreaKm.toStringAsFixed(0)} km da questa zona: '
            'ti mostro le fontane, ma non avvio la navigazione.',
          ),
        ),
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FountainMapScreen(
            place: widget.targetLabel ?? widget.initialPlace,
            center: center,
            fountains: items,
          ),
        ),
      );
      return;
    }

    // Siamo realmente nella zona: scegli la fontana più vicina AL GPS REALE.
    final sorted = List<NearbyPoi>.from(items)
      ..sort((a, b) {
        final da = Geolocator.distanceBetween(
          realGps.latitude,
          realGps.longitude,
          a.point.latitude,
          a.point.longitude,
        );
        final db = Geolocator.distanceBetween(
          realGps.latitude,
          realGps.longitude,
          b.point.latitude,
          b.point.longitude,
        );
        return da.compareTo(db);
      });

    final nearest = sorted.first;
    final nearestKm = Geolocator.distanceBetween(
          realGps.latitude,
          realGps.longitude,
          nearest.point.latitude,
          nearest.point.longitude,
        ) /
        1000.0;

    if (!mounted) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Fontana più vicina',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '${nearest.name}\n'
          'Distanza dal tuo GPS: ${nearestKm.toStringAsFixed(1)} km\n\n'
          'Vuoi che GoTr-Ail ti porti lì?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('PORTAMI'),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await HikingRouter.instance.route(
      start: realGps,
      destination: nearest.point,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!result.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          route: result.points,
          destinationName: nearest.name,
          initialPosition: realGps,
        ),
      ),
    );
  }

  int? _count(NearbyPoiCategory category) {
    final snap = _snapshot;
    if (snap == null || !snap.sourceAvailable) return null;
    return snap.count(category);
  }

  @override
  Widget build(BuildContext context) {
    final planning = widget.mode == V8Mode.plan;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 660;
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(12, compact ? 8 : 12, 16, compact ? 11 : 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF073A79), Color(0xFF0B5FD7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(26),
                      bottomRight: Radius.circular(26),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .16),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Indietro',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planning ? 'PIANIFICA' : 'INIZIA',
                              style: const TextStyle(
                                color: Color(0xFF9DD2FF),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            Text(
                              'Cosa vuoi fare?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 23 : 26,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _scanning
                                  ? 'Analizzo ciò che esiste entro 10 km…'
                                  : 'Risultati reali entro 10 km',
                              style: const TextStyle(
                                color: Color(0xFFEAF4FF),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (planning && (widget.initialPlace ?? '').isNotEmpty)
                              Text(
                                widget.initialPlace!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFEAF4FF),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _home,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .16),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.home_rounded),
                        tooltip: 'Home',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, compact ? 12 : 16, 14, 12),
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.directions_walk_rounded,
                          title: 'Passeggiata',
                          subtitle: null,
                          color: _green,
                          onTap: _openWalk,
                        ),
                        SizedBox(height: compact ? 9 : 12),
                        _ActionTile(
                          icon: Icons.cabin_rounded,
                          title: 'Rifugi',
                          subtitle: null,
                          color: const Color(0xFFE8812B),
                          count: _scanning ? null : _count(NearbyPoiCategory.hut),
                          loading: _scanning,
                          onTap: () => _openPoi(NearbyPoiCategory.hut, 'Rifugio'),
                        ),
                        SizedBox(height: compact ? 9 : 12),
                        _ActionTile(
                          icon: Icons.water_drop_rounded,
                          title: 'Cascate',
                          subtitle: null,
                          color: const Color(0xFF1499D6),
                          count: _scanning ? null : _count(NearbyPoiCategory.waterfall),
                          loading: _scanning,
                          onTap: () => _openPoi(NearbyPoiCategory.waterfall, 'Cascata'),
                        ),
                        SizedBox(height: compact ? 9 : 12),
                        _ActionTile(
                          icon: Icons.local_drink_rounded,
                          title: 'Fontane',
                          subtitle: null,
                          color: _blue,
                          count: _scanning ? null : _count(NearbyPoiCategory.drinkingWater),
                          loading: _scanning,
                          onTap: _openFountains,
                        ),
                        const Spacer(),
                        if (!_scanning &&
                            _snapshot != null &&
                            !_snapshot!.sourceAvailable)
                          Text(
                            'Ricerca non riuscita: ${_snapshot!.sourceMessage}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (!_scanning && _snapshot != null && !_snapshot!.sourceAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.icon(
                              onPressed: () {
                                setState(() => _scanning = true);
                                _scanArea();
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('RIPROVA RICERCA'),
                            ),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final int? count;
  final bool loading;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    this.count,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      elevation: 1.5,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF112234),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (subtitle != null && subtitle!.isNotEmpty)

                      Text(

                        subtitle!,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(color: Colors.black54, fontSize: 11.2),

                      ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else if (count != null)
                Container(
                  constraints: const BoxConstraints(minWidth: 38),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA8B3)),
            ],
          ),
        ),
      ),
    );
  }
}
