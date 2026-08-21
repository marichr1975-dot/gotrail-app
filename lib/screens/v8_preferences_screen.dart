import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/gemini_ai_service.dart';
import '../services/gps_service.dart';
import '../services/location_search_service.dart';
import 'ai_suggestion_screen.dart';
import 'ai_creating_screen.dart';

import 'home_screen.dart';
import 'v8_choice_screen.dart';

class V8PreferencesScreen extends StatefulWidget {
  final V8Mode mode;
  final String activity;
  final String? place;
  final LatLng? targetPoint;
  final String? targetLabel;

  const V8PreferencesScreen({
    super.key,
    required this.mode,
    required this.activity,
    this.place,
    this.targetPoint,
    this.targetLabel,
  });

  @override
  State<V8PreferencesScreen> createState() => _V8PreferencesScreenState();
}

class _V8PreferencesScreenState extends State<V8PreferencesScreen> {
  static const _blue = Color(0xFF0B5FD7);
  static const _green = Color(0xFF20A85A);
  static const _orange = Color(0xFFF18C2C);
  static const _ink = Color(0xFF112234);

  bool dog = false;
  bool children = false;
  bool forest = false;
  bool rock = false;
  bool loop = true;
  String difficulty = 'Semplice';
  String distance = '4 km';
  bool _aiWorking = false;

  Future<void> _createWithAi() async {
    if (_aiWorking) return;
    setState(() {
      _aiWorking = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      double? lat;
      double? lon;
      var placeLabel = widget.targetLabel ??
          (widget.mode == V8Mode.plan ? (widget.place ?? 'Località pianificata') : 'Posizione GPS');

      if (widget.targetPoint != null) {
        lat = widget.targetPoint!.latitude;
        lon = widget.targetPoint!.longitude;
      } else if (widget.mode == V8Mode.start) {
        final p = await GpsService.currentPosition();
        lat = p.latitude;
        lon = p.longitude;
      } else if ((widget.place ?? '').trim().isNotEmpty) {
        final found = await LocationSearchService.instance.search(widget.place!.trim());
        if (found == null) {
          throw Exception('Località non trovata. Controlla il nome oppure prova con Internet attivo.');
        }
        lat = found.point.latitude;
        lon = found.point.longitude;
        placeLabel = found.label;
      }

      final suggestionFuture = GeminiAiService.instance.suggest(
        AiTrailRequest(
          activity: widget.activity,
          place: placeLabel,
          latitude: lat,
          longitude: lon,
          distance: distance,
          difficulty: difficulty,
          dog: dog,
          children: children,
          forest: forest,
          rock: rock,
          loop: loop,
        ),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AiCreatingScreen(suggestionFuture: suggestionFuture),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _aiWorking = false);
    }
  }

  void _home() => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);

