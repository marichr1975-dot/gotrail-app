import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:camera/camera.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/gps_service.dart';

class NavigationScreen extends StatefulWidget {
  final List<LatLng> route;
  final String destinationName;
  final LatLng initialPosition;

  const NavigationScreen({
    super.key,
    required this.route,
    required this.destinationName,
    required this.initialPosition,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _controller = MapController();
  late LatLng _position;
  StreamSubscription? _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;

  bool _followGps = true;
  double _heading = 0;
  bool _hasCompass = false;
  bool _offTrack = false;
  bool _offTrackFlash = true;
  Timer? _flashTimer;

  static const double _navigationZoom = 16.7;
  static const double _offTrackEnterMeters = 25.0;
  static const double _offTrackExitMeters = 15.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;

    _gpsSub = GpsService.stream().listen((p) {
      if (!mounted) return;

      final gpsHeading = p.heading;
      final nextPosition = LatLng(p.latitude, p.longitude);
      final distanceFromRoute = _distanceFromRoute(nextPosition);
      final nextOffTrack = _offTrack
          ? distanceFromRoute > _offTrackExitMeters
          : distanceFromRoute > _offTrackEnterMeters;

      setState(() {
        _position = nextPosition;
        _offTrack = nextOffTrack;
        // Se il telefono non dispone di bussola, durante il movimento
        // usiamo comunque la direzione fornita dal GPS.
        if (!_hasCompass && gpsHeading.isFinite && gpsHeading >= 0) {
          _heading = _smoothHeading(_heading, gpsHeading, 0.16);
        }
      });

      if (_followGps) {
        _controller.move(_position, _navigationZoom);
      }
    });

    _flashTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (mounted && _offTrack) {
        setState(() => _offTrackFlash = !_offTrackFlash);
      }
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (!mounted || h == null || !h.isFinite) return;
      setState(() {
        _hasCompass = true;
        _heading = _smoothHeading(_heading, h, 0.35);
      });
    });
  }


  double _distanceFromRoute(LatLng point) {
    if (widget.route.isEmpty) return 0;
    if (widget.route.length == 1) {
      final p = widget.route.first;
      return Geolocator.distanceBetween(
        point.latitude, point.longitude, p.latitude, p.longitude);
    }

    final lat0 = point.latitude * math.pi / 180;
    const earth = 6371000.0;
    double best = double.infinity;

    for (var i = 0; i < widget.route.length - 1; i++) {
      final a = widget.route[i];
      final b = widget.route[i + 1];
      final ax = (a.longitude - point.longitude) * math.pi / 180 * earth * math.cos(lat0);
      final ay = (a.latitude - point.latitude) * math.pi / 180 * earth;
      final bx = (b.longitude - point.longitude) * math.pi / 180 * earth * math.cos(lat0);
      final by = (b.latitude - point.latitude) * math.pi / 180 * earth;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
      final x = ax + t * dx;
      final y = ay + t * dy;
      final d = math.sqrt(x * x + y * y);
      if (d < best) best = d;
    }
    return best;
  }

  double _smoothHeading(double current, double next, double factor) {
    // Interpolazione sul cerchio: evita il salto 359° -> 0° e riduce
    // il tremolio tipico della bussola di telefoni meno recenti.
    final delta = ((next - current + 540) % 360) - 180;
    return (current + delta * factor + 360) % 360;
  }

  double get _remainingMeters {
    if (widget.route.isEmpty) return 0;

    var bestIndex = 0;
    var bestDistance = double.infinity;

    for (var i = 0; i < widget.route.length; i += 6) {
      final p = widget.route[i];
      final d = Geolocator.distanceBetween(
        _position.latitude,
        _position.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }

    var total = 0.0;
    for (var i = bestIndex; i < widget.route.length - 1; i++) {
      final a = widget.route[i];
      final b = widget.route[i + 1];
      total += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
    }

    return total;
  }

  String get _remainingLabel {
    final meters = _remainingMeters;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  Widget _buildNavigationMap() {
    // La bussola restituisce l'orientamento del telefono rispetto al Nord.
    // In modalita FOLLOW ruotiamo la MAPPA in senso opposto: la direzione
    // verso cui stai puntando il telefono resta sempre in alto, come in un
    // navigatore. La freccia quindi NON va ruotata una seconda volta.
    // Se l'utente sposta la mappa e disattiva FOLLOW, torniamo Nord-up e in
    // quel caso ruotiamo soltanto la freccia secondo la bussola.
    final headingRad = _heading * math.pi / 180;
    final mapRotation = _followGps ? -headingRad : 0.0;
    final arrowRotation = headingRad;

    final map = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _position,
        initialZoom: _navigationZoom,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _followGps) {
            setState(() => _followGps = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gotrai.app',
          maxZoom: 19,
          errorTileCallback: (_, __, ___) {},
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: widget.route,
              strokeWidth: 8,
              color: const Color(0xFF0D6EFD),
              borderStrokeWidth: 3,
              borderColor: Colors.white,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _position,
              width: 66,
              height: 66,
              child: Transform.rotate(
                angle: arrowRotation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0x334285F4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.route.isNotEmpty)
              Marker(
                point: widget.route.last,
                width: 44,
                height: 44,
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF2F7A37),
                  child: Icon(Icons.flag_rounded, color: Colors.white),
                ),
              ),
          ],
        ),
      ],
    );

    // 5.2: navigazione volutamente 2D. Nessuna deformazione prospettica:
    // mantiene la mappa fluida e leggibile anche sui telefoni meno recenti.
    return Transform.rotate(
      angle: mapRotation,
      child: map,
    );
  }

  Future<void> _showHelpMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AIUTO',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F8A3B),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openArView();
                  },
                  icon: const Icon(Icons.view_in_ar_rounded),
                  label: const Text(
                    'ATTIVA VISTA AR',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F8A3B),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _confirmReturnToStart();
                  },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text(
                    'ANNULLA PERCORSO E RIPORTAMI ALLA PARTENZA',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openArView() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotocamera non disponibile su questo telefono.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ExperimentalArView(
            camera: cameras.first,
            route: widget.route,
            initialPosition: _position,
            destinationName: widget.destinationName,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vista AR non disponibile. Verifica il permesso fotocamera.'),
        ),
      );
    }
  }

  Future<void> _confirmReturnToStart() async {
    if (widget.route.isEmpty) return;
    final yes = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(
              'Tornare alla partenza?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: const Text(
              'Il percorso attuale verrà annullato e GoTr-AI ti guiderà verso il punto di partenza del sentiero.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ANNULLA'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('SÌ, RIPORTAMI'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes || !mounted) return;

    // Prima versione semplice e robusta: usa al contrario la traccia già
    // percorsa/creata fino al suo punto iniziale. Non richiede rete.
    final routeBack = <LatLng>[_position];
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < widget.route.length; i++) {
      final p = widget.route[i];
      final d = Geolocator.distanceBetween(
        _position.latitude, _position.longitude, p.latitude, p.longitude);
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    for (var i = nearest; i >= 0; i--) {
      routeBack.add(widget.route[i]);
    }

    if (routeBack.length < 2) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          route: routeBack,
          destinationName: 'Partenza',
          initialPosition: _position,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildNavigationMap()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.destinationName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.explore_rounded,
                                color: Color(0xFF1565C0),
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Material(
                        color: const Color(0xFFD32F2F),
                        elevation: 5,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _showHelpMenu,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Text(
                              'AIUTO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.white,
                        elevation: 5,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Ripristina posizione',
                          onPressed: () {
                            setState(() => _followGps = true);
                            _controller.move(_position, _navigationZoom);
                          },
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_offTrack) ...[
                    const SizedBox(height: 12),
                    AnimatedOpacity(
                      opacity: _offTrackFlash ? 1.0 : 0.35,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44000000), blurRadius: 8),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'FUORI TRACCIA – TORNA SUL PERCORSO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _ExperimentalArView extends StatefulWidget {
  final CameraDescription camera;
  final List<LatLng> route;
  final LatLng initialPosition;
  final String destinationName;

  const _ExperimentalArView({
    required this.camera,
    required this.route,
    required this.initialPosition,
    required this.destinationName,
  });

  @override
  State<_ExperimentalArView> createState() => _ExperimentalArViewState();
}

class _ExperimentalArViewState extends State<_ExperimentalArView> {
  late final CameraController _cameraController;
  Future<void>? _initialize;
  StreamSubscription? _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;

  late LatLng _position;
  double _heading = 0;
  bool _hasCompass = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initialize = _cameraController.initialize();

    _gpsSub = GpsService.stream().listen((p) {
      if (!mounted) return;
      setState(() {
        _position = LatLng(p.latitude, p.longitude);
        if (!_hasCompass && p.heading.isFinite && p.heading >= 0) {
          _heading = _smoothHeading(_heading, p.heading, 0.18);
        }
      });
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (!mounted || h == null || !h.isFinite) return;
      setState(() {
        _hasCompass = true;
        _heading = _smoothHeading(_heading, h, 0.22);
      });
    });
  }

  double _smoothHeading(double current, double next, double factor) {
    final delta = ((next - current + 540) % 360) - 180;
    return (current + delta * factor + 360) % 360;
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initialize,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Vista AR non disponibile',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final next = _nextRoutePoint(widget.route, _position);
          final nextBearing = next == null
              ? _heading
              : Geolocator.bearingBetween(
                  _position.latitude,
                  _position.longitude,
                  next.latitude,
                  next.longitude,
                );

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_cameraController),

              // Linea blu AR calcolata dai veri punti GPS del percorso.
              IgnorePointer(
                child: CustomPaint(
                  painter: _ArRoutePainter(
                    route: widget.route,
                    position: _position,
                    heading: _heading,
                  ),
                ),
              ),

              // Freccia di navigazione: indica il prossimo tratto reale.
              IgnorePointer(
                child: _ArDirectionArrow(
                  relativeBearing: _angleDelta(nextBearing, _heading),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xDDFFFFFF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'AR • ${widget.destinationName}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xA8000000),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Text(
                          'Segui la linea blu e la freccia',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800),
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
    );
  }
}

