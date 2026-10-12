import 'dart:math';
import 'package:flutter/widgets.dart';

class AnalogGaugeWidget extends StatefulWidget {
  final String title;
  final double value;
  final double maxValue;
  final String unit;
  final List<double> ticks;
  final int decimalPlaces;
  final double size;

  const AnalogGaugeWidget({
    super.key,
    required this.title,
    required this.value,
    this.maxValue = 800.0,
    required this.unit,
    this.ticks = const [0, 200, 400, 600, 800],
    this.decimalPlaces = 0,
    this.size = 290,
  });

  @override
  State<AnalogGaugeWidget> createState() => _AnalogGaugeWidgetState();
}

class _AnalogGaugeWidgetState extends State<AnalogGaugeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _needleAnimation;
  double _prevValue = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _needleAnimation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _prevValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnalogGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _needleAnimation = Tween<double>(begin: _prevValue, end: widget.value).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
      );
      _prevValue = widget.value;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _needleAnimation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _AnalogGaugePainter(
              title: widget.title,
              currentValue: _needleAnimation.value,
              maxValue: widget.maxValue,
              unit: widget.unit,
              ticks: widget.ticks,
              decimalPlaces: widget.decimalPlaces,
            ),
          ),
        );
      },
    );
  }
}

class _AnalogGaugePainter extends CustomPainter {
  final String title;
  final double currentValue;
  final double maxValue;
  final String unit;
  final List<double> ticks;
  final int decimalPlaces;

  _AnalogGaugePainter({
    required this.title,
    required this.currentValue,
    required this.maxValue,
    required this.unit,
    required this.ticks,
    required this.decimalPlaces,
  });

