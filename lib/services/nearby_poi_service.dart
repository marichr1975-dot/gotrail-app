import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'organic_maps_search_bridge.dart';

enum NearbyPoiCategory { hut, waterfall, drinkingWater }

class NearbyPoi {
  final String name;
  final String subtitle;
  final LatLng point;
  final NearbyPoiCategory category;
  final double distanceKm;

  const NearbyPoi({
    required this.name,
    required this.subtitle,
    required this.point,
    required this.category,
    required this.distanceKm,
  });
}

class NearbyPoiSnapshot {
  final Map<NearbyPoiCategory, List<NearbyPoi>> items;
  final bool usedOrganic;
  final bool usedOnlineFallback;
  final bool sourceAvailable;
  final String sourceMessage;

  const NearbyPoiSnapshot({
    required this.items,
    required this.usedOrganic,
    required this.usedOnlineFallback,
    this.sourceAvailable = true,
    this.sourceMessage = '',
  });

  int count(NearbyPoiCategory category) => items[category]?.length ?? 0;

  List<NearbyPoi> forCategory(NearbyPoiCategory category) =>
      items[category] ?? const <NearbyPoi>[];
}

/// Scansione POI reale entro un raggio.
///
/// PrioritÃ  V11.3:
/// 1) bridge Organic Maps/MWM locale;
/// 2) se il bridge nativo non Ã¨ ancora disponibile, fallback OSM Overpass.
///
/// Il fallback non inventa risultati: se non riesce a leggere dati reali,
/// restituisce zero elementi.
class NearbyPoiService {
  NearbyPoiService._();
  static final instance = NearbyPoiService._();

  static const _radiusKm = 10.0;

  Future<NearbyPoiSnapshot> scan(
    LatLng center, {
    double radiusKm = _radiusKm,
  }) async {
    final organicItems = await _scanOrganic(center, radiusKm);

    // V11.88: non basta trovare "qualcosa" con Organic Maps.
    // Se una categoria e vuota (es. rifugi presenti ma cascate = 0),
    // proviamo il fallback OSM SOLO per completare le categorie mancanti.
    final missingCategory = NearbyPoiCategory.values.any(
      (category) => organicItems[category]?.isEmpty ?? true,
    );

    if (!missingCategory) {
      return NearbyPoiSnapshot(
        items: organicItems,
        usedOrganic: true,
        usedOnlineFallback: false,
        sourceAvailable: true,
        sourceMessage: 'Organic Maps',
      );
    }

    final online = await _scanOverpass(center, radiusKm);
    final merged = <NearbyPoiCategory, List<NearbyPoi>>{};

    for (final category in NearbyPoiCategory.values) {
      final organic = List<NearbyPoi>.from(
        organicItems[category] ?? const <NearbyPoi>[],
      );
      final fallback = online.items[category] ?? const <NearbyPoi>[];

      if (organic.isEmpty) {
        merged[category] = List<NearbyPoi>.from(fallback);
      } else {
        merged[category] = organic;
      }
    }

    _sortHutsByPriority(merged[NearbyPoiCategory.hut]!);

    return NearbyPoiSnapshot(
      items: merged,
      usedOrganic: organicItems.values.any((list) => list.isNotEmpty),
      usedOnlineFallback: online.ok &&
          NearbyPoiCategory.values.any(
            (category) =>
                (organicItems[category]?.isEmpty ?? true) &&
                (online.items[category]?.isNotEmpty ?? false),
          ),
      sourceAvailable:
          organicItems.values.any((list) => list.isNotEmpty) || online.ok,
      sourceMessage: online.ok ? 'Organic Maps + OpenStreetMap' : 'Organic Maps',
    );
  }

  Future<Map<NearbyPoiCategory, List<NearbyPoi>>> _scanOrganic(
    LatLng center,
    double radiusKm,
  ) async {
    final result = <NearbyPoiCategory, List<NearbyPoi>>{
      NearbyPoiCategory.hut: <NearbyPoi>[],
      NearbyPoiCategory.waterfall: <NearbyPoi>[],
      NearbyPoiCategory.drinkingWater: <NearbyPoi>[],
    };

    final searches = <NearbyPoiCategory, List<String>>{
      NearbyPoiCategory.hut: const [
        'rifugio',
        'malga',
        'baita',
        'bivacco',
      ],
      NearbyPoiCategory.waterfall: const [
        'cascata',
        'cascate',
        'waterfall',
      ],
      NearbyPoiCategory.drinkingWater: const [
        'fontana',
        'acqua potabile',
      ],
    };

    for (final entry in searches.entries) {
      final seen = <String>{};
      for (final query in entry.value) {
        final found = await OrganicMapsSearchBridge.instance.search(
          query: query,
          center: center,
          radiusKm: radiusKm,
        );
        for (final item in found) {
          final km = Geolocator.distanceBetween(
                center.latitude,
                center.longitude,
                item.point.latitude,
                item.point.longitude,
              ) /
              1000.0;
          if (km > radiusKm) continue;
          final key = _dedupeKey(item.name, item.point);
          if (!seen.add(key)) continue;
          result[entry.key]!.add(
            NearbyPoi(
              name: item.name.trim().isEmpty ? _fallbackName(entry.key) : item.name.trim(),
              subtitle: item.subtitle.trim(),
              point: item.point,
              category: entry.key,
              distanceKm: km,
            ),
          );
        }
      }
      if (entry.key == NearbyPoiCategory.hut) {
        _sortHutsByPriority(result[entry.key]!);
      } else {
        result[entry.key]!.sort(
          (a, b) => a.distanceKm.compareTo(b.distanceKm),
        );
      }
    }

    return result;
  }

