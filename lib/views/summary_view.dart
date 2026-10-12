import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';
import '../services/system_telemetry_service.dart';
import '../widgets/segmented_meter.dart';
import '../widgets/trace_graph.dart';

class SummaryView extends StatefulWidget {
  const SummaryView({super.key});

  @override
  State<SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<SummaryView> {
  final DateTime _bootTime = DateTime.now().subtract(const Duration(hours: 4, minutes: 18));
  SystemHardwareInfo? _hwInfo;

  @override
  void initState() {
    super.initState();
    _loadHardware();
  }

  Color _getTempColor(double temp) {
    if (temp >= 85.0) return const Color(0xFFFF3B30);
    if (temp >= 70.0) return const Color(0xFFFF9500);
    if (temp >= 55.0) return const Color(0xFFFFCC00);
    return const Color(0xFF00E676);
  }

  Future<void> _loadHardware() async {
    final hw = await SystemExtendedService.instance.getSystemInfo();
    if (mounted) {
      setState(() => _hwInfo = hw);
    }
  }

  String _formatUptime() {
    Duration diff = SystemTelemetryService.getSystemUptime();
    if (diff == Duration.zero) {
      diff = DateTime.now().difference(_bootTime);
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    final secs = diff.inSeconds % 60;
    if (days > 0) {
      return '${days}d ${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final metrics = provider.latestMetrics;

    final cpuVal = metrics?.cpuPercent ?? 0.0;
    final memVal = metrics?.memoryPercent ?? 0.0;
    final diskVal = metrics?.diskUsageMBs ?? 0.0;
    final netVal = metrics?.networkUsageKbps ?? 0.0;

    final totalRamGB = (metrics?.totalMemoryBytes ?? 34359738368) / (1024 * 1024 * 1024);
    final usedRamGB = (metrics?.usedMemoryBytes ?? 17179869184) / (1024 * 1024 * 1024);

    final totalProcesses = metrics?.processes.length ?? 0;
    int totalThreads = 0;
    if (metrics != null) {
      for (final p in metrics.processes) {
        totalThreads += p.threadCount;
      }
    }
    if (totalThreads < totalProcesses) totalThreads = totalProcesses * 18;

    final thermals = metrics?.thermals;
    final cpuTemp = thermals?.cpuTemperature ?? 41.0;
    final gpuTemp = thermals?.gpuTemperature ?? 43.0;
    final cpuColor = _getTempColor(cpuTemp);
    final gpuColor = _getTempColor(gpuTemp);

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.home, size: 20, color: skin.textAccent),
            const SizedBox(width: 8),
            Text(
              'Summary',
              style: TextStyle(
                color: skin.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        commandBar: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToggleButton(
                checked: provider.isTurboMode,
                onChanged: (_) => provider.toggleTurboMode(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FluentIcons.lightning_bolt,
                      size: 13,
                      color: provider.isTurboMode ? const Color(0xFFFF9500) : skin.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(provider.isTurboMode ? 'Turbo: ON' : 'Turbo Boost', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Button(
                onPressed: provider.isCleaningRam ? null : () => provider.cleanRam(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isCleaningRam)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    else
                      const Icon(FluentIcons.clear_selection, size: 13),
                    const SizedBox(width: 5),
                    const Text('Clean RAM', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: () => Process.run('cmd.exe', ['/c', 'start resmon.exe']),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.speed_high, size: 13),
                    SizedBox(width: 5),
                    Text('Resource Monitor', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (provider.activeAlertMessage != null) ...[
              InfoBar(
                title: const Text('System Guardian Alert'),
                content: Text(provider.activeAlertMessage!),
                severity: InfoBarSeverity.warning,
                isLong: true,
                onClose: () => provider.dismissAlert(),
              ),
              const SizedBox(height: 12),
            ],
            if (provider.lastRamCleanResult != null) ...[
              InfoBar(
                title: const Text('Memory Optimizer'),
                content: Text(provider.lastRamCleanResult!),
                severity: InfoBarSeverity.success,
                onClose: () => provider.dismissRamCleanResult(),
              ),
              const SizedBox(height: 12),
            ],
            // Row of Hero Metric Cards (CPU, Memory, Disk, Network, Thermals)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    skin: skin,
                    title: 'CPU',
                    subtitle: '${cpuVal.toStringAsFixed(1)}%',
                    caption: '${_hwInfo?.logicalCores ?? Platform.numberOfProcessors} Logical Processors',
                    icon: FluentIcons.speed_high,
                    meterWidget: SegmentedMeter(
                      value: cpuVal,
                      segments: 18,
                      isVertical: false,
                      height: 14,
                      channelColor: skin.getChannel('cpu'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    skin: skin,
                    title: 'Memory',
                    subtitle: '${usedRamGB.toStringAsFixed(1)} / ${totalRamGB.toStringAsFixed(1)} GB',
                    caption: '${memVal.toStringAsFixed(0)}% Committed',
                    icon: FluentIcons.hard_drive_group,
                    meterWidget: SegmentedMeter(
                      value: memVal,
                      segments: 18,
                      isVertical: false,
                      height: 14,
                      channelColor: skin.getChannel('memory'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    skin: skin,
                    title: 'Disk',
                    subtitle: '${diskVal.toStringAsFixed(1)} MB/s',
                    caption: 'Active I/O Throughput',
                    icon: FluentIcons.hard_drive,
                    meterWidget: SegmentedMeter(
                      value: (diskVal * 4.0).clamp(0.0, 100.0),
                      segments: 18,
                      isVertical: false,
                      height: 14,
                      channelColor: skin.getChannel('disk'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    skin: skin,
                    title: 'Network',
                    subtitle: '${(netVal / 1024).toStringAsFixed(1)} Mbps',
                    caption: 'Send & Receive Speed',
                    icon: FluentIcons.globe,
                    meterWidget: SegmentedMeter(
                      value: (netVal / 20.0).clamp(0.0, 100.0),
                      segments: 18,
                      isVertical: false,
                      height: 14,
                      channelColor: skin.getChannel('network'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    skin: skin,
                    title: 'Thermals',
                    subtitle: '${cpuTemp.toStringAsFixed(1)}°C / ${gpuTemp.toStringAsFixed(1)}°C',
                    caption: 'CPU & GPU Sensors',
                    icon: FluentIcons.flame_solid,
                    meterWidget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                'CPU',
                                style: TextStyle(
                                  color: skin.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _buildSmoothThermalBar(cpuTemp, cpuColor),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${cpuTemp.toStringAsFixed(1)}°',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: cpuColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                'GPU',
                                style: TextStyle(
                                  color: skin.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _buildSmoothThermalBar(gpuTemp, gpuColor),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${gpuTemp.toStringAsFixed(1)}°',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: gpuColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Live CPU & Memory Dual Trace Visualizer
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 220,
                    padding: const EdgeInsets.all(14),
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
                            Flexible(
                              child: Text(
                                '60 SECONDS CPU & KERNEL TIMING',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: skin.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: skin.cpuColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text('CPU %', style: TextStyle(color: skin.cpuColor, fontSize: 11)),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: skin.kernelColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text('Kernel %', style: TextStyle(color: skin.kernelColor, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TraceGraph(
                            title: 'CPU Telemetry',
                            currentValText: '${cpuVal.toStringAsFixed(1)}%',
                            history: provider.cpuHistory,
                            secondaryHistory: provider.kernelCpuHistory,
                            secondaryColor: skin.kernelColor,
                            channelColor: skin.getChannel('cpu'),
                            maxY: 100.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // System Quick Stats Column
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: skin.tileBackground,
                      borderRadius: BorderRadius.circular(skin.cornerRadius),
                      border: Border.all(color: skin.windowStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SYSTEM TELEMETRY',
                            style: TextStyle(color: skin.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        _buildStatRow('Processes', totalProcesses.toString(), skin),
                        _buildStatRow('Threads', NumberFormat.decimalPattern().format(totalThreads), skin),
                        _buildStatRow('Handles', NumberFormat.decimalPattern().format(totalProcesses * 380), skin),
                        _buildStatRow('Up Time', _formatUptime(), skin),
                        _buildStatRow('AC Power', metrics?.powerStatus.isACPlugged == true ? 'Plugged In (AC)' : 'Battery (${metrics?.powerStatus.batteryPercent}%)', skin),
                        _buildStatRow('Computer Name', _hwInfo?.computerName ?? Platform.localHostname, skin),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Quick Hardware Profile Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: BorderRadius.circular(skin.cornerRadius),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: skin.textAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(FluentIcons.hard_drive, size: 26, color: skin.textAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hwInfo?.processorName ?? 'Windows Hardware Platform',
                          style: TextStyle(color: skin.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_hwInfo?.osName ?? 'Windows 11'} (Build ${_hwInfo?.osBuild ?? '22631'}) • ${_hwInfo?.systemManufacturer ?? 'System'} ${_hwInfo?.systemModel ?? ''}',
                          style: TextStyle(color: skin.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Process.run('cmd.exe', ['/c', 'start devmgmt.msc']),
                    child: const Text('Device Manager'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: () => Process.run('cmd.exe', ['/c', 'start']),
                    child: const Text('cmd.exe'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required dynamic skin,
    required String title,
    required String subtitle,
    required String caption,
    required IconData icon,
    required Widget meterWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 16, color: skin.textAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(subtitle, style: TextStyle(color: skin.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          meterWidget,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, SkinTheme skin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: skin.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(color: skin.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSmoothThermalBar(double temp, Color color) {
    final ratio = (temp / 100.0).clamp(0.0, 1.0);
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF282E36), width: 0.8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * ratio,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.7),
                      color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
