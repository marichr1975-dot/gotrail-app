
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';

class LocalRouter {
  static RouteResult route({
    required LatLng start,
    required LatLng destination,
    required OfflineArea area,
  }) {
    final nodes = <String, _Node>{};

    String keyOf(LatLng p) =>
        '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

    _Node nodeFor(LatLng p) {
      final key = keyOf(p);
      return nodes.putIfAbsent(
        key,
        () => _Node(key: key, point: p),
      );
    }

    for (final trail in area.trails) {
      for (var i = 0; i < trail.points.length; i++) {
        final a = nodeFor(trail.points[i]);
        if (i == 0) continue;
        final b = nodeFor(trail.points[i - 1]);

        final d = Geolocator.distanceBetween(
          a.point.latitude,
          a.point.longitude,
          b.point.latitude,
          b.point.longitude,
        );

        if (d > 0 && d < 1000) {
          a.edges.add(_Edge(b.key, d));
          b.edges.add(_Edge(a.key, d));
        }
      }
    }

    final buckets = <String, List<_Node>>{};
    String bucket(LatLng p) =>
        '${(p.latitude * 1700).floor()},${(p.longitude * 1700).floor()}';

    for (final n in nodes.values) {
      buckets.putIfAbsent(bucket(n.point), () => []).add(n);
    }

    for (final n in nodes.values) {
      final y = (n.point.latitude * 1700).floor();
      final x = (n.point.longitude * 1700).floor();

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final list = buckets['${y + dy},${x + dx}'];
          if (list == null) continue;

          for (final other in list) {
            if (other.key == n.key) continue;
            final d = Geolocator.distanceBetween(
              n.point.latitude,
              n.point.longitude,
              other.point.latitude,
              other.point.longitude,
            );
            if (d <= 35) {
              n.edges.add(_Edge(other.key, d));
            }
          }
        }
      }
    }

    List<_Candidate> nearestCandidates(
      LatLng target,
      double maxDistance,
    ) {
      final result = <_Candidate>[];

      for (final n in nodes.values) {
        final d = Geolocator.distanceBetween(
          target.latitude,
          target.longitude,
          n.point.latitude,
          n.point.longitude,
        );
        if (d <= maxDistance) {
          result.add(_Candidate(n.key, d));
        }
      }

      result.sort((a, b) => a.distance.compareTo(b.distance));
      return result.take(12).toList();
    }

    final starts = nearestCandidates(start, 900);
    final ends = nearestCandidates(destination, 800);

    if (starts.isEmpty) {
      return const RouteResult(
        points: [],
        message: 'Nessun sentiero vicino alla posizione GPS.',
      );
    }

    if (ends.isEmpty) {
      return const RouteResult(
        points: [],
        message: 'Nessun sentiero vicino alla destinazione.',
      );
    }

    final endCosts = {for (final e in ends) e.key: e.distance};
    final dist = {for (final k in nodes.keys) k: double.infinity};
    final prev = <String, String>{};
    final open = <_QueueItem>[];

    for (final s in starts) {
      dist[s.key] = s.distance;
      open.add(_QueueItem(s.key, s.distance));
    }

    String? bestEnd;
    var bestTotal = double.infinity;

    while (open.isNotEmpty) {
      open.sort((a, b) => b.distance.compareTo(a.distance));
      final current = open.removeLast();

      if (current.distance > (dist[current.key] ?? double.infinity)) {
        continue;
      }

      final last = endCosts[current.key];
      if (last != null && current.distance + last < bestTotal) {
        bestTotal = current.distance + last;
        bestEnd = current.key;
      }

      if (current.distance >= bestTotal) continue;

      final node = nodes[current.key];
      if (node == null) continue;

      for (final edge in node.edges) {
        final candidate = current.distance + edge.distance;
        if (candidate < (dist[edge.to] ?? double.infinity)) {
          dist[edge.to] = candidate;
          prev[edge.to] = current.key;
          open.add(_QueueItem(edge.to, candidate));
        }
      }
    }

    if (bestEnd == null) {
      return const RouteResult(
        points: [],
        message: 'La rete offline non contiene un collegamento continuo.',
      );
    }

    final keys = <String>[bestEnd];
    var cursor = bestEnd;

    while (prev.containsKey(cursor)) {
      cursor = prev[cursor]!;
      keys.add(cursor);
    }

    return RouteResult(
      points: [
        start,
        ...keys.reversed.map((k) => nodes[k]!.point),
        destination,
      ],
      message: 'Percorso calcolato completamente sul telefono.',
    );
  }
}

class _Node {
  final String key;
  final LatLng point;
  final List<_Edge> edges = [];
  _Node({required this.key, required this.point});
}
class _Edge {
  final String to;
  final double distance;
  const _Edge(this.to, this.distance);
}
class _Candidate {
  final String key;
  final double distance;
  const _Candidate(this.key, this.distance);
}
class _QueueItem {
  final String key;
  final double distance;
  const _QueueItem(this.key, this.distance);
}
