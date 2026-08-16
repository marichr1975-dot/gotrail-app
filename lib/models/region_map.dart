import 'package:latlong2/latlong.dart';

class RegionMap {
  final String id;
  final String name;
  final String region;
  final int version;
  final String url;
  final int expectedBytes;
  final double south;
  final double west;
  final double north;
  final double east;

  const RegionMap({
    required this.id,
    required this.name,
    required this.region,
    required this.version,
    required this.url,
    required this.expectedBytes,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;

  String get fileName => '$id.mbtiles';
  String get versionFileName => '$id.version';

  factory RegionMap.fromJson(Map<String, dynamic> json) {
    final bounds = (json['bounds'] as List).cast<num>();
    return RegionMap(
      id: json['id'].toString(),
      name: json['name'].toString(),
      region: (json['region'] ?? json['name']).toString(),
      version: (json['version'] as num).toInt(),
      url: json['url'].toString(),
      expectedBytes: (json['size'] as num?)?.toInt() ?? 0,
      south: bounds[0].toDouble(),
      west: bounds[1].toDouble(),
      north: bounds[2].toDouble(),
      east: bounds[3].toDouble(),
    );
  }
}
