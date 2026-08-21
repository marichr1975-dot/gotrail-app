import 'package:flutter/material.dart';

import '../services/gemini_ai_service.dart';
import '../widgets/ai_hiker_animation.dart';
import 'ai_suggestion_screen.dart';

class AiCreatingScreen extends StatefulWidget {
  final Future<AiTrailSuggestion> suggestionFuture;

  const AiCreatingScreen({
    super.key,
    required this.suggestionFuture,
  });

  @override
  State<AiCreatingScreen> createState() => _AiCreatingScreenState();
}

class _AiCreatingScreenState extends State<AiCreatingScreen>
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
      duration: const Duration(milliseconds: 2200),
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
                      AiHikerAnimation(animation: _walkController)
                    else if (ready)
                      Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE9F7EF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 58,
                          color: _green,
                        ),
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
                              : 'Analizzo distanza, difficoltà e preferenze per preparare la proposta più adatta.'),
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
