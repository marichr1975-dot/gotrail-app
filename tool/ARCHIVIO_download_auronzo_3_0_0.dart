
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const servers = [
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass-api.de/api/interpreter',
];

const tiles = [
  [46.40, 12.20, 46.58, 12.48],
  [46.40, 12.48, 46.58, 12.75],
  [46.58, 12.20, 46.75, 12.48],
  [46.58, 12.48, 46.75, 12.75],
];

Future<Map<String, dynamic>> queryTile(List<double> b) async {
  final south = b[0];
  final west = b[1];
  final north = b[2];
  final east = b[3];

  final query = '''
[out:json][timeout:60];
(
  way($south,$west,$north,$east)["highway"="path"]["foot"!="no"];
  way($south,$west,$north,$east)["highway"="footway"]["foot"!="no"];
  way($south,$west,$north,$east)["highway"="track"]["foot"!="no"];
  way($south,$west,$north,$east)["highway"="pedestrian"]["foot"!="no"];
  way($south,$west,$north,$east)["highway"="steps"]["foot"!="no"];
  nwr($south,$west,$north,$east)["tourism"="alpine_hut"];
  nwr($south,$west,$north,$east)["tourism"="wilderness_hut"];
  nwr($south,$west,$north,$east)["tourism"="viewpoint"];
  nwr($south,$west,$north,$east)["amenity"="drinking_water"];
  nwr($south,$west,$north,$east)["amenity"="parking"];
);
out geom center tags;
''';

  Object? lastError;

  for (final server in servers) {
    try {
      stdout.writeln('  server: $server');
      final response = await http
          .post(
            Uri.parse(server),
            headers: const {
              'User-Agent': 'GoTr-AI-3.0-offline-builder',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        lastError = 'HTTP ${response.statusCode}';
        continue;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);

      lastError = 'JSON non valido';
    } catch (e) {
      lastError = e;
    }
  }

  throw Exception('Tile non scaricata: $lastError');
}

Future<void> main() async {
  stdout.writeln('GoTr-AI 3.0 - preparo pacchetto offline Auronzo');
  stdout.writeln('Questo download si fa sul PC UNA VOLTA prima dell APK.');

  final merged = <String, Map<String, dynamic>>{};

  for (var i = 0; i < tiles.length; i++) {
    stdout.writeln('Scarico zona ${i + 1}/${tiles.length}...');
    final data = await queryTile(tiles[i]);
    final elements = data['elements'];

    if (elements is! List) continue;

    for (final raw in elements) {
      if (raw is! Map) continue;
      final type = raw['type']?.toString() ?? '';
      final id = raw['id']?.toString() ?? '';
      if (type.isEmpty || id.isEmpty) continue;

      merged['$type:$id'] = Map<String, dynamic>.from(raw);
    }

    stdout.writeln('  elementi unici finora: ${merged.length}');
  }

  final output = {
    'gotr_pack': 1,
    'name': 'Auronzo - Misurina offline',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'bbox': [46.40, 12.20, 46.75, 12.75],
    'elements': merged.values.toList(),
  };

  final file = File('assets/offline/auronzo_osm.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(output), flush: true);

  final mb = await file.length() / 1024 / 1024;

  stdout.writeln('');
  stdout.writeln('PACCHETTO CREATO');
  stdout.writeln('File: ${file.path}');
  stdout.writeln('Dimensione: ${mb.toStringAsFixed(2)} MB');
  stdout.writeln('Elementi: ${merged.length}');
  stdout.writeln('');
  stdout.writeln('Ora puoi fare: flutter run');
}
