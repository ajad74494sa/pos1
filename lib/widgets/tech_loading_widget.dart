import 'package:flutter/material.dart';
import 'dart:math' as math;

class TechLoadingWidget extends StatefulWidget {
  final String text;
  const TechLoadingWidget({super.key, this.text = 'INITIALIZING...'});

  @override
  State<TechLoadingWidget> createState() => _TechLoadingWidgetState();
}

class _TechLoadingWidgetState extends State<TechLoadingWidget> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color techColor = Colors.cyanAccent.shade400;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Inner glowing circle
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: techColor.withOpacity(0.2 * _pulseController.value),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                      border: Border.all(color: techColor.withOpacity(0.3), width: 1),
                    ),
                  );
                },
              ),

              // Rotating Data Rings
              RotationTransition(
                turns: _rotationController,
                child: CustomPaint(
                  size: const Size(140, 140),
                  painter: TechRingPainter(techColor),
                ),
              ),

              // Counter-rotating outer ring
              RotationTransition(
                turns: ReverseAnimation(_rotationController),
                child: CustomPaint(
                  size: const Size(180, 180),
                  painter: OuterTechRingPainter(techColor),
                ),
              ),

              // Central Text
              Column(
                children: [
                  Text(
                    'KR POS',
                    style: TextStyle(
                      color: techColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [Shadow(color: techColor, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: techColor.withOpacity(0.7),
                      fontSize: 8,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TechGridPainter extends CustomPainter {
  final Color color;
  TechGridPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    const double step = 40;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TechRingPainter extends CustomPainter {
  final Color color;
  TechRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw dashed ring
    for (int i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (i * math.pi / 4),
        math.pi / 8,
        false,
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OuterTechRingPainter extends CustomPainter {
  final Color color;
  OuterTechRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, paint);

    final dashPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi / 4,
      false,
      dashPaint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
