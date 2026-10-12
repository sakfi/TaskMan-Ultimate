import 'package:flutter/widgets.dart';
import '../models/skin_theme.dart';

class SegmentedMeter extends StatelessWidget {
  final String? label;
  final double value; // 0.0 to 100.0
  final ChannelColor channelColor;
  final int segments;
  final bool isVertical;
  final double? height;
  final String? displayValue;

  const SegmentedMeter({
    super.key,
    this.label,
    required this.value,
    required this.channelColor,
    this.segments = 14,
    this.isVertical = false,
    this.height,
    this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 100.0);
    final activeCount = ((clamped / 100.0) * segments).round();

    final effectivePadding = (height != null && height! <= 12)
        ? const EdgeInsets.symmetric(horizontal: 2, vertical: 1)
        : const EdgeInsets.symmetric(horizontal: 4, vertical: 3);

    Widget barContainer = Container(
      height: height ?? (isVertical ? 120 : 18),
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border.all(color: const Color(0xFF404040), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: isVertical
          ? Column(
              children: List.generate(segments, (index) {
                final segmentIndex = segments - 1 - index;
                final isLit = segmentIndex < activeCount;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 1.0),
                    decoration: BoxDecoration(
                      color: isLit ? channelColor.lit : channelColor.unlit,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: isLit
                          ? [
                              BoxShadow(
                                color: channelColor.lit.withValues(alpha: 0.6),
                                blurRadius: 3,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            )
          : Row(
              children: List.generate(segments, (index) {
                final isLit = index < activeCount;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.0),
                    decoration: BoxDecoration(
                      color: isLit ? channelColor.lit : channelColor.unlit,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: isLit
                          ? [
                              BoxShadow(
                                color: channelColor.lit.withValues(alpha: 0.5),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
    );

    if (label == null && displayValue == null) {
      return barContainer;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
        ],
        barContainer,
        if (displayValue != null) ...[
          const SizedBox(height: 4),
          Text(
            displayValue!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Consolas',
              color: channelColor.lit,
            ),
          ),
        ],
      ],
    );
  }
}