  // 135 deg (7:30 o'clock) to 405 deg (4:30 o'clock) - 270 deg sweep
  static const double startAngle = 135 * (pi / 180);
  static const double sweepAngle = 270 * (pi / 180);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer Dark Metallic Bezel Ring with metallic sheen
    final outerBezelPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF2C3036),
          Color(0xFF1E2125),
          Color(0xFF0F1113),
          Color(0xFF08090A),
        ],
        stops: const [0.75, 0.88, 0.96, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outerBezelPaint);

    // Bezel outer chrome highlight edge
    final bezelBorder = Paint()
      ..color = const Color(0xFF4C535D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 1.0, bezelBorder);

    // Subtle inner metallic groove
    final innerBezelBorder = Paint()
      ..color = const Color(0xFF16181B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius - 7, innerBezelBorder);

    // 2. Dial Face: Dark carbon / vignette with green-tinted perimeter glow
    final dialRadius = radius - 11;
    final dialFacePaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF1E2422), // subtle deep greenish tint in center-reflection
          Color(0xFF131718),
          Color(0xFF0A0C0E),
          Color(0xFF050607),
        ],
        stops: const [0.0, 0.55, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: dialRadius));
    canvas.drawCircle(center, dialRadius, dialFacePaint);

    // Dial edge subtle ambient rim
    final dialRimPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0x2213D6B2),
          Color(0x0513D6B2),
          Color(0x3313D6B2),
          Color(0x0513D6B2),
          Color(0x2213D6B2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: dialRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, dialRadius - 1.5, dialRimPaint);

    // 3. Ticks and Labels
    final trackRadius = dialRadius - 13;

    // Track arc
    final trackPaint = Paint()
      ..color = const Color(0xFF1E332B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: trackRadius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Draw major and minor ticks
    const int totalTicks = 40;
    for (int i = 0; i <= totalTicks; i++) {
      final fraction = i / totalTicks;
      final angle = startAngle + (fraction * sweepAngle);
      final isMajor = i % (totalTicks ~/ (ticks.length - 1)) == 0;

      final tickLength = isMajor ? 13.0 : 6.0;
      final tickStroke = isMajor ? 2.2 : 1.1;
      final tickColor = isMajor ? const Color(0xFFE2E8F0) : const Color(0xFF5F6B78);

      final p1 = Offset(
        center.dx + (trackRadius - 1) * cos(angle),
        center.dy + (trackRadius - 1) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (trackRadius - tickLength) * cos(angle),
        center.dy + (trackRadius - tickLength) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = tickStroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Cyan accent markers at the bottom extremes
    final cyanP1Start = Offset(
      center.dx + (trackRadius - 2) * cos(startAngle),
      center.dy + (trackRadius - 2) * sin(startAngle),
    );
    final cyanP2Start = Offset(
      center.dx + (trackRadius - 16) * cos(startAngle),
      center.dy + (trackRadius - 16) * sin(startAngle),
    );
    final cyanP1End = Offset(
      center.dx + (trackRadius - 2) * cos(startAngle + sweepAngle),
      center.dy + (trackRadius - 2) * sin(startAngle + sweepAngle),
    );
    final cyanP2End = Offset(
      center.dx + (trackRadius - 16) * cos(startAngle + sweepAngle),
      center.dy + (trackRadius - 16) * sin(startAngle + sweepAngle),
    );
    final cyanTickPaint = Paint()
      ..color = const Color(0xFF00DFD0)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(cyanP1Start, cyanP2Start, cyanTickPaint);
    canvas.drawLine(cyanP1End, cyanP2End, cyanTickPaint);

    // Draw Numbers for Ticks
    for (int i = 0; i < ticks.length; i++) {
      final fraction = i / (ticks.length - 1);
      final angle = startAngle + (fraction * sweepAngle);
      final tickVal = ticks[i];

      final labelRadius = trackRadius - 26;
      final lx = center.dx + labelRadius * cos(angle);
      final ly = center.dy + labelRadius * sin(angle);

      final textStr = decimalPlaces > 0
          ? tickVal.toStringAsFixed(decimalPlaces)
          : tickVal.toStringAsFixed(0);

      final tp = TextPainter(
        text: TextSpan(
          text: textStr,
          style: const TextStyle(
            color: Color(0xFFC4CFDC),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Segoe UI',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // 4. Center Title ("Single core" / "Multi core")
    final titleTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFF86929F),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          fontFamily: 'Segoe UI',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(center.dx - titleTp.width / 2, center.dy - 38));

    // 5. Digital 7-Segment LCD Odometer Readout Box
    final readoutRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 48),
      width: 76,
      height: 24,
    );
    final readoutBoxPaint = Paint()
      ..color = const Color(0xFF050709)
      ..style = PaintingStyle.fill;
    final readoutBorder = Paint()
      ..color = const Color(0xFF262C34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRRect(RRect.fromRectAndRadius(readoutRect, const Radius.circular(2)), readoutBoxPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(readoutRect, const Radius.circular(2)), readoutBorder);

    // Digital numeric display
    final numStr = decimalPlaces > 0
        ? currentValue.toStringAsFixed(decimalPlaces)
        : currentValue.toStringAsFixed(0);

    // Ghosted "8888" background unlit segment look
    final ghostTp = TextPainter(
      text: const TextSpan(
        text: '8888',
        style: TextStyle(
          color: Color(0x1800DFD0),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'Consolas',
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ghostTp.paint(
      canvas,
      Offset(readoutRect.center.dx - ghostTp.width / 2, readoutRect.center.dy - ghostTp.height / 2),
    );

    // Active digits
    final readoutTp = TextPainter(
      text: TextSpan(
        text: numStr,
        style: const TextStyle(
          color: Color(0xFF67DBEF),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'Consolas',
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: Color(0xFF0090B0), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    readoutTp.paint(
      canvas,
      Offset(readoutRect.center.dx - readoutTp.width / 2, readoutRect.center.dy - readoutTp.height / 2),
    );

    // 6. Unit Subtitle ("Mops/sec" / "Gop/sec") in glowing cyan
    final unitTp = TextPainter(
      text: TextSpan(
        text: unit,
        style: const TextStyle(
          color: Color(0xFF00DFD0),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Segoe UI',
          shadows: [
            Shadow(color: Color(0xFF088074), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unitTp.paint(canvas, Offset(center.dx - unitTp.width / 2, center.dy + 68));

    // 7. Red Gauge Needle
    final clampedVal = currentValue.clamp(0.0, maxValue);
    final valFraction = maxValue > 0 ? (clampedVal / maxValue) : 0.0;
    final needleAngle = startAngle + (valFraction * sweepAngle);

    final needleLength = trackRadius - 4;
    final needleTip = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    // Needle drop shadow
    final shadowTip = Offset(needleTip.dx + 2, needleTip.dy + 3);
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, shadowTip, shadowPaint);

    // Needle Path (tapered needle)
    final needlePath = Path();
    final perpAngle = needleAngle + (pi / 2);
    const baseWidth = 3.4;

    final pBase1 = Offset(
      center.dx + baseWidth * cos(perpAngle),
      center.dy + baseWidth * sin(perpAngle),
    );
    final pBase2 = Offset(
      center.dx - baseWidth * cos(perpAngle),
      center.dy - baseWidth * sin(perpAngle),
    );

    needlePath.moveTo(pBase1.dx, pBase1.dy);
    needlePath.lineTo(needleTip.dx, needleTip.dy);
    needlePath.lineTo(pBase2.dx, pBase2.dy);
    needlePath.close();

    final needlePaint = Paint()
      ..color = const Color(0xFFE52521)
      ..style = PaintingStyle.fill;
    canvas.drawPath(needlePath, needlePaint);

    // Needle center bright stripe
    final needleTipGlow = Paint()
      ..color = const Color(0xFFFF6666)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needleTipGlow);

    // 8. Center Metallic Pivot Hub
    const hubRadius = 14.0;
    final hubOuter = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF656D77),
          Color(0xFF33383F),
          Color(0xFF141618),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: hubRadius));
    canvas.drawCircle(center, hubRadius, hubOuter);

    final hubRing = Paint()
      ..color = const Color(0xFF8B96A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, hubRadius, hubRing);

    final hubInner = Paint()
      ..color = const Color(0xFF1B1E22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.0, hubInner);

    final hubCenterDot = Paint()
      ..color = const Color(0xFF9CA7B5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0, hubCenterDot);
  }

  @override
  bool shouldRepaint(covariant _AnalogGaugePainter oldDelegate) {
    return oldDelegate.currentValue != currentValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.title != title;
  }
}
