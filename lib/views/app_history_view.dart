import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class AppHistoryView extends StatefulWidget {
  const AppHistoryView({super.key});

  @override
  State<AppHistoryView> createState() => _AppHistoryViewState();
}

class _AppHistoryViewState extends State<AppHistoryView> {
  List<AppHistoryInfo> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await SystemExtendedService.instance.getAppHistory();
    if (mounted) {
      setState(() {
        _history = list;
        _loading = false;
      });
    }
  }

  void _clearHistory() {
    setState(() => _history = []);
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('History Reset'),
        content: const Text('Application resource usage history cleared.'),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.history, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('App History', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Button(
              onPressed: _clearHistory,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14),
                  SizedBox(width: 6),
                  Text('Delete usage history'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
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
                  Expanded(flex: 4, child: Text('Name', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('CPU Time', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Network', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Metered Network', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Tile Updates', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: ProgressRing())
                  : Container(
                      decoration: BoxDecoration(
                        color: skin.tileBackground,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                        border: Border(
                          left: BorderSide(color: skin.windowStroke),
                          right: BorderSide(color: skin.windowStroke),
                          bottom: BorderSide(color: skin.windowStroke),
                        ),
                      ),
                      child: ListView.separated(
                        itemCount: _history.length,
                        separatorBuilder: (_, index) => Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),
                        itemBuilder: (context, idx) {
                          final h = _history[idx];

                          return Container(
                            color: idx.isEven ? skin.tileBackground : skin.tileBackground.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      Icon(FluentIcons.app_icon_default, size: 16, color: skin.textAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                        h.name,
                                        style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    h.cpuTime,
                                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${h.networkMB.toStringAsFixed(1)} MB',
                                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${h.meteredNetworkMB.toStringAsFixed(1)} MB',
                                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${h.tileUpdates}',
                                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
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
}
