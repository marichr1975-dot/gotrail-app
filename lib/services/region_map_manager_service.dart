import 'dart:io';

import 'mwm_release_service.dart';
import 'package:latlong2/latlong.dart';

class RegionMapStatus {
  final String id;
  final String label;
  final List<MwmReleaseAsset> assets;
  final int installedCount;
  final int installedBytes;

  const RegionMapStatus({
    required this.id,
    required this.label,
    required this.assets,
    required this.installedCount,
    required this.installedBytes,
  });

  bool get installed => assets.isNotEmpty && installedCount == assets.length;
  bool get partiallyInstalled => installedCount > 0 && !installed;
  int get totalBytes => assets.fold(0, (sum, a) => sum + a.size);
}

class RegionMapManagerService {
  RegionMapManagerService._();
  static final instance = RegionMapManagerService._();

  static const regionLabels = <String, String>{
    'veneto': 'Veneto',
    'trentino': 'Trentino-Alto Adige / Südtirol',
    'friuli': 'Friuli-Venezia Giulia',
  };

  bool _assetBelongsToRegion(String regionId, String assetName) {
    final n = MwmReleaseService.normalizeForMatching(assetName);

    // Prima riconosciamo la REGIONE dal nome completo del file.
    // È fondamentale farlo prima delle province: "Friuli-Venezia Giulia"
    // contiene la parola "Venezia", che prima faceva finire Udine nel Veneto.
    if (n.contains('friuli venezia giulia')) {
      return regionId == 'friuli';
    }

    if (n.contains('trentino alto adige') ||
        n.contains('sudtirol') ||
        n.contains('südtirol')) {
      return regionId == 'trentino';
    }

    if (n.contains('italy veneto') || n.contains(' veneto ')) {
      return regionId == 'veneto';
    }

    // Fallback solo per eventuali asset provinciali senza nome regione.
    if (regionId == 'veneto') {
      return const [
        'belluno','padova','rovigo','treviso','venezia','verona','vicenza'
      ].any((x) => n == x || n.endsWith(' $x'));
    }

    if (regionId == 'friuli') {
      return const [
        'pordenone','udine','gorizia','trieste'
      ].any((x) => n == x || n.endsWith(' $x'));
    }

    if (regionId == 'trentino') {
      return const [
        'trento','bolzano'
      ].any((x) => n == x || n.endsWith(' $x'));
    }

    return false;
  }

  String? regionIdForPoint(LatLng point) {
    // Classificazione pratica per le tre regioni pilota.
    // Prima separiamo nettamente Friuli e Trentino; il resto dell'area pilota
    // viene considerato Veneto.
    final lat = point.latitude;
    final lon = point.longitude;

    if (lat < 44.6 || lat > 47.3 || lon < 9.9 || lon > 14.3) {
      return null;
    }

    // Friuli-Venezia Giulia: ad est del Cadore/Veneto.
    if (lon >= 12.55 && lat >= 45.55) {
      return 'friuli';
    }

    // Trentino-Alto Adige / Südtirol: fascia occidentale/nord-occidentale.
    if (lon < 12.05 && lat >= 45.65) {
      return 'trentino';
    }

    return 'veneto';
  }

  Future<bool> isRegionFullyInstalled(String regionId) async {
    final s = await status(regionId);
    return s.installed;
  }

  Future<List<MwmReleaseAsset>> assetsForRegion(String regionId) async {
    final all = await MwmReleaseService.instance.catalog(forceRefresh: true);
    return all.where((a) => _assetBelongsToRegion(regionId, a.name)).toList();
  }

  Future<RegionMapStatus> status(String regionId) async {
    final assets = await assetsForRegion(regionId);
    var count = 0;
    var bytes = 0;

    for (final asset in assets) {
      if (await MwmReleaseService.instance.isInstalled(asset)) {
        count++;
        final dir = await MwmReleaseService.instance.mapsDirectory();
        final file = File('${dir.path}${Platform.pathSeparator}${asset.name}');
        if (await file.exists()) bytes += await file.length();
      }
    }

    return RegionMapStatus(
      id: regionId,
      label: regionLabels[regionId] ?? regionId,
      assets: assets,
      installedCount: count,
      installedBytes: bytes,
    );
  }

  Future<bool> hasAnyInstalledMap() async {
    final dir = await MwmReleaseService.instance.mapsDirectory();
    if (!await dir.exists()) return false;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.mwm') &&
          await entity.length() > 100000) {
        return true;
      }
    }
    return false;
  }

  Future<void> downloadRegion(
    String regionId, {
    void Function(String assetName, int received, int total)? onProgress,
  }) async {
    final assets = await assetsForRegion(regionId);
    if (assets.isEmpty) {
      throw Exception('Nessuna mappa disponibile sul server per questa regione.');
    }

    for (final asset in assets) {
      if (await MwmReleaseService.instance.isInstalled(asset)) continue;
      await MwmReleaseService.instance.download(
        asset,
        onProgress: (r, t) => onProgress?.call(asset.name, r, t),
      );
    }
  }

  Future<void> deleteRegion(String regionId) async {
    final assets = await assetsForRegion(regionId);
    final dir = await MwmReleaseService.instance.mapsDirectory();

    for (final asset in assets) {
      final file = File('${dir.path}${Platform.pathSeparator}${asset.name}');
      if (await file.exists()) {
        await file.delete();
      }
      final temp = File('${file.path}.download');
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }
}
