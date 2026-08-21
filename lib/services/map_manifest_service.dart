import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/region_map.dart';

class MapManifestService {
  MapManifestService._();
  static final instance = MapManifestService._();

  static const String manifestUrl =
      'https://raw.githubusercontent.com/marichr1975-dot/nuove-mappe/main/maps.json';

  // Fallback integrato: la 6.6 continua a funzionare anche prima di caricare
  // maps.json nel repository. Quando il file online esiste, prevale quello.
  static const List<Map<String, dynamic>> _fallbackMaps = [
    {
      'id': 'veneto',
      'name': 'Veneto',
      'region': 'Veneto',
      'version': 1,
      'url':
          'https://github.com/marichr1975-dot/nuove-mappe/releases/download/maps-v1/veneto.mbtiles',
      'size': 305463296,
      'bounds': [44.75, 10.60, 46.70, 13.15],
    },
  ];

  List<RegionMap>? _cache;

  Future<List<RegionMap>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    // V9: avvio offline-first. Per la normale ricerca non aspettiamo Internet:
    // il catalogo Veneto integrato è disponibile immediatamente e riconosce
    // anche veneto.mbtiles copiato via ADB/PowerShell.
    if (!forceRefresh) {
      final fallback = _fallbackMaps
          .map((e) => RegionMap.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      _cache = fallback;
      return fallback;
    }

    try {
      final response = await http
          .get(
            Uri.parse(manifestUrl),
            headers: const {'User-Agent': 'GoTr-AI/9.0'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['maps'] is List) {
          final maps = <RegionMap>[];
          for (final raw in decoded['maps'] as List) {
            if (raw is Map) {
              maps.add(RegionMap.fromJson(Map<String, dynamic>.from(raw)));
            }
          }
          if (maps.isNotEmpty) {
            _cache = maps;
            return maps;
          }
        }
      }
    } catch (_) {}

    final fallback = _fallbackMaps
        .map((e) => RegionMap.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    _cache = fallback;
    return fallback;
  }

  void clearCache() => _cache = null;
}
