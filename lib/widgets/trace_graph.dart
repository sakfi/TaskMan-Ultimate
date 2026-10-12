import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import '../models/skin_theme.dart';

class TraceGraph extends StatelessWidget {
  final String title;
  final String currentValText;
  final List<double> history;
  final List<double>? secondaryHistory;
  final Color? secondaryColor;
  final ChannelColor channelColor;
  final double maxY;
  final String unit;

  const TraceGraph({
    super.key,
    required this.title,
    required this.currentValText,
    required this.history,
    this.secondaryHistory,
    this.secondaryColor,
    required this.channelColor,
    this.maxY = 100.0,
    this.unit = '%',
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].clamp(0.0, maxY)));
    }

    final secondarySpots = <FlSpot>[];
    if (secondaryHistory != null) {
      for (int i = 0; i < secondaryHistory!.length; i++) {
        secondarySpots.add(FlSpot(i.toDouble(), secondaryHistory![i].clamp(0.0, maxY)));
      }
    }

    final lineBars = <LineChartBarData>[
      // Main user/overall trace
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: channelColor.accent,
        barWidth: 2.0,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              channelColor.accent.withValues(alpha: 0.35),
              channelColor.accent.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ];

    // Optional Kernel Times trace (Dave Plummer Classic feature)
    if (secondarySpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: secondarySpots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: secondaryColor ?? const Color(0xFFFF4D4D),
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080C10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: channelColor.accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: channelColor.accent,
                ),
              ),
              Row(
                children: [
                  if (secondarySpots.isNotEmpty) ...[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: secondaryColor ?? const Color(0xFFFF4D4D),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text(
                      'Kernel',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFF4D4D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: channelColor.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentValText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Consolas',
                        color: channelColor.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxY / 4,
                  verticalInterval: 15,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFF222B35),
                    strokeWidth: 0.8,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: const Color(0xFF1B232C),
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 59,
                minY: 0,
                maxY: maxY,
                lineBarsData: lineBars,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '60s ago',
                style: TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
              ),
              Text(
                '0-$maxY $unit',
                style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
              ),
              const Text(
                'now',
                style: TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
