import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class StartupAppsView extends StatefulWidget {
  const StartupAppsView({super.key});

  @override
  State<StartupAppsView> createState() => _StartupAppsViewState();
}

class _StartupAppsViewState extends State<StartupAppsView> {
  List<StartupAppInfo> _apps = [];
  bool _loading = true;
  String _search = '';
  StartupAppInfo? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await SystemExtendedService.instance.getStartupApps();
    if (mounted) {
      setState(() {
        _apps = list;
        _loading = false;
      });
    }
  }

  Color _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFFB300);
      case 'low':
        return const Color(0xFF69F0AE);
      default:
        return Colors.grey[100];
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    final filtered = _apps.where((a) {
      return a.name.toLowerCase().contains(_search.toLowerCase()) ||
          a.command.toLowerCase().contains(_search.toLowerCase()) ||
          a.publisher.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.play, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Startup Apps', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.textAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filtered.length} startup items',
                style: TextStyle(color: skin.textAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Button(
              onPressed: () => Process.run('explorer.exe', ['shell:startup']),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.folder, size: 14),
                  SizedBox(width: 6),
                  Text('Startup Folder'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Process.run('cmd.exe', ['/c', 'start ms-settings:startupapps']),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.settings, size: 14),
                  SizedBox(width: 6),
                  Text('Windows Startup Settings'),
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
            // Search Bar & Details
            Row(
              children: [
                SizedBox(
                  width: 320,
                  child: TextBox(
                    placeholder: 'Search startup apps...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (val) => setState(() => _search = val),
                  ),
                ),
                const Spacer(),
                if (_selected != null)
                  Button(
                    onPressed: () {
                      final q = Uri.encodeComponent('${_selected!.name} startup impact');
                      Process.run('cmd.exe', ['/c', 'start', 'https://www.google.com/search?q=$q']);
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.search_and_apps, size: 14),
                        SizedBox(width: 6),
                        Text('Search Online'),
                      ],
                    ),
                  ),
              ],
            ),

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
                  Expanded(flex: 3, child: Text('Name', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Publisher', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Startup Impact', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 4, child: Text('Command Line', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
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
                        itemCount: filtered.length,
                        separatorBuilder: (_, index) => Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),
                        itemBuilder: (context, idx) {
                          final a = filtered[idx];
                          final isSelected = _selected?.name == a.name;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = a),
                            child: Container(
                              color: isSelected
                                  ? skin.textAccent.withValues(alpha: 0.18)
                                  : (idx.isEven ? skin.tileBackground : skin.tileBackground.withValues(alpha: 0.7)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      a.name,
                                      style: TextStyle(
                                        color: skin.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      a.publisher,
                                      style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      a.isEnabled ? 'Enabled' : 'Disabled',
                                      style: TextStyle(
                                        color: a.isEnabled ? const Color(0xFF00E676) : Colors.grey[100],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _getImpactColor(a.impact),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          a.impact,
                                          style: TextStyle(color: _getImpactColor(a.impact), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      a.command,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: skin.textSecondary, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
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
