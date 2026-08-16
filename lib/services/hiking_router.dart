
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class HikingRouteResult {
  final List<LatLng> points;
  final String message;

  const HikingRouteResult({
    required this.points,
    required this.message,
  });

  bool get available => points.length >= 2;
}

class HikingRouter {
  HikingRouter._();
  static final instance = HikingRouter._();

  static const _servers = [
    'https://brouter.de/brouter',
    'https://brouter.m11n.de/brouter',
  ];

  Future<HikingRouteResult> route({
    required LatLng start,
    required LatLng destination,
  }) {
    return routeThrough([start, destination]);
  }

  Future<HikingRouteResult> routeThrough(
    List<LatLng> waypoints,
  ) async {
    if (waypoints.length < 2) {
      return const HikingRouteResult(
        points: [],
        message: 'Servono almeno due punti per calcolare un percorso.',
      );
    }

    Object? lastError;

    final lonLats = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join('|');

    for (final server in _servers) {
      try {
        final uri = Uri.parse(server).replace(
          queryParameters: {
            'lonlats': lonLats,
            'profile': 'hiking-mountain',
            'alternativeidx': '0',
            'format': 'geojson',
          },
        );

        final response = await http
            .get(
              uri,
              headers: const {
                'User-Agent': 'GoTr-AI/3.07',
                'Accept': 'application/geo+json,application/json',
              },
            )
            .timeout(const Duration(seconds: 22));

        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }

        final decoded = jsonDecode(response.body);
        final points = _extractRoutePoints(decoded);

        if (points.length < 2) {
          lastError = 'Risposta senza geometria';
          continue;
        }

        return HikingRouteResult(
          points: points,
          message: 'Percorso calcolato.',
        );
      } catch (e) {
        lastError = e;
      }
    }

    return HikingRouteResult(
      points: const [],
      message:
          'Non riesco a calcolare il percorso. '
          'Controlla la connessione dati e riprova. Dettaglio: $lastError',
    );
  }


  Future<HikingRouteResult> routeLoop({
    required LatLng start,
    required LatLng destination,
    required LatLng viaOut,
    required LatLng viaBack,
  }) async {
    // Calcoliamo due rotte separate verso lo stesso punto finale.
    // L'andata passa da viaOut; il ritorno passa dal lato opposto viaBack.
    final outward = await routeThrough([
      start,
      viaOut,
      destination,
    ]);

    if (!outward.available) return outward;

    final returning = await routeThrough([
      destination,
      viaBack,
      start,
    ]);

    if (!returning.available) return returning;

    final points = <LatLng>[
      ...outward.points,
      ...returning.points.skip(1),
    ];

    // Chiusura esatta sul GPS.
    if (points.isNotEmpty) {
      points[0] = start;
      points[points.length - 1] = start;
    }

    return HikingRouteResult(
      points: points,
      message: 'Percorso ad anello calcolato con andata e ritorno distinti.',
    );
  }

  List<LatLng> _extractRoutePoints(dynamic json) {
    final result = <LatLng>[];

    void addCoordinates(dynamic coordinates) {
      if (coordinates is! List || coordinates.isEmpty) return;

      if (coordinates.first is List &&
          (coordinates.first as List).length >= 2 &&
          (coordinates.first as List).first is num) {
        for (final raw in coordinates) {
          if (raw is List &&
              raw.length >= 2 &&
              raw[0] is num &&
              raw[1] is num) {
            result.add(
              LatLng(
                (raw[1] as num).toDouble(),
                (raw[0] as num).toDouble(),
              ),
            );
          }
        }
        return;
      }

      for (final child in coordinates) {
        addCoordinates(child);
      }
    }

    if (json is Map) {
      if (json['type'] == 'FeatureCollection' && json['features'] is List) {
        for (final feature in json['features'] as List) {
          if (feature is Map && feature['geometry'] is Map) {
            addCoordinates((feature['geometry'] as Map)['coordinates']);
          }
        }
      } else if (json['type'] == 'Feature' && json['geometry'] is Map) {
        addCoordinates((json['geometry'] as Map)['coordinates']);
      } else if (json['coordinates'] != null) {
        addCoordinates(json['coordinates']);
      }
    }

    final clean = <LatLng>[];
    for (final p in result) {
      if (clean.isEmpty) {
        clean.add(p);
        continue;
      }
      final last = clean.last;
      if ((last.latitude - p.latitude).abs() > 0.000001 ||
          (last.longitude - p.longitude).abs() > 0.000001) {
        clean.add(p);
      }
    }

    return clean;
  }
}