LatLng? _nextRoutePoint(List<LatLng> route, LatLng position) {
  if (route.isEmpty) return null;

  var nearest = 0;
  var best = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final d = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      route[i].latitude, route[i].longitude);
    if (d < best) {
      best = d;
      nearest = i;
    }
  }

  // Punta abbastanza avanti da dare una direzione stabile, non al singolo
  // punto GPS immediatamente vicino che farebbe tremare la freccia.
  var target = nearest;
  var travelled = 0.0;
  while (target < route.length - 1 && travelled < 18.0) {
    final a = route[target];
    final b = route[target + 1];
    travelled += Geolocator.distanceBetween(
      a.latitude, a.longitude, b.latitude, b.longitude);
    target++;
  }
  return route[target];
}

double _angleDelta(double bearing, double heading) {
  return ((bearing - heading + 540) % 360) - 180;
}

class _ArDirectionArrow extends StatelessWidget {
  final double relativeBearing;

  const _ArDirectionArrow({required this.relativeBearing});

  @override
  Widget build(BuildContext context) {
    // Con camera ~60° di campo visivo, 30° corrispondono quasi al bordo.
    final clamped = relativeBearing.clamp(-38.0, 38.0).toDouble();
    final radians = clamped * math.pi / 180;

    return Align(
      alignment: const Alignment(0, 0.18),
      child: Transform.rotate(
        angle: radians,
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0x440D6EFD),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xCCFFFFFF),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.navigation_rounded,
            size: 68,
            color: Color(0xFF0D6EFD),
          ),
        ),
      ),
    );
  }
}

