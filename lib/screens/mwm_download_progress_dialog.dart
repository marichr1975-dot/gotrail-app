import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/mwm_map_service.dart';

class MwmDownloadProgressDialog {
  static Future<MwmMapInfo?> ensureForPoint(
    BuildContext context,
    LatLng point,
  ) async {
    final local = await MwmMapService.instance.mapForPoint(point);
    if (local != null) return local;
    return _run(
      context,
      (onProgress) => MwmMapService.instance.ensureForPoint(
        point,
        onProgress: onProgress,
      ),
    );
  }

  static Future<MwmMapInfo?> ensureForTextAndPoint(
    BuildContext context,
    String text,
    LatLng point,
  ) async {
    final local = await MwmMapService.instance.mapForPoint(point);
    if (local != null) return local;
    return _run(
      context,
      (onProgress) => MwmMapService.instance.ensureForTextAndPoint(
        text,
        point,
        onProgress: onProgress,
      ),
    );
  }

  static Future<MwmMapInfo?> _run(
    BuildContext context,
    Future<MwmMapInfo?> Function(
      void Function(int received, int total) onProgress,
    ) action,
  ) async {
    final received = ValueNotifier<int>(0);
    final total = ValueNotifier<int>(1);
    String? error;
    MwmMapInfo? result;

    if (!context.mounted) return null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFEAF5E7),
                child: Icon(Icons.download_rounded, color: Color(0xFF2F7A37)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Scarico la mappa',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: ValueListenableBuilder<int>(
              valueListenable: received,
              builder: (context, r, _) => ValueListenableBuilder<int>(
                valueListenable: total,
                builder: (context, t, __) {
                  final safeTotal = t <= 0 ? 1 : t;
                  final fraction = (r / safeTotal).clamp(0.0, 1.0);
                  final pct = (fraction * 100).round();
                  final rMb = (r / 1024 / 1024).toStringAsFixed(1);
                  final tMb = (safeTotal / 1024 / 1024).toStringAsFixed(1);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'La mappa della zona non è ancora sul telefono.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: t > 1 ? fraction : null,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t > 1 ? '$pct%' : 'Connessione al server…',
                        style: const TextStyle(
                          color: Color(0xFF2F7A37),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        t > 1 ? '$rMb MB di $tMb MB' : '$rMb MB scaricati',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Al termine resterà disponibile anche offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    try {
      result = await action((r, t) {
        received.value = r;
        if (t > 0) total.value = t;
      });
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    received.dispose();
    total.dispose();

    if (error != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'Download non riuscito',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(error!),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return result;
  }
}
