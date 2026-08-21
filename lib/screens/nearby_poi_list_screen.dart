import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/hiking_router.dart';
import '../services/nearby_poi_service.dart';
import 'navigation_screen.dart';
import 'poi_route_summary_screen.dart';
import 'v8_choice_screen.dart';

class NearbyPoiListScreen extends StatelessWidget {
  final V8Mode mode;
  final String activity;
  final String? place;
  final LatLng center;
  final List<NearbyPoi> items;

  const NearbyPoiListScreen({
    super.key,
    required this.mode,
    required this.activity,
    required this.place,
    required this.center,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        title: Text(
          '$activity entro 10 km',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Nessun elemento reale trovato entro 10 km.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final item = items[index];
                return Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      child: Icon(_iconFor(item.category)),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${item.distanceKm.toStringAsFixed(1)} km${item.subtitle.isEmpty ? '' : ' · ${item.subtitle}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      if (item.category == NearbyPoiCategory.drinkingWater) {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            content: Text(
                              'Vuoi che GoTr-Ail ti porti a questa fontana? '
                              'Dista ${item.distanceKm.toStringAsFixed(1)} km.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('ANNULLA'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('PORTAMI'),
                              ),
                            ],
                          ),
                        );
                        if (yes != true || !context.mounted) return;

                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        final result = await HikingRouter.instance.route(
                          start: center,
                          destination: item.point,
                        );
                        if (!context.mounted) return;
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
                              destinationName: item.name,
                              initialPosition: center,
                            ),
                          ),
                        );
                        return;
                      }

                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PoiRouteSummaryScreen(
                            destination: item,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  IconData _iconFor(NearbyPoiCategory category) {
    switch (category) {
      case NearbyPoiCategory.hut:
        return Icons.cabin_rounded;
      case NearbyPoiCategory.waterfall:
        return Icons.water_drop_rounded;
      case NearbyPoiCategory.drinkingWater:
        return Icons.local_drink_rounded;
    }
  }
}
