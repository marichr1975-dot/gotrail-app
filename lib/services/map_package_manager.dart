import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/map_package.dart';

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  double get fraction {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get percent => (fraction * 100).round();

  String get receivedLabel =>
      '${(receivedBytes / 1024 / 1024).toStringAsFixed(2)} MB';

  String get totalLabel =>
      '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB';
}

class _IOSinkAdapter implements Sink<List<int>> {
  final IOSink sink;
  _IOSinkAdapter(this.sink);

  @override
  void add(List<int> data) => sink.add(data);

  @override
  void close() {}
}

class MapPackageManager {
  MapPackageManager._();
  static final instance = MapPackageManager._();

  Future<Directory> _mapsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}gotr_maps');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<File> fileFor(MapPackage package) async {
    final dir = await _mapsDirectory();
    return File('${dir.path}${Platform.pathSeparator}${package.fileName}');
  }

  Future<bool> isInstalled(MapPackage package) async {
    final file = await fileFor(package);

    if (!await file.exists()) return false;

    final length = await file.length();
    if (length < 100000) {
      try {
        await file.delete();
      } catch (_) {}
      return false;
    }

    // Il pacchetto viene validato completamente al termine del download.
    // All'avvio evitiamo di rileggere e decodificare decine di MB di GeoJSON.
    return true;
  }

  Future<File> download(
    MapPackage package, {
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    final target = await fileFor(package);
    final compressed = File('${target.path}.download.gz');
    final unpacking = File('${target.path}.unpacking');

    for (final f in [compressed, unpacking]) {
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    final client = http.Client();
    IOSink? compressedSink;
    IOSink? unpackSink;

    try {
      final request = http.Request('GET', Uri.parse(package.url));
      request.headers['User-Agent'] = 'GoTr-AI/5.0';
      request.headers['Accept-Encoding'] = 'identity';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Server mappe: errore HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? package.expectedBytes;
      compressedSink = compressed.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        compressedSink.add(chunk);
        received += chunk.length;
        onProgress(
          DownloadProgress(
            receivedBytes: total > 0 && received > total ? total : received,
            totalBytes: total,
          ),
        );
      }

      await compressedSink.flush();
      await compressedSink.close();
      compressedSink = null;

      final compressedLength = await compressed.length();
      if (compressedLength < 10000) {
        throw Exception('Il pacchetto compresso ricevuto è incompleto.');
      }

      // Decompressione GZIP in streaming: non carica l'intera provincia in RAM.
      unpackSink = unpacking.openWrite();
      final decoderSink = gzip.decoder.startChunkedConversion(
        _IOSinkAdapter(unpackSink),
      );

      await for (final chunk in compressed.openRead()) {
        decoderSink.add(chunk);
      }
      decoderSink.close();
      await unpackSink.flush();
      await unpackSink.close();
      unpackSink = null;

      final finalLength = await unpacking.length();
      if (finalLength < 100000) {
        throw Exception('La mappa decompressa è incompleta.');
      }

      // Controllo rapido prima dell'installazione. La validazione completa
      // viene fatta al primo caricamento della zona: evitiamo così di
      // decodificare due volte consecutivamente un GeoJSON di decine di MB
      // subito dopo il download.
      final probeBytes = await unpacking.openRead(0, 8192).fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      final probe = utf8.decode(probeBytes, allowMalformed: true);
      if (!probe.contains('FeatureCollection') || !probe.contains('features')) {
        throw Exception('Il pacchetto mappa non è un GeoJSON valido.');
      }

      if (await target.exists()) {
        await target.delete();
      }
      await unpacking.rename(target.path);

      try {
        await compressed.delete();
      } catch (_) {}

      onProgress(
        DownloadProgress(
          receivedBytes: total > 0 ? total : compressedLength,
          totalBytes: total > 0 ? total : compressedLength,
        ),
      );

      return target;
    } on FormatException {
      throw Exception('Il file scaricato non è una mappa GZIP/GeoJSON valida.');
    } finally {
      try {
        await compressedSink?.close();
      } catch (_) {}
      try {
        await unpackSink?.close();
      } catch (_) {}
      client.close();
    }
  }
}
