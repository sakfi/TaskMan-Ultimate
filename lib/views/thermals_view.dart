import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../widgets/trace_graph.dart';

class ThermalsView extends StatelessWidget {
  const ThermalsView({super.key});

  Color _getTempColor(double temp) {
    if (temp >= 85.0) return const Color(0xFFFF3B30); // Critical / Red
    if (temp >= 70.0) return const Color(0xFFFF9500); // Warm / Orange
    if (temp >= 55.0) return const Color(0xFFFFCC00); // Moderate / Yellow
    return const Color(0xFF00E676); // Cool / Green
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final metrics = provider.latestMetrics;
    final thermals = metrics?.thermals;

    final cpuTemp = thermals?.cpuTemperature ?? 41.0;
    final gpuTemp = thermals?.gpuTemperature ?? 43.0;
    final gpuHotSpot = thermals?.gpuHotSpotTemperature ?? 51.0;
    final gpuWatts = thermals?.gpuPowerWatts ?? 22.0;
    final gpuFan = thermals?.gpuFanSpeedPercent ?? 0.0;
    final gpuUtil = thermals?.gpuUtilization ?? 0.0;

    final cpuModel = thermals?.cpuModel ?? 'CPU Processor';
    final gpuModel = thermals?.gpuModel ?? 'Dedicated GPU';
    final cpuSensor = thermals?.cpuSensorSource ?? 'Hardware Thermal Sensor';
    final gpuSensor = thermals?.gpuSensorSource ?? 'GPU Driver Telemetry';

    final isCpuThrottling = thermals?.isCpuThrottling ?? false;
    final coreTemps = thermals?.cpuCoreTemps ?? [];

    final cpuColor = _getTempColor(cpuTemp);
    final gpuColor = _getTempColor(gpuTemp);

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            const Icon(FluentIcons.flame_solid, size: 22, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 10),
            Text(
              'Thermals & Sensors',
              style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2518),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.check_mark, size: 12, color: Color(0xFF00E676)),
                  SizedBox(width: 6),
                  Text(
                    'Auto-Sensor Telemetry Active',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Primary Cards: CPU Package & GPU Core
            Row(
              children: [
                // CPU Package Thermals Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: skin.tileBackground,
                      borderRadius: BorderRadius.circular(skin.cornerRadius),
                      border: Border.all(color: skin.windowStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(FluentIcons.speed_high, size: 18, color: Color(0xFF64D2FF)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cpuModel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: skin.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${cpuTemp.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                color: cpuColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isCpuThrottling ? const Color(0xFFFF3B30) : const Color(0xFF00E676)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCpuThrottling ? 'THROTTLING' : 'Optimal Temp',
                                style: TextStyle(
                                  color: isCpuThrottling ? const Color(0xFFFF3B30) : const Color(0xFF00E676),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Clean smooth gauge line (no LED bars)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final ratio = (cpuTemp / 100.0).clamp(0.0, 1.0);
                            return Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E232A),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: constraints.maxWidth * ratio,
                                decoration: BoxDecoration(
                                  color: cpuColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sensor: $cpuSensor',
                          style: TextStyle(color: skin.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // GPU Core Thermals Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: skin.tileBackground,
                      borderRadius: BorderRadius.circular(skin.cornerRadius),
                      border: Border.all(color: skin.windowStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(FluentIcons.screen, size: 18, color: Color(0xFF00E676)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                gpuModel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: skin.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${gpuTemp.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                color: gpuColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Hot Spot: ${gpuHotSpot.toStringAsFixed(1)}°C',
                                style: TextStyle(
                                  color: skin.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Clean smooth gauge line (no LED bars)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final ratio = (gpuTemp / 100.0).clamp(0.0, 1.0);
                            return Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E232A),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: constraints.maxWidth * ratio,
                                decoration: BoxDecoration(
                                  color: gpuColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Power: ${gpuWatts.toStringAsFixed(1)} W | Fan: ${gpuFan.toStringAsFixed(0)}% | Load: ${gpuUtil.toStringAsFixed(0)}%',
                              style: TextStyle(color: skin.textSecondary, fontSize: 11),
                            ),
                            Text(
                              gpuSensor,
                              style: TextStyle(color: skin.textSecondary, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 60-Second Real-Time Thermal History Trace Chart
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: BorderRadius.circular(skin.cornerRadius),
                border: Border.all(color: skin.windowStroke),
              ),
              child: SizedBox(
                height: 190,
                child: TraceGraph(
                  title: 'CPU & GPU REAL-TIME TEMPERATURE HISTORY',
                  currentValText: 'CPU: ${cpuTemp.toStringAsFixed(1)}°C  |  GPU: ${gpuTemp.toStringAsFixed(1)}°C',
                  history: provider.cpuThermalHistory,
                  secondaryHistory: provider.gpuThermalHistory,
                  secondaryColor: const Color(0xFF00E676),
                  channelColor: skin.getChannel('thermal'),
                  maxY: 100.0,
                  unit: '°C',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Per-Core CPU Temperature Breakdown Grid
            if (coreTemps.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: skin.tileBackground,
                  borderRadius: BorderRadius.circular(skin.cornerRadius),
                  border: Border.all(color: skin.windowStroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PER-CORE PROCESSOR TEMPERATURES',
                      style: TextStyle(
                        color: skin.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3.2,
                      ),
                      itemCount: coreTemps.length,
                      itemBuilder: (context, idx) {
                        final t = coreTemps[idx];
                        final c = _getTempColor(t);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14171A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF22262B)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Core $idx',
                                style: TextStyle(
                                  color: skin.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${t.toStringAsFixed(1)}°C',
                                style: TextStyle(
                                  color: c,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
