import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class FlightRecorderView extends StatefulWidget {
  const FlightRecorderView({super.key});

  @override
  State<FlightRecorderView> createState() => _FlightRecorderViewState();
}

class _FlightRecorderViewState extends State<FlightRecorderView> {
  final _service = SystemExtendedService.instance;
  int? _scrubbedIndex;

  void _exportJson() async {
    final jsonStr = _service.generateTelemetryJson();
    final file = File('flight_recorder_dump.json');
    await file.writeAsString(jsonStr);

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Export JSON Complete'),
          content: Text('Saved ${_service.flightRecorderLogs.length} events to ${file.absolute.path}'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  void _exportCsv() async {
    final csvStr = _service.generateTelemetryCsv();
    final file = File('flight_recorder_dump.csv');
    await file.writeAsString(csvStr);

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Export CSV Complete'),
          content: Text('Saved ${_service.flightRecorderLogs.length} events to ${file.absolute.path}'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  void _clearLogs() {
    setState(() {
      _service.flightRecorderLogs.clear();
      _scrubbedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    final logs = _service.flightRecorderLogs.reversed.toList();
    final totalSnapshots = _service.flightRecorderLogs.length;

    FlightRecorderSnapshot? inspectedSnapshot;
    if (_scrubbedIndex != null &&
        _scrubbedIndex! >= 0 &&
        _scrubbedIndex! < _service.flightRecorderLogs.length) {
      inspectedSnapshot = _service.flightRecorderLogs[_scrubbedIndex!];
    }

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.send, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Flight Recorder 2.0', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _service.isRecordingFlight ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _service.isRecordingFlight ? const Color(0xFF00E676) : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _service.isRecordingFlight ? 'RECORDING LIVE' : 'RECORDER PAUSED',
                    style: TextStyle(
                      color: _service.isRecordingFlight ? const Color(0xFF00E676) : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Button(
              onPressed: () => setState(() => _service.isRecordingFlight = !_service.isRecordingFlight),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_service.isRecordingFlight ? FluentIcons.pause : FluentIcons.play, size: 14),
                  const SizedBox(width: 6),
                  Text(_service.isRecordingFlight ? 'Pause' : 'Resume'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: _exportCsv,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.table, size: 14),
                  SizedBox(width: 6),
                  Text('Export CSV'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: _exportJson,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.download, size: 14),
                  SizedBox(width: 6),
                  Text('Export JSON'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: _clearLogs,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // Flight Recorder Stats Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: BorderRadius.circular(skin.cornerRadius),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Logged Events', '${logs.length} snapshots', skin),
                  _statItem('Sample Rate', '1.0 sec (Real-time)', skin),
                  _statItem('Spikes Detected', '${logs.where((l) => l.cpuPercent > 70).length}', skin),
                  _statItem('Memory Buffer', '${(logs.length * 64 / 1024).toStringAsFixed(1)} KB', skin),
                ],
              ),
            ),

            if (totalSnapshots > 1) ...[
              const SizedBox(height: 10),
              // Timeline Playback Scrubber Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        Icon(FluentIcons.history, size: 14, color: skin.textAccent),
                        const SizedBox(width: 8),
                        Text(
                          inspectedSnapshot != null
                              ? 'Timeline Inspector - Snapshot at ${DateFormat('HH:mm:ss').format(inspectedSnapshot.timestamp)}'
                              : 'Interactive Timeline Scrubber (Scrub backward to analyze telemetry spikes)',
                          style: TextStyle(
                            color: skin.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (inspectedSnapshot != null)
                          Button(
                            onPressed: () => setState(() => _scrubbedIndex = null),
                            child: const Text('Reset to Live', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Slider(
                      value: (_scrubbedIndex ?? (totalSnapshots - 1)).toDouble().clamp(0.0, (totalSnapshots - 1).toDouble()),
                      min: 0.0,
                      max: (totalSnapshots - 1).toDouble(),
                      onChanged: (val) {
                        setState(() => _scrubbedIndex = val.toInt());
                      },
                    ),
                    if (inspectedSnapshot != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: skin.windowBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: skin.tileStroke),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('Time: ${DateFormat('HH:mm:ss.SSS').format(inspectedSnapshot.timestamp)}',
                                style: TextStyle(color: skin.textSecondary, fontFamily: 'Consolas', fontSize: 12)),
                            Text('CPU: ${inspectedSnapshot.cpuPercent.toStringAsFixed(1)}%',
                                style: TextStyle(color: skin.cpuColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('RAM: ${inspectedSnapshot.memoryPercent.toStringAsFixed(1)}%',
                                style: TextStyle(color: skin.memoryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Disk: ${inspectedSnapshot.diskMBs.toStringAsFixed(1)} MB/s',
                                style: TextStyle(color: skin.diskColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Top Process: ${inspectedSnapshot.topProcessName} (${inspectedSnapshot.topProcessCpu.toStringAsFixed(1)}%)',
                                style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Timestamp', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('CPU %', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Memory %', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Disk (MB/s)', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Top Process', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

            // Logs Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: skin.tileBackground,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                  border: Border(
                    left: BorderSide(color: skin.windowStroke),
                    right: BorderSide(color: skin.windowStroke),
                    bottom: BorderSide(color: skin.windowStroke),
                  ),
                ),
                child: logs.isEmpty
                    ? Center(child: Text('No telemetry events recorded yet.', style: TextStyle(color: skin.textSecondary)))
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, index) => Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),
                        itemBuilder: (context, idx) {
                          final event = logs[idx];
                          final isSpike = event.cpuPercent > 75.0;

                          return Container(
                            color: isSpike
                                ? Colors.red.withValues(alpha: 0.15)
                                : (idx.isEven ? skin.tileBackground : skin.tileBackground.withValues(alpha: 0.7)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    DateFormat('HH:mm:ss.SSS').format(event.timestamp),
                                    style: TextStyle(
                                      color: isSpike ? Colors.red : skin.textPrimary,
                                      fontFamily: 'Consolas',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${event.cpuPercent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: isSpike ? Colors.red : skin.cpuColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${event.memoryPercent.toStringAsFixed(1)}%',
                                    style: TextStyle(color: skin.memoryColor, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${event.diskMBs.toStringAsFixed(1)} MB/s',
                                    style: TextStyle(color: skin.diskColor, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    event.topProcessName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: skin.textPrimary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, dynamic skin) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: skin.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
      ],
    );
  }
}
