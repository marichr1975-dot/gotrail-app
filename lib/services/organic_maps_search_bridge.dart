import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class OrganicSearchResult {
  final String name;
  final String subtitle;
  final LatLng point;
  final String type;
  const OrganicSearchResult({required this.name, required this.subtitle, required this.point, required this.type});

  factory OrganicSearchResult.fromMap(Map<Object?, Object?> raw) => OrganicSearchResult(
    name: raw['name']?.toString() ?? '',
    subtitle: raw['subtitle']?.toString() ?? '',
    point: LatLng((raw['lat'] as num?)?.toDouble() ?? 0, (raw['lon'] as num?)?.toDouble() ?? 0),
    type: raw['type']?.toString() ?? '',
  );
}

class OrganicMapsSearchBridge {
  OrganicMapsSearchBridge._();
  static final instance = OrganicMapsSearchBridge._();
  static const _channel = MethodChannel('gotrail/organic_search');

  Future<List<OrganicSearchResult>> search({required String query, required LatLng center, double radiusKm = 10}) async {
    if (query.trim().length < 2) return const [];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('search', {
        'query': query.trim(), 'lat': center.latitude, 'lon': center.longitude, 'radiusKm': radiusKm,
      });
      return (raw ?? const []).whereType<Map<Object?, Object?>>().map(OrganicSearchResult.fromMap).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
