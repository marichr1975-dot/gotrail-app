import 'package:latlong2/latlong.dart';

class MapPackage {
  final String id;
  final String name;
  final String areaLabel;
  final String url;
  final int expectedBytes;
  final double south;
  final double west;
  final double north;
  final double east;

  const MapPackage({
    required this.id,
    required this.name,
    required this.areaLabel,
    required this.url,
    required this.expectedBytes,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  LatLng get center =>
      LatLng((south + north) / 2, (west + east) / 2);

  String get fileName => '$id.geojson';

  String get sizeLabel => expectedBytes > 0
      ? '${(expectedBytes / 1024 / 1024).toStringAsFixed(2)} MB'
      : 'calcolata al download';
}

class MapCatalog {
  MapCatalog._();

  static const String _base =
      'https://raw.githubusercontent.com/marichr1975-dot/gotr-maps/refs/heads/main';

  // Le dimensioni vengono rilevate dal server al momento del download.
  // I riquadri servono alla selezione automatica in base al GPS.
  static const List<MapPackage> packages = [
    MapPackage(id:'belluno_provincia', name:'Provincia di Belluno', areaLabel:'Belluno', url:'$_base/belluno_provincia_gotr.json.gz', expectedBytes:0, south:45.86, west:10.38, north:46.68, east:12.79),
    MapPackage(id:'padova_provincia', name:'Provincia di Padova', areaLabel:'Padova', url:'$_base/padova_provincia_gotr.json.gz', expectedBytes:0, south:45.12, west:11.39, north:45.66, east:12.12),
    MapPackage(id:'rovigo_provincia', name:'Provincia di Rovigo', areaLabel:'Rovigo', url:'$_base/rovigo_provincia_gotr.json.gz', expectedBytes:0, south:44.77, west:11.13, north:45.18, east:12.57),
    MapPackage(id:'treviso_provincia', name:'Provincia di Treviso', areaLabel:'Treviso', url:'$_base/treviso_provincia_gotr.json.gz', expectedBytes:0, south:45.52, west:11.96, north:46.09, east:12.70),
    MapPackage(id:'venezia', name:'Provincia di Venezia', areaLabel:'Venezia', url:'$_base/venezia_gotr.json.gz', expectedBytes:0, south:45.08, west:11.68, north:45.78, east:13.10),
    MapPackage(id:'verona_provincia', name:'Provincia di Verona', areaLabel:'Verona', url:'$_base/verona_provincia_gotr.json.gz', expectedBytes:0, south:45.10, west:10.62, north:45.82, east:11.50),
    MapPackage(id:'vicenza_provincia', name:'Provincia di Vicenza', areaLabel:'Vicenza', url:'$_base/vicenza_provincia_gotr.json.gz', expectedBytes:0, south:45.24, west:11.16, north:46.02, east:11.88),
    MapPackage(id:'trento_provincia', name:'Provincia di Trento', areaLabel:'Trento', url:'$_base/trento_provincia_gotr.json.gz', expectedBytes:0, south:45.67, west:10.40, north:46.54, east:11.96),
    MapPackage(id:'bolzano_provincia', name:'Provincia di Bolzano', areaLabel:'Bolzano', url:'$_base/bolzano_provincia_gotr.json.gz', expectedBytes:0, south:46.22, west:10.37, north:47.10, east:12.52),
    MapPackage(id:'pordenone_provincia', name:'Provincia di Pordenone', areaLabel:'Pordenone', url:'$_base/pordenone_provincia_gotr.json.gz', expectedBytes:0, south:45.78, west:12.32, north:46.48, east:13.10),
    MapPackage(id:'udine_provincia', name:'Provincia di Udine', areaLabel:'Udine', url:'$_base/udine_provincia_gotr.json.gz', expectedBytes:0, south:45.75, west:12.68, north:46.65, east:13.72),
    MapPackage(id:'gorizia_provincia', name:'Provincia di Gorizia', areaLabel:'Gorizia', url:'$_base/gorizia_provincia_gotr.json.gz', expectedBytes:0, south:45.62, west:13.31, north:46.06, east:13.76),
    MapPackage(id:'trieste_provincia', name:'Provincia di Trieste', areaLabel:'Trieste', url:'$_base/trieste_provincia_gotr.json.gz', expectedBytes:0, south:45.54, west:13.55, north:45.82, east:13.92),
  ];

  static MapPackage? packageFor(LatLng position) {
    for (final package in packages) {
      if (package.contains(position)) return package;
    }
    return null;
  }
}
