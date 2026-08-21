import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gps_service.dart';
import '../services/mwm_map_service.dart';
import '../services/region_map_manager_service.dart';
import 'map_manager_screen.dart';
import 'saved_routes_screen.dart';
import 'start_overview_map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _blue = Color(0xFF0B5FD7);
  static const _green = Color(0xFF20A85A);

  Future<void> _start(BuildContext context) async {
    final hasMaps = await RegionMapManagerService.instance.hasAnyInstalledMap();
    if (!context.mounted) return;

    if (!hasMaps) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MapManagerScreen()),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Cerco la tua posizione GPS…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final point = await GpsService.currentPosition();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final regionId =
          RegionMapManagerService.instance.regionIdForPoint(point);
      if (regionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Questa zona non è ancora disponibile nelle mappe offline.',
            ),
          ),
        );
        return;
      }

      final full =
          await RegionMapManagerService.instance.isRegionFullyInstalled(
        regionId,
      );
      if (!context.mounted) return;

      if (!full) {
        final label =
            RegionMapManagerService.regionLabels[regionId] ?? regionId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scarica prima la mappa completa di $label.'),
          ),
        );
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapManagerScreen()),
        );
        return;
      }

      final mwm = await MwmMapService.instance.mapForPoint(point);
      if (!context.mounted) return;

      if (mwm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Non trovo la mappa offline corretta per la posizione GPS.',
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StartOverviewMapScreen(
            initialPosition: point,
            regionLabel: mwm.regionLabel,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _confirmExit(BuildContext context) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Uscire da GoTr-Ail?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text('Vuoi veramente uscire dall\'app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/monte_pelmo.png',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22000818),
                  Color(0x55000818),
                  Color(0xE6071725),
                ],
                stops: [0, .46, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final compact = h < 700;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    compact ? 12 : 18,
                    18,
                    compact ? 12 : 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: compact ? 46 : 50,
                            height: compact ? 46 : 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.terrain_rounded,
                              color: _blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GoTr-Ail',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Il tuo accompagnatore nei sentieri',
                                  style: TextStyle(
                                    color: Color(0xFFEAF4FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            '11.7',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 28 : 44),
                      Text(
                        'Dove vuoi andare?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 25 : 28,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),

                      // I due pulsanti principali sono volutamente più piccoli.
                      _PrimaryAction(
                        title: 'INIZIA',
                        subtitle: 'Apri la mappa dalla tua posizione',
                        icon: Icons.navigation_rounded,
                        color: _green,
                        onTap: () => _start(context),
                      ),
                      const SizedBox(height: 8),
                      _PrimaryAction(
                        title: 'MAPPE',
                        subtitle: 'Gestisci le mappe offline',
                        icon: Icons.map_rounded,
                        color: _blue,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MapManagerScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Percorsi salvati resta, ma molto più compatto.
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SavedRoutesScreen(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF172C43),
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.2,
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(
                            Icons.bookmark_rounded,
                            size: 19,
                          ),
                          label: const Text(
                            'PERCORSI SALVATI',
                            style: TextStyle(
                              fontSize: 13,
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
          ),
        ],
      ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(17),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
