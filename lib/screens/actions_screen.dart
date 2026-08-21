
import 'package:flutter/material.dart';

import '../models/map_package.dart';
import '../services/gps_service.dart';
import '../services/map_package_manager.dart';
import 'map_download_dialog.dart';
import 'map_screen.dart';

class ActionsScreen extends StatefulWidget {
  const ActionsScreen({super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  bool _working = false;

  Future<void> _openTrails() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      final position = await GpsService.currentPosition();

      if (!mounted) return;

      MapPackage? package = MapCatalog.packageFor(position);

      if (package == null) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(
              'Zona non disponibile',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: const Text(
              'Per questa zona non è ancora disponibile una mappa GoTr.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;

      final installed =
          await MapPackageManager.instance.isInstalled(package);

      if (!mounted) return;

      if (!installed) {
        final completed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => MapDownloadDialog(
            package: package,
          ),
        );

        if (completed != true || !mounted) return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapScreen(
            package: package,
            initialPosition: position,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('GPS non disponibile'),
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        title: const Text(
          'Cosa vuoi fare?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
        child: Column(
          children: [
            _ActionCard(
              icon: Icons.hiking_rounded,
              title: 'Sentieri',
              subtitle:
                  'Apri la mappa escursionistica della zona',
              color: const Color(0xFF4F9448),
              enabled: !_working,
              onTap: _openTrails,
              trailing: _working
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(
                      Icons.chevron_right_rounded,
                      size: 34,
                    ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget trailing;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .58,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 132,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 42,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
