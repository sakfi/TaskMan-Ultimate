import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/taskman_provider.dart';

class MiniHudWidget extends StatelessWidget {
  const MiniHudWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final metrics = provider.latestMetrics;

    final cpu = metrics?.cpuPercent ?? 0.0;
    final mem = metrics?.memoryPercent ?? 0.0;
    final disk = metrics?.diskUsageMBs ?? 0.0;
    final net = metrics?.networkUsageKbps ?? 0.0;
    final power = metrics?.powerStatus;

    return GestureDetector(
      onDoubleTap: () => provider.toggleMiniHudMode(),
      child: Container(
        color: skin.windowBackground,
        child: Column(
          children: [
            // Drag Header
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: skin.headerBackground,
              child: Row(
                children: [
                  Icon(
                    FluentIcons.diagnostic_data_bar_tooltip,
                    size: 12,
                    color: skin.textAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TASKMAN HUD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: skin.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Restore button
                  IconButton(
                    icon: Icon(FluentIcons.mini_expand, size: 10, color: skin.textSecondary),
                    onPressed: () => provider.toggleMiniHudMode(),
                  ),
                  // Close button
                  IconButton(
                    icon: Icon(FluentIcons.chrome_close, size: 10, color: skin.textSecondary),
                    onPressed: () async => await windowManager.close(),
                  ),
                ],
              ),
            ),

            // Mini Meters Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _meterRow('CPU', cpu, skin.getChannel('cpu').accent, '${cpu.toStringAsFixed(0)}%'),
                    _meterRow('RAM', mem, skin.getChannel('memory').accent, '${mem.toStringAsFixed(0)}%'),
                    _meterRow('DSK', (disk * 5).clamp(0.0, 100.0), skin.getChannel('disk').accent, '${disk.toStringAsFixed(1)}M/s'),
                    _meterRow('NET', (net / 10).clamp(0.0, 100.0), skin.getChannel('network').accent, '${net.toStringAsFixed(0)}Kb/s'),
                  ],
                ),
              ),
            ),

            // Power / Battery Status footer
            if (power != null && power.batteryPercent >= 0)
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: skin.tileBackground,
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.info,
                      size: 11,
                      color: skin.textAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Battery: ${power.batteryPercent}% ${power.isCharging ? "(Charging)" : ""}',
                      style: TextStyle(fontSize: 9, color: skin.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _meterRow(String label, double percent, Color color, String value) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F141C),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFF283444), width: 0.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent / 100.0).clamp(0.01, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Consolas',
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
