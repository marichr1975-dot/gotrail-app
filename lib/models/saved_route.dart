import 'package:latlong2/latlong.dart';

class SavedRoute {
  final String id;
  final String title;
  final DateTime savedAt;
  final List<LatLng> points;
  final double distanceKm;

  const SavedRoute({
    required this.id,
    required this.title,
    required this.savedAt,
    required this.points,
    required this.distanceKm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
        'distanceKm': distanceKm,
        'points': [
          for (final p in points)
            {
              'lat': p.latitude,
              'lon': p.longitude,
            },
        ],
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = <LatLng>[];

    if (rawPoints is List) {
      for (final raw in rawPoints) {
        if (raw is! Map) continue;
        final lat = raw['lat'];
        final lon = raw['lon'];
        if (lat is num && lon is num) {
          points.add(LatLng(lat.toDouble(), lon.toDouble()));
        }
      }
    }

    return SavedRoute(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Percorso salvato',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      points: points,
      distanceKm: (json['distanceKm'] is num)
          ? (json['distanceKm'] as num).toDouble()
          : 0,
    );
  }
}
