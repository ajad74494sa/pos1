import 'dart:math' as math;
import 'package:flutter/material.dart';

class FuturisticLoader extends StatefulWidget {
  final String title;
  final String subTitle;
  final double size;
  final bool showGrid;

  const FuturisticLoader({
    Key? key,
    this.title = 'KR POS',
    this.subTitle = 'LODING...',
    this.size = 200,
    this.showGrid = true,
  }) : super(key: key);

  @override
  _FuturisticLoaderState createState() => _FuturisticLoaderState();
}

class _FuturisticLoaderState extends State<FuturisticLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Grid Background
            if (widget.showGrid) _buildGridBackground(),
            
            // Outer Rotating Rings
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _FuturisticPainter(
                    animationValue: _controller.value,
                    color: const Color(0xFF00E5FF), // Cyan/Light Blue
                  ),
                );
              },
            ),
            
            // Text in the center
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: const Color(0xFF00E5FF),
                    fontSize: widget.size * 0.15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: const Color(0xFF00E5FF).withOpacity(0.8),
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subTitle,
                  style: TextStyle(
                    color: const Color(0xFF00E5FF).withOpacity(0.7),
                    fontSize: widget.size * 0.05,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBackground() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _FuturisticPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _FuturisticPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Inner Circle
    final innerCirclePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.6, innerCirclePaint);

    // 2. Middle Dashed Ring (Rotating)
    final dashPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    _drawDashedArc(canvas, center, radius * 0.8, 
        math.pi * 2 * animationValue, math.pi * 0.4, 6, dashPaint);
    _drawDashedArc(canvas, center, radius * 0.8, 
        math.pi * 2 * animationValue + math.pi, math.pi * 0.4, 6, dashPaint);

    // 3. Outer Segmented Ring (Counter Rotating)
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    double outerRotation = -math.pi * 2 * animationValue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      outerRotation,
      math.pi * 0.3,
      false,
      outerPaint,
    );

    // 4. Subtle Outer Circle
    final thinOuterPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, radius * 1.1, thinOuterPaint);
    
    // 5. Four Corner brackets/marks
    _drawBrackets(canvas, center, radius * 0.9, color.withOpacity(0.8));
  }

  void _drawDashedArc(Canvas canvas, Offset center, double radius, 
      double startAngle, double sweepAngle, int dashCount, Paint paint) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < dashCount; i++) {
      double angle = startAngle + (sweepAngle / dashCount) * i * 2;
      canvas.drawArc(rect, angle, (sweepAngle / dashCount), false, paint);
    }
  }

  void _drawBrackets(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    double len = radius * 0.2;
    // Top Left
    canvas.drawLine(Offset(center.dx - radius, center.dy - radius), Offset(center.dx - radius + len, center.dy - radius), paint);
    canvas.drawLine(Offset(center.dx - radius, center.dy - radius), Offset(center.dx - radius, center.dy - radius + len), paint);
    
    // Top Right
    canvas.drawLine(Offset(center.dx + radius, center.dy - radius), Offset(center.dx + radius - len, center.dy - radius), paint);
    canvas.drawLine(Offset(center.dx + radius, center.dy - radius), Offset(center.dx + radius, center.dy - radius + len), paint);
    
    // Bottom Left
    canvas.drawLine(Offset(center.dx - radius, center.dy + radius), Offset(center.dx - radius + len, center.dy + radius), paint);
    canvas.drawLine(Offset(center.dx - radius, center.dy + radius), Offset(center.dx - radius, center.dy + radius - len), paint);
    
    // Bottom Right
    canvas.drawLine(Offset(center.dx + radius, center.dy + radius), Offset(center.dx + radius - len, center.dy + radius), paint);
    canvas.drawLine(Offset(center.dx + radius, center.dy + radius), Offset(center.dx + radius, center.dy + radius - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    double step = 30.0;
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
