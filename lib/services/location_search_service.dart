import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'gemini_ai_service.dart';

class LocationSearchResult {
  final String label;
  final LatLng point;
  final String mapHint;

  const LocationSearchResult({
    required this.label,
    required this.point,
    this.mapHint = '',
  });
}

class LocationSearchService {
  LocationSearchService._();
  static final instance = LocationSearchService._();

  // 8.9: piccolo indice locale per le località usate più spesso nei test e
  // nelle Dolomiti venete. Serve a Pianifica anche senza rete: se la località
  // è nell'indice non viene fatta alcuna chiamata a Nominatim.
  static final Map<String, LocationSearchResult> _offlinePlaces = {
    'auronzo': const LocationSearchResult(
      label: 'Auronzo di Cadore (BL)',
      point: LatLng(46.5503, 12.4416),
    ),
    'auronzo di cadore': const LocationSearchResult(
      label: 'Auronzo di Cadore (BL)',
      point: LatLng(46.5503, 12.4416),
    ),
    'misurina': const LocationSearchResult(
      label: 'Misurina (BL)',
      point: LatLng(46.5828, 12.2547),
    ),
    'cortina': const LocationSearchResult(
      label: "Cortina d'Ampezzo (BL)",
      point: LatLng(46.5405, 12.1357),
    ),
    "cortina d'ampezzo": const LocationSearchResult(
      label: "Cortina d'Ampezzo (BL)",
      point: LatLng(46.5405, 12.1357),
    ),
    'belluno': const LocationSearchResult(
      label: 'Belluno (BL)',
      point: LatLng(46.1399, 12.2176),
    ),
    'alleghe': const LocationSearchResult(
      label: 'Alleghe (BL)',
      point: LatLng(46.4074, 12.0242),
    ),
    'selva di cadore': const LocationSearchResult(
      label: 'Selva di Cadore (BL)',
      point: LatLng(46.4506, 12.0564),
    ),
    'arabba': const LocationSearchResult(
      label: 'Arabba (BL)',
      point: LatLng(46.4971, 11.8752),
    ),
    'san vito di cadore': const LocationSearchResult(
      label: 'San Vito di Cadore (BL)',
      point: LatLng(46.4618, 12.2067),
    ),
    'borca di cadore': const LocationSearchResult(
      label: 'Borca di Cadore (BL)',
      point: LatLng(46.4360, 12.2221),
    ),
    'pieve di cadore': const LocationSearchResult(
      label: 'Pieve di Cadore (BL)',
      point: LatLng(46.4271, 12.3747),
    ),
    'poz zale di cadore': const LocationSearchResult(
      label: 'Pozzale di Cadore (BL)',
      point: LatLng(46.4148, 12.3754),
    ),
    'pozzale di cadore': const LocationSearchResult(
      label: 'Pozzale di Cadore (BL)',
      point: LatLng(46.4148, 12.3754),
    ),
    'sappada': const LocationSearchResult(
      label: 'Sappada (UD)',
      point: LatLng(46.5684, 12.6841),
    ),
    'longarone': const LocationSearchResult(
      label: 'Longarone (BL)',
      point: LatLng(46.2673, 12.3015),
    ),
    'feltre': const LocationSearchResult(
      label: 'Feltre (BL)',
      point: LatLng(46.0189, 11.9068),
    ),
    'agordo': const LocationSearchResult(
      label: 'Agordo (BL)',
      point: LatLng(46.2827, 12.0340),
    ),
    'falcade': const LocationSearchResult(
      label: 'Falcade (BL)',
      point: LatLng(46.3563, 11.8736),
    ),
    'venezia': const LocationSearchResult(
      label: 'Venezia (VE)',
      point: LatLng(45.4408, 12.3155),
    ),
    'mestre': const LocationSearchResult(
      label: 'Mestre (VE)',
      point: LatLng(45.4935, 12.2416),
    ),
    'brunico': const LocationSearchResult(
      label: 'Brunico / Bruneck (BZ)',
      point: LatLng(46.7963, 11.9360),
    ),
    'bruneck': const LocationSearchResult(
      label: 'Brunico / Bruneck (BZ)',
      point: LatLng(46.7963, 11.9360),
    ),
    'mira': const LocationSearchResult(
      label: 'Mira (VE)',
      point: LatLng(45.4342, 12.1331),
    ),
    'treviso': const LocationSearchResult(
      label: 'Treviso (TV)',
      point: LatLng(45.6669, 12.2430),
    ),
    'vicenza': const LocationSearchResult(
      label: 'Vicenza (VI)',
      point: LatLng(45.5455, 11.5354),
    ),
    'verona': const LocationSearchResult(
      label: 'Verona (VR)',
      point: LatLng(45.4384, 10.9916),
    ),
    'padova': const LocationSearchResult(
      label: 'Padova (PD)',
      point: LatLng(45.4064, 11.8768),
    ),
    'rovigo': const LocationSearchResult(
      label: 'Rovigo (RO)',
      point: LatLng(45.0703, 11.7901),
    ),
  };

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll(RegExp(r'\s+'), ' ');


  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }

  List<LocationSearchResult> suggestions(String query, {int limit = 5}) {
    final normalized = _normalize(query);
    if (normalized.length < 2) return const [];

    final scored = <({int score, LocationSearchResult result})>[];
    final seen = <String>{};

    for (final entry in _offlinePlaces.entries) {
      final key = _normalize(entry.key);
      int score;

      if (key == normalized) {
        score = 0;
      } else if (key.startsWith(normalized) || normalized.startsWith(key)) {
        score = 1;
      } else if (key.contains(normalized) || normalized.contains(key)) {
        score = 2;
      } else {
        final distance = _levenshtein(normalized, key);
        final allowed = normalized.length <= 4
            ? 1
            : normalized.length <= 7
                ? 2
                : 3;
        if (distance > allowed) continue;
        score = 10 + distance;
      }

      final uniqueKey = '${entry.value.label}|${entry.value.point.latitude}|${entry.value.point.longitude}';
      if (seen.add(uniqueKey)) {
        scored.add((score: score, result: entry.value));
      }
    }

    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      return a.result.label.compareTo(b.result.label);
    });

    return scored.take(limit).map((e) => e.result).toList(growable: false);
  }

  LocationSearchResult? exactLocalMatch(String query) {
    final normalized = _normalize(query);
    return _offlinePlaces[normalized];
  }

  LocationSearchResult? _bestOfflineMatch(String query) {
    final normalized = _normalize(query);
    final exact = _offlinePlaces[normalized];
    if (exact != null) return exact;

    final matches = suggestions(query, limit: 1);
    return matches.isEmpty ? null : matches.first;
  }

  Future<List<LocationSearchResult>> intelligentSuggestions(
    String query, {
    int limit = 5,
  }) async {
    final results = await GeminiAiService.instance.resolvePlaces(
      query,
      limit: limit,
    );
    return results
        .map(
          (r) => LocationSearchResult(
            label: '${r.label} · ${r.province}',
            point: LatLng(r.latitude, r.longitude),
            mapHint: '${r.province} ${r.region}',
          ),
        )
        .toList(growable: false);
  }

  Future<LocationSearchResult?> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    final results = await intelligentSuggestions(q, limit: 1);
    return results.isEmpty ? null : results.first;
  }

}
