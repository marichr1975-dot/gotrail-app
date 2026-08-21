import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ElevationProfile {
  final List<double> elevations;
  final double minElevation;
  final double maxElevation;
  final double ascent;
  final double descent;

  const ElevationProfile({
    required this.elevations,
    required this.minElevation,
    required this.maxElevation,
    required this.ascent,
    required this.descent,
  });
}

class ElevationService {
  ElevationService._();
  static final instance = ElevationService._();

  Future<ElevationProfile?> profile(List<LatLng> route) async {
    if (route.length < 2) return null;

    final sample = _sample(route, maxPoints: 70);
    final elevations = <double>[];

    for (var start = 0; start < sample.length; start += 30) {
      final end = (start + 30 < sample.length) ? start + 30 : sample.length;
      final chunk = sample.sublist(start, end);

      final latitudes = chunk.map((p) => p.latitude.toStringAsFixed(6)).join(',');
      final longitudes = chunk.map((p) => p.longitude.toStringAsFixed(6)).join(',');

      try {
        final uri = Uri.parse('https://api.open-meteo.com/v1/elevation').replace(
          queryParameters: {
            'latitude': latitudes,
            'longitude': longitudes,
          },
        );

        final response = await http.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'GoTr-Ail/11.5',
          },
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) return null;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['elevation'] is! List) return null;

        for (final raw in decoded['elevation'] as List) {
          if (raw is num) elevations.add(raw.toDouble());
        }
      } catch (_) {
        return null;
      }
    }

    if (elevations.length < 2) return null;

    var minE = elevations.first;
    var maxE = elevations.first;
    var ascent = 0.0;
    var descent = 0.0;

    for (var i = 0; i < elevations.length; i++) {
      final e = elevations[i];
      if (e < minE) minE = e;
      if (e > maxE) maxE = e;

      if (i > 0) {
        final delta = e - elevations[i - 1];
        if (delta > 0) {
          ascent += delta;
        } else {
          descent += -delta;
        }
      }
    }

    return ElevationProfile(
      elevations: elevations,
      minElevation: minE,
      maxElevation: maxE,
      ascent: ascent,
      descent: descent,
    );
  }

  List<LatLng> _sample(List<LatLng> route, {required int maxPoints}) {
    if (route.length <= maxPoints) return List<LatLng>.from(route);

    final result = <LatLng>[];
    final step = (route.length - 1) / (maxPoints - 1);

    for (var i = 0; i < maxPoints; i++) {
      final index = (i * step).round().clamp(0, route.length - 1);
      result.add(route[index]);
    }

    return result;
  }
}
