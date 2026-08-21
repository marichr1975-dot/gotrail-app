import 'package:flutter/material.dart';

import '../services/region_map_manager_service.dart';

class MapManagerScreen extends StatefulWidget {
  final bool firstUse;
  const MapManagerScreen({super.key, this.firstUse = false});

  @override
  State<MapManagerScreen> createState() => _MapManagerScreenState();
}

class _MapManagerScreenState extends State<MapManagerScreen> {
  static const _regions = ['veneto', 'trentino', 'friuli'];

  final Map<String, RegionMapStatus?> _status = {};
  String? _busyRegion;
  String _busyFile = '';
  int _received = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      for (final id in _regions) {
        final status = await RegionMapManagerService.instance.status(id);
        if (!mounted) return;
        setState(() => _status[id] = status);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _download(String id) async {
    if (_busyRegion != null) return;
    setState(() {
      _busyRegion = id;
      _busyFile = '';
      _received = 0;
      _total = 0;
      _error = null;
    });

    try {
      await RegionMapManagerService.instance.downloadRegion(
        id,
        onProgress: (name, received, total) {
          if (!mounted) return;
          setState(() {
            _busyFile = name;
            _received = received;
            _total = total;
          });
        },
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _busyRegion = null;
          _busyFile = '';
          _received = 0;
          _total = 0;
        });
      }
    }
  }

  Future<void> _delete(String id) async {
    if (_busyRegion != null) return;
    final label = RegionMapManagerService.regionLabels[id] ?? id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la mappa?'),
        content: Text(
          'Vuoi cancellare dal telefono le mappe di $label?\n\n'
          'Potrai riscaricarle in qualsiasi momento.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULLA')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINA')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyRegion = id);
    try {
      await RegionMapManagerService.instance.deleteRegion(id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyRegion = null);
    }
  }

  String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(0)} MB';

  @override
  Widget build(BuildContext context) {
    final anyLoaded = _status.values.any((s) => s != null && s!.installedCount > 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappe offline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        automaticallyImplyLeading: !widget.firstUse || anyLoaded,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 14),
          children: [
            const Text(
              'Scegli le mappe che vuoi avere sul telefono per poter usare l’applicazione anche senza aver accesso a Internet. Per l’intelligenza artificiale serve sempre Internet.',
              style: TextStyle(
                height: 1.22,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 4),
            ..._regions.map(_regionCard),
            if (widget.firstUse && anyLoaded) ...[
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: _busyRegion == null ? () => Navigator.pop(context, true) : null,
                icon: const Icon(Icons.check_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('CONTINUA', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _regionCard(String id) {
    final s = _status[id];
    final busy = _busyRegion == id;
    final loadingStatus = s == null;

    String subtitle;
    if (loadingStatus) {
      subtitle = 'Controllo disponibilità…';
    } else if (s.assets.isEmpty) {
      subtitle = 'Nessuna mappa trovata sul server';
    } else if (s.installed) {
      subtitle = 'Installata · ${s.installedCount} file · ${_mb(s.installedBytes)}';
    } else if (s.partiallyInstalled) {
      subtitle = 'Parziale · ${s.installedCount}/${s.assets.length} file installati';
    } else {
      subtitle = '${s.assets.length} file disponibili · circa ${_mb(s.totalBytes)}';
    }

    final fraction = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(0xFFE9F3FF),
                  child: Icon(Icons.map_rounded, color: Color(0xFF0B5FD7), size: 12),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        RegionMapManagerService.regionLabels[id] ?? id,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 1),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.1)),
                    ],
                  ),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 4),
              Text(
                _busyFile.isEmpty
                    ? 'Preparazione…'
                    : '${_busyFile.split('/').last}  ${_total > 0 ? '${(100 * _received / _total).round()}%' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (!loadingStatus && !s.installed)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busyRegion == null && s.assets.isNotEmpty ? () => _download(id) : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: const Text('SCARICA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (!loadingStatus && s.installed) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busyRegion == null ? () => _delete(id) : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 15),
                      label: const Text('ELIMINA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