  Widget _choiceButton({required String label, required bool selected, required VoidCallback onTap, IconData? icon, Color active = _blue}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 43,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: selected ? active : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? active : const Color(0xFFDCE5EC)),
              boxShadow: selected ? [BoxShadow(color: active.withValues(alpha: .20), blurRadius: 9, offset: const Offset(0, 4))] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: selected ? Colors.white : active),
                  const SizedBox(width: 5),
                ],
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : _ink, fontSize: 12.5, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFE8F1FF), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: _blue, size: 17)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _ink)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeLabel = widget.targetLabel ??
        (widget.mode == V8Mode.plan ? (widget.place ?? '') : 'Dalla tua posizione');
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 660;
            final gap = compact ? 8.0 : 10.0;
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(12, compact ? 8 : 11, 14, compact ? 8 : 11),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF073A79), Color(0xFF0B5FD7)]),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
                  ),
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .16),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Indietro',
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ULTIMO PASSO', style: TextStyle(color: Color(0xFF9DD2FF), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                            Text('Come vuoi il percorso?', style: TextStyle(color: Colors.white, fontSize: compact ? 20.5 : 23, height: 1.02, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded, color: Color(0xFFDCEEFF), size: 13),
                                const SizedBox(width: 3),
                                Flexible(child: Text('${widget.activity} · $placeLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFEAF4FF), fontSize: 10.5, fontWeight: FontWeight.w700))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _home,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .16),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.home_rounded),
                        tooltip: 'Home',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(13, compact ? 6 : 9, 13, 6),
                    child: Column(
                      children: [
                        _sectionTitle(Icons.route_rounded, 'Distanza'),
                        SizedBox(height: compact ? 5 : 7),
                        Row(
                          children: [
                            _choiceButton(label: '2 km', selected: distance == '2 km', onTap: () => setState(() => distance = '2 km'), active: _green),
                            const SizedBox(width: 7),
                            _choiceButton(label: '4 km', selected: distance == '4 km', onTap: () => setState(() => distance = '4 km'), active: _blue),
                            const SizedBox(width: 7),
                            _choiceButton(label: '6 km', selected: distance == '6 km', onTap: () => setState(() => distance = '6 km'), active: _orange),
                          ],
                        ),
                        SizedBox(height: gap),
                        _sectionTitle(Icons.trending_up_rounded, 'Difficoltà'),
                        SizedBox(height: compact ? 5 : 7),
                        Row(
                          children: [
                            _choiceButton(label: 'Semplice', selected: difficulty == 'Semplice', onTap: () => setState(() => difficulty = 'Semplice'), active: _green),
                            const SizedBox(width: 7),
                            _choiceButton(label: 'Media', selected: difficulty == 'Media', onTap: () => setState(() => difficulty = 'Media'), active: _blue),
                            const SizedBox(width: 7),
                            _choiceButton(label: 'Esperta', selected: difficulty == 'Esperta', onTap: () => setState(() => difficulty = 'Esperta'), active: const Color(0xFFD94A46)),
                          ],
                        ),
                        SizedBox(height: gap),
                        _sectionTitle(Icons.group_rounded, 'Con chi vai?'),
                        SizedBox(height: compact ? 5 : 7),
                        Row(
                          children: [
                            _choiceButton(icon: Icons.pets_rounded, label: 'Cane', selected: dog, onTap: () => setState(() => dog = !dog), active: _green),
                            const SizedBox(width: 7),
                            _choiceButton(icon: Icons.family_restroom_rounded, label: 'Bambini', selected: children, onTap: () => setState(() => children = !children), active: _blue),
                          ],
                        ),
                        SizedBox(height: gap),
                        _sectionTitle(Icons.terrain_rounded, 'Preferenze'),
                        SizedBox(height: compact ? 5 : 7),
                        Row(
                          children: [
                            _choiceButton(icon: Icons.forest_rounded, label: 'Bosco', selected: forest, onTap: () => setState(() => forest = !forest), active: _green),
                            const SizedBox(width: 7),
                            _choiceButton(icon: Icons.landscape_rounded, label: 'Roccia', selected: rock, onTap: () => setState(() => rock = !rock), active: _orange),
                          ],
                        ),
                        SizedBox(height: gap),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => loop = !loop),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              height: compact ? 49 : 54,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: loop ? const Color(0xFFE9F7EF) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: loop ? _green : const Color(0xFFDCE5EC), width: loop ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 34, height: 34, decoration: BoxDecoration(color: loop ? _green : const Color(0xFFEFF3F6), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.loop_rounded, color: loop ? Colors.white : _green, size: 20)),
                                  const SizedBox(width: 9),
                                  const Expanded(child: Text('Percorso ad anello', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _ink))),
                                  Switch(value: loop, onChanged: (v) => setState(() => loop = v), activeThumbColor: Colors.white, activeTrackColor: _green),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 6),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(13, 4, 13, compact ? 9 : 13),
                  child: SizedBox(
                    width: double.infinity,
                    height: compact ? 51 : 57,
                    child: FilledButton.icon(
                      onPressed: _aiWorking ? null : _createWithAi,
                      icon: _aiWorking
                          ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 21),
                      label: Text(_aiWorking ? 'GEMINI STA CREANDO…' : 'CREA CON AI', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .35)),
                      style: FilledButton.styleFrom(backgroundColor: _green, disabledBackgroundColor: _green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class _AiCreatingScreen extends StatefulWidget {
  final Future<AiTrailSuggestion> suggestionFuture;

  const _AiCreatingScreen({required this.suggestionFuture});

  @override
  State<_AiCreatingScreen> createState() => _AiCreatingScreenState();
}

class _AiCreatingScreenState extends State<_AiCreatingScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF0B5FD7);
  static const _green = Color(0xFF20A85A);
  static const _ink = Color(0xFF112234);

  late final AnimationController _walkController;
  AiTrailSuggestion? _suggestion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.suggestionFuture;
      if (!mounted) return;
      _walkController.stop();
      setState(() => _suggestion = result);
    } catch (e) {
      if (!mounted) return;
      _walkController.stop();
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _walkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _suggestion != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Creo il percorso',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (!ready && _error == null)
                      SizedBox(
                        height: 105,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedBuilder(
                              animation: _walkController,
                              builder: (context, child) {
                                final x = -38 +
                                    (constraints.maxWidth + 76) *
                                        _walkController.value;
                                return Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 17,
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCE5EC),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: x,
                                      bottom: 20,
                                      child: const Icon(
                                        Icons.hiking_rounded,
                                        size: 56,
                                        color: _green,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      )
                    else if (ready)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 82,
                        color: _green,
                      )
                    else
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 76,
                        color: Colors.redAccent,
                      ),
                    const SizedBox(height: 18),
                    Text(
                      _error != null
                          ? 'Non sono riuscito a creare il percorso'
                          : ready
                              ? 'Percorso creato!'
                              : 'Sto creando il tuo percorso…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _error ??
                          (ready
                              ? 'La proposta è pronta.'
                              : 'GoTr-AI sta preparando la proposta più adatta alle tue scelte.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF627383),
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: ready
                      ? () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => AiSuggestionScreen(
                                suggestion: _suggestion!,
                              ),
                            ),
                          );
                        }
                      : _error != null
                          ? () => Navigator.of(context).pop()
                          : null,
                  icon: Icon(
                    ready
                        ? Icons.map_rounded
                        : _error != null
                            ? Icons.arrow_back_rounded
                            : Icons.hourglass_top_rounded,
                  ),
                  label: Text(
                    ready
                        ? 'VISUALIZZA PERCORSO'
                        : _error != null
                            ? 'TORNA INDIETRO'
                            : 'ATTENDI…',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    disabledBackgroundColor: const Color(0xFFDCE5EC),
                    disabledForegroundColor: const Color(0xFF7A8995),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

