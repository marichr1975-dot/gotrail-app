import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/region_map.dart';
import 'map_manifest_service.dart';
import 'map_storage_service.dart';

class ResolvedMap {
  final RegionMap map;
  final File file;
  const ResolvedMap(this.map, this.file);
}

class MapManager {
  MapManager._();
  static final instance = MapManager._();

  Future<RegionMap?> mapForPoint(LatLng point) async {
    final maps = await MapManifestService.instance.load();
    for (final map in maps) {
      if (map.contains(point)) return map;
    }
    return null;
  }

  Future<ResolvedMap> ensureMapForPoint(
    LatLng point, {
    void Function(MapDownloadProgress progress)? onProgress,
  }) async {
    final map = await mapForPoint(point);
    if (map == null) {
      throw Exception('Nessuna mappa disponibile per questa zona.');
    }

    // 8.8: se la MBTiles è già presente localmente, usala SEMPRE.
    // Questo permette anche le mappe copiate manualmente via ADB/PowerShell
    // e impedisce di riscaricare Veneto quando veneto.mbtiles è già installata.
    if (await MapStorageService.instance.isInstalled(map)) {
      return ResolvedMap(map, await MapStorageService.instance.fileFor(map));
    }

    final file = await MapStorageService.instance.ensureInstalled(
      map,
      onProgress: onProgress,
    );
    return ResolvedMap(map, file);
  }

  Future<void> checkUpdatesInBackground() async {
    try {
      final maps = await MapManifestService.instance.load(forceRefresh: true);
      for (final map in maps) {
        if (await MapStorageService.instance.isInstalled(map) &&
            await MapStorageService.instance.needsUpdate(map)) {
          // Download senza bloccare l'utente. La vecchia mappa resta valida
          // finché la nuova non è stata scaricata e verificata.
          await MapStorageService.instance.ensureInstalled(map);
        }
      }
    } catch (_) {
      // In assenza rete o server non disponibile l'app continua con le mappe locali.
    }
  }
}
