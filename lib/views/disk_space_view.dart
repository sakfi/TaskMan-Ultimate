import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';
import '../widgets/segmented_meter.dart';

class DiskSpaceView extends StatefulWidget {
  const DiskSpaceView({super.key});

  @override
  State<DiskSpaceView> createState() => _DiskSpaceViewState();
}

class _DiskSpaceViewState extends State<DiskSpaceView> {
  List<DiskDriveInfo> _drives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final list = await SystemExtendedService.instance.getDrives(force: force);
    if (mounted) {
      setState(() {
        _drives = list;
        _loading = false;
      });
    }
  }

  Color _getUsageColor(double percent) {
    if (percent > 90.0) return const Color(0xFFFF5252);
    if (percent > 75.0) return Colors.orange;
    return const Color(0xFF00E676);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.hard_drive, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Disk Space & Storage', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Button(
              onPressed: () => _load(force: true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 14),
                  SizedBox(width: 6),
                  Text('Scan Drives'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Process.run('cleanmgr.exe', []),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14),
                  SizedBox(width: 6),
                  Text('Disk Cleanup (cleanmgr)'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: _loading
          ? const Center(child: ProgressRing())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _drives.length,
              itemBuilder: (context, idx) {
                final d = _drives[idx];
                final color = _getUsageColor(d.usedPercent);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
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
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(FluentIcons.hard_drive, color: color, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${d.label} (${d.name})',
                                      style: TextStyle(
                                        color: skin.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: skin.textAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        d.fileSystem,
                                        style: TextStyle(color: skin.textAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.formattedFree} free of ${d.formattedTotal} (${d.usedPercent.toStringAsFixed(1)}% used)',
                                  style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Button(
                            onPressed: () => Process.run('explorer.exe', [d.name]),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.folder, size: 14),
                                SizedBox(width: 6),
                                Text('Open'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SegmentedMeter(
                        value: d.usedPercent,
                        segments: 28,
                        height: 18,
                        channelColor: ChannelColor(
                          accent: color,
                          lit: color,
                          unlit: skin.unlitChannelColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
