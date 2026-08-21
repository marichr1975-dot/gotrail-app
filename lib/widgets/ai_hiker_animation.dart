import 'package:flutter/material.dart';

class AiHikerAnimation extends StatelessWidget {
  final Animation<double> animation;

  const AiHikerAnimation({
    super.key,
    required this.animation,
  });

  static const _green = Color(0xFF20A85A);
  static const _blue = Color(0xFF0B5FD7);
  static const _ink = Color(0xFF112234);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final progress = Curves.easeInOut.transform(animation.value);
              final x = 14 + (constraints.maxWidth - 78) * progress;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 18,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEAF6E8), Color(0xFFF4F8F1)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 20,
                    bottom: 41,
                    child: Icon(
                      Icons.forest_rounded,
                      size: 34,
                      color: Color(0xFF5A9B55),
                    ),
                  ),
                  const Positioned(
                    right: 18,
                    bottom: 40,
                    child: Icon(
                      Icons.terrain_rounded,
                      size: 46,
                      color: Color(0xFF8B9C88),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 35,
                    child: CustomPaint(
                      painter: _TrailProgressPainter(progress),
                      child: const SizedBox(height: 18),
                    ),
                  ),
                  Positioned(
                    left: x,
                    bottom: 46,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _green, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hiking_rounded,
                        size: 31,
                        color: _green,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: _blue,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Gemini sta cercando il sentiero migliore',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink.withValues(alpha: .82),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TrailProgressPainter extends CustomPainter {
  final double progress;

  const _TrailProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = const Color(0xFFC9D8C5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final active = Paint()
      ..color = const Color(0xFF20A85A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * .72)
      ..cubicTo(
        size.width * .28,
        size.height * .05,
        size.width * .58,
        size.height * .95,
        size.width,
        size.height * .28,
      );

    canvas.drawPath(path, base);

    for (final metric in path.computeMetrics()) {
      final partial = metric.extractPath(
        0,
        metric.length * progress.clamp(0.0, 1.0),
      );
      canvas.drawPath(partial, active);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
