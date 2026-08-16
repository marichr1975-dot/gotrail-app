import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationSearchResult {
  final String label;
  final LatLng point;
  const LocationSearchResult({required this.label, required this.point});
}

class LocationSearchService {
  LocationSearchService._();
  static final instance = LocationSearchService._();

  Future<LocationSearchResult?> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'it',
    });

    final response = await http
        .get(
          uri,
          headers: const {
            'User-Agent': 'GoTr-AI/6.5 (planning search)',
            'Accept-Language': 'it',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Ricerca località: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final first = Map<String, dynamic>.from(decoded.first as Map);
    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    return LocationSearchResult(
      label: first['display_name']?.toString() ?? q,
      point: LatLng(lat, lon),
    );
  }
}
