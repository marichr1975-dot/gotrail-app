import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/saved_route.dart';

class SavedRoutesService {
  SavedRoutesService._();
  static final instance = SavedRoutesService._();

  Future<File> _file() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}gotr_routes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}saved_routes.json');
  }

  Future<List<SavedRoute>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return <SavedRoute>[];

    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return <SavedRoute>[];

      final result = <SavedRoute>[];
      for (final item in raw) {
        if (item is Map) {
          final route = SavedRoute.fromJson(Map<String, dynamic>.from(item));
          if (route.id.isNotEmpty && route.points.length >= 2) {
            result.add(route);
          }
        }
      }
      result.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return result;
    } catch (_) {
      return <SavedRoute>[];
    }
  }

  Future<void> save(SavedRoute route) async {
    final routes = await loadAll();
    routes.removeWhere((r) => r.id == route.id);
    routes.insert(0, route);
    await _write(routes);
  }

  Future<void> delete(String id) async {
    final routes = await loadAll();
    routes.removeWhere((r) => r.id == id);
    await _write(routes);
  }

  Future<void> _write(List<SavedRoute> routes) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode([for (final r in routes) r.toJson()]));
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