class _ArRoutePainter extends CustomPainter {
  final List<LatLng> route;
  final LatLng position;
  final double heading;

  const _ArRoutePainter({
    required this.route,
    required this.position,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;

    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final d = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        route[i].latitude, route[i].longitude);
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    final projected = <Offset>[];
    double along = 0.0;
    LatLng? previous;

    // Disegniamo solo il tratto davanti all'utente, fino a circa 220 m.
    for (var i = nearest; i < route.length; i++) {
      final p = route[i];
      if (previous != null) {
        along += Geolocator.distanceBetween(
          previous.latitude, previous.longitude, p.latitude, p.longitude);
      }
      previous = p;
      if (along > 220) break;

      final distance = Geolocator.distanceBetween(
        position.latitude, position.longitude, p.latitude, p.longitude);
      if (distance < 3) continue;

      final bearing = Geolocator.bearingBetween(
        position.latitude, position.longitude, p.latitude, p.longitude);
      final rel = _angleDelta(bearing, heading);

      // Camera approssimata a 70° orizzontali. I punti molto fuori campo
      // vengono ignorati: rientrano appena l'utente orienta il telefono.
      if (rel.abs() > 42) continue;

      final x = size.width * 0.5 + (rel / 42.0) * size.width * 0.48;

      // Il vicino resta basso, il lontano sale verso l'orizzonte.
      final norm = (distance / 220.0).clamp(0.0, 1.0);
      final y = size.height * (0.84 - 0.43 * math.sqrt(norm));
      projected.add(Offset(x, y));
    }

    if (projected.isEmpty) return;

    final glow = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final blue = Paint()
      ..color = const Color(0xE60D6EFD)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = ui.Path();
    path.moveTo(size.width * 0.5, size.height * 0.91);
    for (final p in projected) {
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, glow);
    canvas.drawPath(path, blue);
  }

  @override
  bool shouldRepaint(covariant _ArRoutePainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.heading != heading ||
        oldDelegate.route != route;
  }
}
