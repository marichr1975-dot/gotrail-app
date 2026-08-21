import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'mwm_release_service.dart';

class MwmMapInfo {
  final File file;
  final String regionLabel;
  final int sizeBytes;
  final bool headerReadable;

  const MwmMapInfo({
    required this.file,
    required this.regionLabel,
    required this.sizeBytes,
    required this.headerReadable,
  });

  String get sizeLabel => '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _Area {
  final String label;
  final String token;
  final double lat;
  final double lon;
  const _Area(this.label, this.token, this.lat, this.lon);
}

class MwmMapService {
  MwmMapService._();
  static final instance = MwmMapService._();

  static const _areas = <_Area>[
    _Area('Belluno', 'belluno', 46.14, 12.22),
    _Area('Treviso', 'treviso', 45.67, 12.24),
    _Area('Venezia', 'venezia', 45.44, 12.33),
    _Area('Vicenza', 'vicenza', 45.55, 11.55),
    _Area('Padova', 'padova', 45.41, 11.88),
    _Area('Verona', 'verona', 45.44, 10.99),
    _Area('Rovigo', 'rovigo', 45.07, 11.79),
    _Area('Udine', 'udine', 46.06, 13.24),
    _Area('Pordenone', 'pordenone', 45.96, 12.66),
    _Area('Gorizia', 'gorizia', 45.94, 13.62),
    _Area('Trieste', 'trieste', 45.65, 13.77),
    _Area('Trento', 'trento', 46.07, 11.12),
    _Area('Bolzano', 'bolzano', 46.50, 11.35),
  ];

  Future<Directory> _mapsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/gotr_maps');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> installedFiles() async {
    final dir = await _mapsDir();
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.mwm')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  _Area? _nearestArea(LatLng p) {
    if (p.latitude < 44.6 ||
        p.latitude > 47.2 ||
        p.longitude < 10.0 ||
        p.longitude > 14.1) {
      return null;
    }
    _Area? best;
    var bestDistance = double.infinity;
    for (final area in _areas) {
      final dLat = p.latitude - area.lat;
      final dLon = (p.longitude - area.lon) *
          math.cos(p.latitude * math.pi / 180.0);
      final d = dLat * dLat + dLon * dLon;
      if (d < bestDistance) {
        bestDistance = d;
        best = area;
      }
    }
    return best;
  }

  Future<MwmMapInfo?> mapForPoint(LatLng point) async {
    final area = _nearestArea(point);
    if (area == null) return null;
    final files = await installedFiles();
    File? selected;
    for (final file in files) {
      final name = file.uri.pathSegments.last.toLowerCase();
      final token = area.token.toLowerCase();
      if (name.contains(token) ||
          (token == 'trentino' &&
              (name.contains('alto adige') ||
               name.contains('sudtirol') ||
               name.contains('südtirol') ||
               name.contains('bolzano') ||
               name.contains('trento')))) {
        selected = file;
        break;
      }
    }
    if (selected == null) return null;
    return _validate(selected, area.label);
  }

  Future<MwmMapInfo?> mapForTextAndPoint(String text, LatLng point) async {
    final q = text.toLowerCase();
    final files = await installedFiles();

    const provinces = <String, String>{
      'belluno': 'Belluno',
      'padova': 'Padova',
      'rovigo': 'Rovigo',
      'treviso': 'Treviso',
      'venezia': 'Venezia',
      'verona': 'Verona',
      'vicenza': 'Vicenza',
      'pordenone': 'Pordenone',
      'udine': 'Udine',
      'gorizia': 'Gorizia',
      'trieste': 'Trieste',
    };

    // Se Gemini ha restituito una provincia, quella è vincolante.
    for (final entry in provinces.entries) {
      if (!q.contains(entry.key)) continue;
      for (final file in files) {
        final n = file.uri.pathSegments.last.toLowerCase();
        if (n.contains(entry.key)) {
          return _validate(file, entry.value);
        }
      }
      // IMPORTANTE: niente fallback a Veneto/Belluno o ad altre mappe.
      return null;
    }

    final asksTrentino = q.contains('trento') ||
        q.contains('bolzano') ||
        q.contains('trentino') ||
        q.contains('alto adige') ||
        q.contains('sudtirol') ||
        q.contains('südtirol');

    if (asksTrentino) {
      for (final file in files) {
        final n = file.uri.pathSegments.last.toLowerCase();
        if (n.contains('trentino') ||
            n.contains('alto adige') ||
            n.contains('sudtirol') ||
            n.contains('südtirol') ||
            n.contains('trento') ||
            n.contains('bolzano')) {
          final label = q.contains('bolzano') ? 'Bolzano' : 'Trentino-Alto Adige';
          return _validate(file, label);
        }
      }
      return null;
    }

    // Solo se il testo non contiene nessuna provincia/area esplicita
    // usiamo le coordinate.
    return mapForPoint(point);
  }


  Future<MwmMapInfo?> ensureForPoint(
    LatLng point, {
    void Function(int received, int total)? onProgress,
  }) async {
    final local = await mapForPoint(point);
    if (local != null) return local;
    final downloaded = await MwmReleaseService.instance.ensureForPoint(
      point,
      onProgress: onProgress,
    );
    if (downloaded == null) return null;
    return mapForPoint(point);
  }

  Future<MwmMapInfo?> ensureForTextAndPoint(
    String text,
    LatLng point, {
    void Function(int received, int total)? onProgress,
  }) async {
    final local = await mapForPoint(point);
    if (local != null) return local;

    final downloaded = await MwmReleaseService.instance.ensureForText(
          text,
          onProgress: onProgress,
        ) ??
        await MwmReleaseService.instance.ensureForPoint(
          point,
          onProgress: onProgress,
        );
    if (downloaded == null) return null;
    return mapForPoint(point);
  }

  Future<MwmMapInfo?> _validate(File selected, String label) async {
    final stat = await selected.stat();
    bool headerReadable = false;
    try {
      final raf = await selected.open();
      final len = stat.size < 64 ? stat.size : 64;
      final Uint8List bytes = await raf.read(len);
      await raf.close();
      headerReadable = bytes.isNotEmpty && bytes.any((b) => b != 0);
    } catch (_) {
      headerReadable = false;
    }
    if (stat.size < 1024 * 1024 || !headerReadable) return null;

    return MwmMapInfo(
      file: selected,
      regionLabel: label,
      sizeBytes: stat.size,
      headerReadable: headerReadable,
    );
  }

  Future<String> installPath() async => (await _mapsDir()).path;
}
