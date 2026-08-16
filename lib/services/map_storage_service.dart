import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/region_map.dart';

class MapDownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  const MapDownloadProgress(this.receivedBytes, this.totalBytes);

  double? get fraction => totalBytes > 0 ? receivedBytes / totalBytes : null;
}

class MapStorageService {
  MapStorageService._();
  static final instance = MapStorageService._();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}gotr_maps');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(RegionMap map) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}${map.fileName}');
  }

  Future<File> _versionFileFor(RegionMap map) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}${map.versionFileName}');
  }

  Future<int> installedVersion(RegionMap map) async {
    final vf = await _versionFileFor(map);
    if (!await vf.exists()) {
      // Migrazione dalle versioni 6.4/6.5: la MBTiles poteva essere gia
      // presente senza il piccolo file .version. Se il file mappa e valido,
      // consideriamolo alla versione corrente e creiamo il marker, evitando
      // di riscaricare centinaia di MB quando si passa da PIANIFICA a INIZIA.
      final mapFile = await fileFor(map);
      if (await mapFile.exists() && await mapFile.length() >= 1024 * 1024) {
        try {
          await vf.writeAsString(map.version.toString(), flush: true);
        } catch (_) {}
        return map.version;
      }
      return 0;
    }
    return int.tryParse((await vf.readAsString()).trim()) ?? 0;
  }

  Future<bool> isInstalled(RegionMap map) async {
    final file = await fileFor(map);
    if (!await file.exists()) return false;
    final len = await file.length();
    if (len < 1024 * 1024) return false;
    return true;
  }

  Future<bool> needsUpdate(RegionMap map) async {
    if (!await isInstalled(map)) return true;
    return await installedVersion(map) < map.version;
  }

  Future<File> ensureInstalled(
    RegionMap map, {
    void Function(MapDownloadProgress progress)? onProgress,
    bool forceUpdate = false,
  }) async {
    if (!forceUpdate && !await needsUpdate(map)) {
      return fileFor(map);
    }

    final target = await fileFor(map);
    final tmp = File('${target.path}.download');
    final versionFile = await _versionFileFor(map);

    if (await tmp.exists()) await tmp.delete();

    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(map.url));
      request.headers['User-Agent'] = 'GoTr-AI/6.5';
      request.followRedirects = true;
      request.maxRedirects = 10;

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Download ${map.name}: HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? map.expectedBytes;
      var received = 0;
      sink = tmp.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(MapDownloadProgress(received, total));
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final size = await tmp.length();
      if (size < 1024 * 1024) {
        throw Exception('Mappa ${map.name} incompleta');
      }
      if (map.expectedBytes > 0 && size < map.expectedBytes * 0.95) {
        throw Exception('Mappa ${map.name} incompleta');
      }

      // La vecchia mappa viene eliminata solo dopo aver verificato la nuova.
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
      await versionFile.writeAsString(map.version.toString(), flush: true);
      return target;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close();
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteMap(RegionMap map) async {
    final f = await fileFor(map);
    final vf = await _versionFileFor(map);
    if (await f.exists()) await f.delete();
    if (await vf.exists()) await vf.delete();
  }
}
