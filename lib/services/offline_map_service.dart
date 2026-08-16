import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../models/map_models.dart';
import '../models/map_package.dart';
import 'map_package_manager.dart';

class OfflineMapService {
  OfflineMapService._();
  static final instance = OfflineMapService._();

  final Map<String, OfflineArea> _cache = {};

  /// Carica solo gli elementi utili attorno al GPS.
  ///
  /// Il GeoJSON deve comunque essere decodificato, ma evitiamo di trasformare
  /// in migliaia di oggetti Dart tutti i sentieri e POI della provincia.
  /// Sui telefoni meno recenti questo riduce soprattutto tempo e RAM necessari
  /// per arrivare alla schermata operativa.
  Future<OfflineArea> loadNearby(
    MapPackage package, {
    required LatLng center,
    double radiusKm = 10.5,
  }) async {
    final gridLat = (center.latitude * 20).round();
    final gridLon = (center.longitude * 20).round();
    final cacheKey = '${package.id}:$gridLat:$gridLon:${radiusKm.toStringAsFixed(1)}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final installed = await MapPackageManager.instance.isInstalled(package);
    if (!installed) {
      throw Exception('Mappa ${package.name} non installata.');
    }

    final file = await MapPackageManager.instance.fileFor(package);
    final raw = await file.readAsString();
    final json = jsonDecode(raw);

    if (json is! Map ||
        json['type'] != 'FeatureCollection' ||
        json['features'] is! List) {
      throw Exception('Pacchetto GeoJSON non valido');
    }

    final latPad = radiusKm / 111.0;
    final cosLat = _cosDegrees(center.latitude).abs().clamp(.25, 1.0);
    final lonPad = radiusKm / (111.0 * cosLat);
    final minLat = center.latitude - latPad;
    final maxLat = center.latitude + latPad;
    final minLon = center.longitude - lonPad;
    final maxLon = center.longitude + lonPad;

    final features = json['features'] as List;
    final trails = <TrailSegment>[];
    final pois = <MapPoi>[];
    var generatedId = 1;

    for (final rawFeature in features) {
      if (rawFeature is! Map) continue;

      final properties = rawFeature['properties'] is Map
          ? Map<String, dynamic>.from(rawFeature['properties'] as Map)
          : <String, dynamic>{};

      final geometry = rawFeature['geometry'];
      if (geometry is! Map) continue;

      final geometryType = geometry['type']?.toString();
      final coordinates = geometry['coordinates'];
      if (!_geometryTouchesBox(
        coordinates,
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      )) {
        continue;
      }

      final highway = properties['highway']?.toString();
      if (const {
        'path',
        'footway',
        'track',
        'pedestrian',
        'steps',
      }.contains(highway)) {
        final lines = _lineStringsFromGeometry(geometryType, coordinates);
        for (final line in lines) {
          if (line.length < 2) continue;
          trails.add(
            TrailSegment(
              id: generatedId++,
              points: line,
              tags: properties,
            ),
          );
        }
      }

      final tourism = properties['tourism']?.toString();
      final amenity = properties['amenity']?.toString();
      PoiType? poiType;

      if (tourism == 'alpine_hut' || tourism == 'wilderness_hut') {
        poiType = PoiType.rifugio;
      } else if (tourism == 'viewpoint') {
        poiType = PoiType.panorama;
      } else if (amenity == 'drinking_water') {
        poiType = PoiType.fontana;
      } else if (amenity == 'parking') {
        poiType = PoiType.parcheggio;
      }

      if (poiType == null) continue;
      final point = _representativePoint(geometryType, coordinates);
      if (point == null ||
          point.latitude < minLat ||
          point.latitude > maxLat ||
          point.longitude < minLon ||
          point.longitude > maxLon) {
        continue;
      }

      final fallback = switch (poiType) {
        PoiType.rifugio => 'Rifugio',
        PoiType.panorama => 'Punto panoramico',
        PoiType.fontana => 'Fontana',
        PoiType.parcheggio => 'Parcheggio',
      };
      final name = properties['name']?.toString().trim();

      pois.add(
        MapPoi(
          id: generatedId++,
          type: poiType,
          name: name != null && name.isNotEmpty ? name : fallback,
          point: point,
          tags: properties,
        ),
      );
    }

    final result = OfflineArea(
      name: json['name']?.toString() ?? package.name,
      trails: trails,
      pois: pois,
    );

    // Manteniamo una cache piccola: basta la zona corrente.
    _cache
      ..clear()
      ..[cacheKey] = result;
    return result;
  }

