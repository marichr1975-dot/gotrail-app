
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum PoiType { rifugio, panorama, fontana, parcheggio }

class TrailSegment {
  final int id;
  final List<LatLng> points;
  final Map<String, dynamic> tags;

  const TrailSegment({
    required this.id,
    required this.points,
    required this.tags,
  });

  String? get ref => tags['ref']?.toString();
  String? get name => tags['name']?.toString();

  Color get color {
    final sac = tags['sac_scale']?.toString();

    switch (sac) {
      case 'hiking':
        return const Color(0xFF2E7D32);
      case 'mountain_hiking':
        return const Color(0xFFF57C00);
      case 'demanding_mountain_hiking':
        return const Color(0xFFD32F2F);
      case 'alpine_hiking':
      case 'demanding_alpine_hiking':
      case 'difficult_alpine_hiking':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF455A64);
    }
  }
}

class MapPoi {
  final int id;
  final PoiType type;
  final String name;
  final LatLng point;
  final Map<String, dynamic> tags;

  const MapPoi({
    required this.id,
    required this.type,
    required this.name,
    required this.point,
    required this.tags,
  });
}

class OfflineArea {
  final String name;
  final List<TrailSegment> trails;
  final List<MapPoi> pois;

  const OfflineArea({
    required this.name,
    required this.trails,
    required this.pois,
  });

  int count(PoiType type) => pois.where((p) => p.type == type).length;
}

class RouteResult {
  final List<LatLng> points;
  final String message;

  const RouteResult({
    required this.points,
    required this.message,
  });

  bool get found => points.length >= 2;
}
