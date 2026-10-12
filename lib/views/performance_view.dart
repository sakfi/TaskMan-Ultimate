import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../widgets/segmented_meter.dart';
import '../widgets/trace_graph.dart';

class PerformanceView extends StatefulWidget {
  const PerformanceView({super.key});

  @override
  State<PerformanceView> createState() => _PerformanceViewState();
}

class _PerformanceViewState extends State<PerformanceView> {
  bool _forceSegmented = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final metrics = provider.latestMetrics;

    final cpuPercent = metrics?.cpuPercent ?? 0.0;
    final kernelPercent = metrics?.kernelCpuPercent ?? 0.0;
    final memPercent = metrics?.memoryPercent ?? 0.0;
    final diskMBs = metrics?.diskUsageMBs ?? 0.0;
    final netKbps = metrics?.networkUsageKbps ?? 0.0;
    final power = metrics?.powerStatus;

    final totalMemGB = ((metrics?.totalMemoryBytes ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final usedMemGB = ((metrics?.usedMemoryBytes ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final availMemGB = ((metrics?.availableMemoryBytes ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(1);

    final showSegmented = _forceSegmented || skin.defaultMeterStyle == MeterStyle.segmented;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control Bar: Mode Toggle, Logical Cores Toggle, Kernel Times Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Telemetry Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: skin.textPrimary,
                ),
              ),
              Row(
                children: [
                  // Logical Cores Toggle
                  Checkbox(
                    checked: provider.showPerCoreCpu,
                    onChanged: (val) => provider.togglePerCoreCpu(),
                    content: Text(
                      '${provider.coreCount} Logical Cores',
                      style: TextStyle(fontSize: 11, color: skin.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Show Kernel Times (Dave Plummer Classic feature)
                  Checkbox(
                    checked: provider.showKernelTimes,
                    onChanged: (val) => provider.toggleKernelTimes(),
                    content: Text(
                      'Kernel Times',
                      style: TextStyle(fontSize: 11, color: skin.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Retro LED Bars Toggle
                  Text(
                    'LED Bars:',
                    style: TextStyle(fontSize: 11, color: skin.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  ToggleSwitch(
                    checked: showSegmented,
                    onChanged: (val) {
                      setState(() {
                        _forceSegmented = val;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Graphs / Meters Grid
          Expanded(
            child: provider.showPerCoreCpu
                ? _buildLogicalCoresGrid(provider, skin, showSegmented)
                : (showSegmented
                    ? _buildSegmentedGrid(skin, cpuPercent, memPercent, diskMBs, netKbps, usedMemGB, totalMemGB)
                    : _buildTraceGrid(provider, skin, cpuPercent, kernelPercent, memPercent, diskMBs, netKbps)),
          ),

          const SizedBox(height: 12),

          // Bottom System Info Bar with Battery/Power Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: skin.tileBackground,
              borderRadius: BorderRadius.circular(skin.tileCornerRadius),
              border: Border.all(color: skin.tileStroke),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoTile('RAM In-Use', '$usedMemGB / $totalMemGB GB', skin),
                _infoTile('RAM Available', '$availMemGB GB', skin),
                _infoTile('Processes', '${metrics?.processes.length ?? 0}', skin),
                _infoTile('Logical Processors', '${provider.coreCount}', skin),
                if (power != null)
                  _infoTile(
                    'Power Source',
                    power.batteryPercent >= 0
                        ? '${power.batteryPercent}% ${power.isCharging ? "Charging" : (power.isACPlugged ? "AC" : "Battery")}'
                        : (power.isACPlugged ? 'Desktop AC' : 'Online'),
                    skin,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogicalCoresGrid(TaskManProvider provider, SkinTheme skin, bool showSegmented) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        borderRadius: BorderRadius.circular(skin.tileCornerRadius),
        border: Border.all(color: skin.tileStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOGICAL PROCESSORS GRID (${provider.coreCount} CORES)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: skin.textAccent,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: provider.coreCount > 16 ? 6 : (provider.coreCount > 8 ? 4 : 2),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: provider.coreCount,
              itemBuilder: (context, index) {
                final history = provider.coreHistories[index];
                final currentVal = history.isNotEmpty ? history.last : 0.0;

                return showSegmented
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.black,
                        child: SegmentedMeter(
                          label: 'CPU $index',
                          value: currentVal,
                          channelColor: skin.getChannel('cpu'),
                          segments: 10,
                          displayValue: '${currentVal.toStringAsFixed(1)}%',
                        ),
                      )
                    : TraceGraph(
                        title: 'CPU Core $index',
                        currentValText: '${currentVal.toStringAsFixed(0)}%',
                        history: history,
                        channelColor: skin.getChannel('cpu'),
                        maxY: 100.0,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedGrid(
    SkinTheme skin,
    double cpu,
    double mem,
    double disk,
    double net,
    String usedMemGB,
    String totalMemGB,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        borderRadius: BorderRadius.circular(skin.tileCornerRadius),
        border: Border.all(color: skin.tileStroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: SegmentedMeter(
              label: 'CPU USAGE',
              value: cpu,
              channelColor: skin.getChannel('cpu'),
              segments: 16,
              displayValue: '${cpu.toStringAsFixed(1)}%',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedMeter(
              label: 'MEMORY USAGE',
              value: mem,
              channelColor: skin.getChannel('memory'),
              segments: 16,
              displayValue: '${mem.toStringAsFixed(1)}% ($usedMemGB / $totalMemGB GB)',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedMeter(
              label: 'DISK ACTIVITY',
              value: (disk * 5.0).clamp(0.0, 100.0),
              channelColor: skin.getChannel('disk'),
              segments: 16,
              displayValue: '${disk.toStringAsFixed(1)} MB/s',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedMeter(
              label: 'NETWORK',
              value: (net / 10.0).clamp(0.0, 100.0),
              channelColor: skin.getChannel('network'),
              segments: 16,
              displayValue: '${net.toStringAsFixed(0)} Kbps',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceGrid(
    TaskManProvider provider,
    SkinTheme skin,
    double cpu,
    double kernel,
    double mem,
    double disk,
    double net,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 700 ? 2 : 1,
          childAspectRatio: 1.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            TraceGraph(
              title: 'Processor (CPU)',
              currentValText: '${cpu.toStringAsFixed(1)}%',
              history: provider.cpuHistory,
              secondaryHistory: provider.showKernelTimes ? provider.kernelCpuHistory : null,
              channelColor: skin.getChannel('cpu'),
              maxY: 100.0,
            ),
            TraceGraph(
              title: 'Physical Memory (RAM)',
              currentValText: '${mem.toStringAsFixed(1)}%',
              history: provider.memoryHistory,
              channelColor: skin.getChannel('memory'),
              maxY: 100.0,
            ),
            TraceGraph(
              title: 'Disk I/O Throughput',
              currentValText: '${disk.toStringAsFixed(1)} MB/s',
              history: provider.diskHistory,
              channelColor: skin.getChannel('disk'),
              maxY: 50.0,
              unit: 'MB/s',
            ),
            TraceGraph(
              title: 'Network Throughput',
              currentValText: '${net.toStringAsFixed(0)} Kbps',
              history: provider.networkHistory,
              channelColor: skin.getChannel('network'),
              maxY: 1000.0,
              unit: 'Kbps',
            ),
          ],
        );
      },
    );
  }

  Widget _infoTile(String label, String value, SkinTheme skin) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: skin.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Consolas',
            color: skin.textPrimary,
          ),
        ),
      ],
    );
  }
}
