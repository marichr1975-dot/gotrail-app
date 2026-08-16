
import 'package:flutter/material.dart';

import '../models/map_package.dart';
import '../services/map_package_manager.dart';

class MapDownloadDialog extends StatefulWidget {
  final MapPackage package;

  const MapDownloadDialog({
    super.key,
    required this.package,
  });

  @override
  State<MapDownloadDialog> createState() =>
      _MapDownloadDialogState();
}

class _MapDownloadDialogState
    extends State<MapDownloadDialog> {
  bool _downloading = false;
  bool _completed = false;
  String? _error;
  DownloadProgress _progress = const DownloadProgress(
    receivedBytes: 0,
    totalBytes: 1,
  );

  Future<void> _download() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
      _completed = false;
      _error = null;
      _progress = DownloadProgress(
        receivedBytes: 0,
        totalBytes: widget.package.expectedBytes > 0 ? widget.package.expectedBytes : 1,
      );
    });

    try {
      await MapPackageManager.instance.download(
        widget.package,
        onProgress: (progress) {
          if (!mounted) return;

          setState(() {
            _progress = progress;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _downloading = false;
        _completed = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _downloading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_downloading,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEAF5E7),
              child: Icon(
                Icons.map_rounded,
                color: Color(0xFF2F7A37),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _completed
                    ? 'Mappa pronta'
                    : 'Mappa offline necessaria',
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 330,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.package.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),

              if (!_downloading && !_completed) ...[
                const Text(
                  'Per utilizzare Sentieri è necessario scaricare la mappa della zona che hai scelto.',
                  style: TextStyle(fontSize: 13, height: 1.20),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded, color: Color(0xFF4F9448), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dimensione mappa: ${widget.package.sizeLabel}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Una volta scaricata, la mappa resterà disponibile anche offline.',
                  style: TextStyle(fontSize: 13, height: 1.20),
                ),
              ],

              if (_downloading) ...[
                LinearProgressIndicator(
                  value: _progress.fraction,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '${_progress.percent}%',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2F7A37),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${_progress.receivedLabel} '
                    'di ${_progress.totalLabel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Download mappa offline…',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],

              if (_completed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5E7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2F7A37),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mappa salvata sul telefono. '
                          'Da ora è disponibile anche offline.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
        actions: [
          if (!_downloading && !_completed)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F9448),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _download,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  _error == null
                      ? 'SCARICA MAPPA'
                      : 'RIPROVA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

          if (_completed)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F9448),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.hiking_rounded),
                label: const Text(
                  'APRI SENTIERI',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