  Future<({Map<NearbyPoiCategory, List<NearbyPoi>> items, bool ok, String message})> _scanOverpass(
    LatLng center,
    double radiusKm,
  ) async {
    final empty = <NearbyPoiCategory, List<NearbyPoi>>{
      NearbyPoiCategory.hut: <NearbyPoi>[],
      NearbyPoiCategory.waterfall: <NearbyPoi>[],
      NearbyPoiCategory.drinkingWater: <NearbyPoi>[],
    };

    final radiusM = (radiusKm * 1000).round();
    final lat = center.latitude;
    final lon = center.longitude;
    final query = '''[out:json][timeout:35];
(
  nwr(around:$radiusM,$lat,$lon)[tourism="alpine_hut"];
  nwr(around:$radiusM,$lat,$lon)[tourism="wilderness_hut"];
  nwr(around:$radiusM,$lat,$lon)[natural="waterfall"];
  nwr(around:$radiusM,$lat,$lon)[waterway="waterfall"];
  nwr(around:$radiusM,$lat,$lon)[tourism="viewpoint"][name~"cascat|waterfall",i];
  nwr(around:$radiusM,$lat,$lon)[amenity="drinking_water"];
  nwr(around:$radiusM,$lat,$lon)[amenity="fountain"][drinking_water!="no"];
  nwr(around:$radiusM,$lat,$lon)[man_made="water_tap"][drinking_water!="no"];
);
out center tags qt;''';

    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.nchc.org.tw/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    String lastError = 'nessuna risposta';
    http.Response? response;

    for (final endpoint in endpoints) {
      try {
        final base = Uri.parse(endpoint);
        final uri = base.replace(queryParameters: {'data': query});
        final candidate = await http.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'GoTr-Ail/11.3',
          },
        ).timeout(const Duration(seconds: 28));
        if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
          response = candidate;
          break;
        }
        lastError = 'HTTP ${candidate.statusCode}';
      } catch (e) {
        lastError = e.runtimeType.toString();
      }

      try {
        final candidate = await http.post(
          Uri.parse(endpoint),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'GoTr-Ail/11.3',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 28));
        if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
          response = candidate;
          break;
        }
        lastError = 'HTTP ${candidate.statusCode}';
      } catch (e) {
        lastError = e.runtimeType.toString();
      }
    }

    if (response == null) {
      return (items: empty, ok: false, message: 'OSM non raggiungibile: $lastError');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (items: empty, ok: false, message: 'Risposta OSM non valida');
      }
      final elements = decoded['elements'];
      if (elements is! List) {
        return (items: empty, ok: false, message: 'Risposta OSM senza elementi');
      }

      final seen = <NearbyPoiCategory, Set<String>>{
        NearbyPoiCategory.hut: <String>{},
        NearbyPoiCategory.waterfall: <String>{},
        NearbyPoiCategory.drinkingWater: <String>{},
      };

      for (final raw in elements) {
        if (raw is! Map) continue;
        final tagsRaw = raw['tags'];
        final tags = tagsRaw is Map ? tagsRaw : const <String, dynamic>{};
        final category = _categoryFromTags(tags);
        if (category == null) continue;

        final latValue = _number(raw['lat']) ?? _number((raw['center'] as Map?)?['lat']);
        final lonValue = _number(raw['lon']) ?? _number((raw['center'] as Map?)?['lon']);
        if (latValue == null || lonValue == null) continue;

        final point = LatLng(latValue, lonValue);
        final km = Geolocator.distanceBetween(
              center.latitude,
              center.longitude,
              point.latitude,
              point.longitude,
            ) /
            1000.0;
        if (km > radiusKm) continue;

        final name = (tags['name'] ?? tags['ref'] ?? _fallbackName(category)).toString().trim();
        final key = _dedupeKey(name, point);
        if (!seen[category]!.add(key)) continue;

        empty[category]!.add(
          NearbyPoi(
            name: name.isEmpty ? _fallbackName(category) : name,
            subtitle: _subtitleFromTags(tags, category),
            point: point,
            category: category,
            distanceKm: km,
          ),
        );
      }

      for (final list in empty.values) {
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      }
      return (items: empty, ok: true, message: 'OpenStreetMap');
    } catch (e) {
      return (items: empty, ok: false, message: 'Errore lettura OSM: ${e.runtimeType}');
    }
  }

  Future<NearbyPoi?> nearestParking(
    LatLng destination, {
    double maxRadiusKm = 15,
  }) async {
    final radii = <double>[3, 6, 10, maxRadiusKm]
        .where((r) => r <= maxRadiusKm)
        .toSet()
        .toList()
      ..sort();

    for (final radiusKm in radii) {
      final result = await _parkingOverpass(destination, radiusKm);
      if (result.isNotEmpty) return result.first;
    }
    return null;
  }

  Future<List<NearbyPoi>> _parkingOverpass(
    LatLng destination,
    double radiusKm,
  ) async {
    final radiusM = (radiusKm * 1000).round();
    final lat = destination.latitude;
    final lon = destination.longitude;

    final query = '''[out:json][timeout:30];
(
  nwr(around:$radiusM,$lat,$lon)[amenity="parking"][access!="private"][access!="no"];
);
out center tags qt;''';

    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    http.Response? response;
    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint).replace(queryParameters: {'data': query});
        final candidate = await http.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'GoTr-Ail/11.4',
          },
        ).timeout(const Duration(seconds: 24));
        if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
          response = candidate;
          break;
        }
      } catch (_) {}
    }

    if (response == null) return const [];

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
        return const [];
      }

      final result = <NearbyPoi>[];
      for (final raw in decoded['elements'] as List) {
        if (raw is! Map) continue;
        final tags = raw['tags'] is Map ? raw['tags'] as Map : const {};
        final latValue =
            _number(raw['lat']) ?? _number((raw['center'] as Map?)?['lat']);
        final lonValue =
            _number(raw['lon']) ?? _number((raw['center'] as Map?)?['lon']);
        if (latValue == null || lonValue == null) continue;

        final point = LatLng(latValue, lonValue);
        final km = Geolocator.distanceBetween(
              destination.latitude,
              destination.longitude,
              point.latitude,
              point.longitude,
            ) /
            1000.0;

        final nameRaw = (tags['name'] ?? '').toString().trim();
        final name = nameRaw.isEmpty ? 'Parcheggio' : nameRaw;
        final access = (tags['access'] ?? '').toString().toLowerCase();
        if (access == 'private' || access == 'no') continue;

        result.add(
          NearbyPoi(
            name: name,
            subtitle: 'Parcheggio Â· ${km.toStringAsFixed(1)} km dalla meta',
            point: point,
            category: NearbyPoiCategory.hut,
            distanceKm: km,
          ),
        );
      }

      result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return result;
    } catch (_) {
      return const [];
    }
  }

  NearbyPoiCategory? _categoryFromTags(Map tags) {
    final tourism = tags['tourism']?.toString();
    if (tourism == 'alpine_hut' || tourism == 'wilderness_hut') {
      return NearbyPoiCategory.hut;
    }
    final natural = tags['natural']?.toString().toLowerCase();
    final waterway = tags['waterway']?.toString().toLowerCase();
    final name = tags['name']?.toString().toLowerCase() ?? '';
    if (natural == 'waterfall' ||
        waterway == 'waterfall' ||
        (tourism == 'viewpoint' &&
            (name.contains('cascat') || name.contains('waterfall')))) {
      return NearbyPoiCategory.waterfall;
    }
    final amenity = tags['amenity']?.toString();
    final manMade = tags['man_made']?.toString();
    final drinking = tags['drinking_water']?.toString();
    if (amenity == 'drinking_water' ||
        (amenity == 'fountain' && drinking == 'yes') ||
        (manMade == 'water_tap' && drinking != 'no')) {
      return NearbyPoiCategory.drinkingWater;
    }
    return null;
  }

  String _subtitleFromTags(Map tags, NearbyPoiCategory category) {
    final elevation = tags['ele']?.toString();
    final operatorName = tags['operator']?.toString();
    if (elevation != null && elevation.isNotEmpty) return 'Quota $elevation m';
    if (operatorName != null && operatorName.isNotEmpty) return operatorName;
    switch (category) {
      case NearbyPoiCategory.hut:
        return 'Rifugio';
      case NearbyPoiCategory.waterfall:
        return 'Cascata';
      case NearbyPoiCategory.drinkingWater:
        return 'Acqua potabile';
    }
  }

  String _fallbackName(NearbyPoiCategory category) {
    switch (category) {
      case NearbyPoiCategory.hut:
        return 'Rifugio';
      case NearbyPoiCategory.waterfall:
        return 'Cascata';
      case NearbyPoiCategory.drinkingWater:
        return 'Fontana';
    }
  }

  void _sortHutsByPriority(List<NearbyPoi> list) {
    int priority(NearbyPoi poi) {
      final text = '${poi.name} ${poi.subtitle}'.toLowerCase();
      if (text.contains('bivacc')) return 3;
      if (text.contains('malga') || text.contains('baita')) return 2;
      if (text.contains('rifug') || text.contains('alpine_hut')) return 0;
      return 1;
    }

    list.sort((a, b) {
      final byType = priority(a).compareTo(priority(b));
      if (byType != 0) return byType;
      return a.distanceKm.compareTo(b.distanceKm);
    });
  }

  String _dedupeKey(String name, LatLng point) =>
      '${name.trim().toLowerCase()}|${point.latitude.toStringAsFixed(5)}|${point.longitude.toStringAsFixed(5)}';

  double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}






