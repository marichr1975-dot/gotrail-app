
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_package.dart';
import '../services/gps_service.dart';
import '../services/map_package_manager.dart';
import '../services/map_manager.dart';
import 'map_download_dialog.dart';
import 'map_screen.dart';
import 'planning_map_screen.dart';
import 'saved_routes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _working = false;

  Future<void> _start() async {
    if (_working) return;
    setState(() => _working = true);

    try {
      final position = await GpsService.currentPosition();
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      final package = MapCatalog.packageFor(point);

      if (package == null) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(
              'Zona non disponibile',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: const Text(
              'La mappa GoTr di questa zona non è ancora disponibile.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // INIZIA usa lo stesso archivio cartografico MBTiles di PIANIFICA.
      // Se la mappa regionale è già presente non viene riscaricata.
      await MapManager.instance.ensureMapForPoint(point);
      if (!mounted) return;

      // I dati operativi delle 4 icone sono ancora nei piccoli GeoJSON.
      // Scarichiamo solo questi se mancano; non la grande mappa regionale.
      final installed = await MapPackageManager.instance.isInstalled(package);
      if (!installed) {
        await MapPackageManager.instance.download(
          package,
          onProgress: (_) {},
        );
      }
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapScreen(
            package: package,
            initialPosition: point,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'GPS non disponibile',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _plan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlanningMapScreen()),
    );
  }

  void _savedRoutes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedRoutesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final exit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(
              'Uscire da GoTr-AI?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: const Text(
              'Vuoi chiudere l’app?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('NO'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                child: const Text('ESCI'),
              ),
            ],
          ),
        );

        if (exit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/monte_pelmo.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text(
                    'GoTr-AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Color(0x88000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Il tuo accompagnatore nei sentieri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F9448),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _working ? null : _start,
                      child: _working
                          ? const SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'INIZIA',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF18539A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _working ? null : _plan,
                      child: const Text('PIANIFICA', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xDDFFFFFF),
                        foregroundColor: const Color(0xFF18539A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFF18539A), width: 1.4),
                        ),
                      ),
                      onPressed: _working ? null : _savedRoutes,
                      icon: const Icon(Icons.bookmarks_rounded),
                      label: const Text(
                        'PERCORSI SALVATI',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}