import 'dart:math';
import 'package:flutter/widgets.dart';

class TaskManLogoWidget extends StatefulWidget {
  final double width;
  final double height;

  const TaskManLogoWidget({
    super.key,
    this.width = 175,
    this.height = 42,
  });

  @override
  State<TaskManLogoWidget> createState() => _TaskManLogoWidgetState();
}

class _TaskManLogoWidgetState extends State<TaskManLogoWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _TaskManLogoPainter(
              pulseValue: _pulseController.value,
            ),
          ),
        );
      },
    );
  }
}

class _TaskManLogoPainter extends CustomPainter {
  final double pulseValue;

  _TaskManLogoPainter({
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background dark container pill
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(6));

    final bgPaint = Paint()
      ..color = const Color(0xFF0C0E11)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRRect, bgPaint);

    final glowAlpha = (0.25 + (pulseValue * 0.25)).clamp(0.0, 1.0);
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRRect, borderPaint);

    // Mini activity waveform on the left
    final wavePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(14, size.height / 2);
    path.lineTo(20, size.height / 2 - 6 * sin(pulseValue * pi));
    path.lineTo(25, size.height / 2 + 8 * cos(pulseValue * pi));
    path.lineTo(30, size.height / 2 - 10 * sin(pulseValue * pi));
    path.lineTo(35, size.height / 2);
    canvas.drawPath(path, wavePaint);

    // "TASKMAN" text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TASKMAN',
        style: TextStyle(
          color: const Color(0xFF00E5FF),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          fontFamily: 'Segoe UI',
          shadows: [
            Shadow(
              color: const Color(0xFF00E5FF).withValues(alpha: glowAlpha),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(44, (size.height - textPainter.height) / 2 - 4),
    );

    // "ULTIMATE" sub-text
    final subPainter = TextPainter(
      text: const TextSpan(
        text: 'ULTIMATE',
        style: TextStyle(
          color: Color(0xFF8B9BB0),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 3.0,
          fontFamily: 'Segoe UI',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    subPainter.paint(
      canvas,
      Offset(46, size.height / 2 + 5),
    );
  }

  @override
  bool shouldRepaint(covariant _TaskManLogoPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}