  bool _geometryTouchesBox(
    dynamic coordinates, {
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) {
    if (coordinates is! List || coordinates.isEmpty) return false;

    // Coppia GeoJSON [lon, lat].
    if (coordinates.length >= 2 &&
        coordinates[0] is num &&
        coordinates[1] is num) {
      final lon = (coordinates[0] as num).toDouble();
      final lat = (coordinates[1] as num).toDouble();
      return lat >= minLat &&
          lat <= maxLat &&
          lon >= minLon &&
          lon <= maxLon;
    }

    // Campionamento progressivo per geometrie grandi: evita di visitare ogni
    // vertice di sentieri lontani, ma controlla sempre anche l'ultimo punto.
    final step = (coordinates.length / 10).ceil().clamp(1, 1000000);
    for (var i = 0; i < coordinates.length; i += step) {
      if (_geometryTouchesBox(
        coordinates[i],
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      )) {
        return true;
      }
    }
    return _geometryTouchesBox(
      coordinates.last,
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }

  List<List<LatLng>> _lineStringsFromGeometry(String? type, dynamic coordinates) {
    final result = <List<LatLng>>[];
    if (type == 'LineString') {
      final line = _parseLine(coordinates);
      if (line.isNotEmpty) result.add(line);
    } else if (type == 'MultiLineString' && coordinates is List) {
      for (final rawLine in coordinates) {
        final line = _parseLine(rawLine);
        if (line.isNotEmpty) result.add(line);
      }
    }
    return result;
  }

  List<LatLng> _parseLine(dynamic rawLine) {
    if (rawLine is! List) return const [];
    final points = <LatLng>[];
    for (final rawPoint in rawLine) {
      final p = _coordinatePair(rawPoint);
      if (p != null) points.add(p);
    }
    return points;
  }

  LatLng? _representativePoint(String? type, dynamic coordinates) {
    if (type == 'Point') return _coordinatePair(coordinates);
    if (type == 'MultiPoint' && coordinates is List) {
      for (final p in coordinates) {
        final point = _coordinatePair(p);
        if (point != null) return point;
      }
    }
    if (type == 'LineString' && coordinates is List && coordinates.isNotEmpty) {
      return _coordinatePair(coordinates[coordinates.length ~/ 2]);
    }
    if (type == 'Polygon' && coordinates is List && coordinates.isNotEmpty) {
      final ring = coordinates.first;
      if (ring is List && ring.isNotEmpty) return _averagePoint(ring);
    }
    if (type == 'MultiPolygon' && coordinates is List && coordinates.isNotEmpty) {
      final polygon = coordinates.first;
      if (polygon is List && polygon.isNotEmpty) {
        final ring = polygon.first;
        if (ring is List && ring.isNotEmpty) return _averagePoint(ring);
      }
    }
    return null;
  }

  LatLng? _averagePoint(List<dynamic> rawPoints) {
    var lat = 0.0;
    var lon = 0.0;
    var count = 0;
    for (final raw in rawPoints) {
      final p = _coordinatePair(raw);
      if (p == null) continue;
      lat += p.latitude;
      lon += p.longitude;
      count++;
    }
    if (count == 0) return null;
    return LatLng(lat / count, lon / count);
  }

  LatLng? _coordinatePair(dynamic raw) {
    if (raw is! List || raw.length < 2) return null;
    if (raw[0] is! num || raw[1] is! num) return null;
    return LatLng((raw[1] as num).toDouble(), (raw[0] as num).toDouble());
  }

  double _cosDegrees(double value) {
    final x = value * 0.017453292519943295;
    final x2 = x * x;
    final x4 = x2 * x2;
    final x6 = x4 * x2;
    return 1 - x2 / 2 + x4 / 24 - x6 / 720;
  }

  void clearCache() => _cache.clear();
}
