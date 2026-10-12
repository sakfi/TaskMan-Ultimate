import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class InstalledAppsView extends StatefulWidget {
  const InstalledAppsView({super.key});

  @override
  State<InstalledAppsView> createState() => _InstalledAppsViewState();
}

class _InstalledAppsViewState extends State<InstalledAppsView> {
  List<InstalledAppInfo> _apps = [];
  bool _loading = true;
  String _search = '';
  InstalledAppInfo? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await SystemExtendedService.instance.getInstalledApps();
    if (mounted) {
      setState(() {
        _apps = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    final filtered = _apps.where((a) {
      return a.name.toLowerCase().contains(_search.toLowerCase()) ||
          a.publisher.toLowerCase().contains(_search.toLowerCase()) ||
          a.version.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.bulleted_list_text, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Installed Apps', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.textAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filtered.length} programs',
                style: TextStyle(color: skin.textAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Button(
              onPressed: () => Process.run('control.exe', ['appwiz.cpl']),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.settings, size: 14),
                  SizedBox(width: 6),
                  Text('Programs & Features (appwiz.cpl)'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Process.run('ms-settings:appsfeatures', []),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.app_icon_default, size: 14),
                  SizedBox(width: 6),
                  Text('Windows Apps Settings'),
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
            // Search Bar
            Row(
              children: [
                SizedBox(
                  width: 320,
                  child: TextBox(
                    placeholder: 'Search installed applications...',
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
                      final q = Uri.encodeComponent('${_selected!.name} ${_selected!.publisher}');
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
                  Expanded(flex: 5, child: Text('App Name', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Publisher', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Version', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Installed On', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
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
                          final app = filtered[idx];
                          final isSelected = _selected?.name == app.name;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = app),
                            child: Container(
                              color: isSelected
                                  ? skin.textAccent.withValues(alpha: 0.18)
                                  : (idx.isEven ? skin.tileBackground : skin.tileBackground.withValues(alpha: 0.7)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Row(
                                      children: [
                                        Icon(FluentIcons.app_icon_default, size: 16, color: skin.textAccent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            app.name,
                                            style: TextStyle(
                                              color: skin.textPrimary,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      app.publisher,
                                      style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      app.version,
                                      style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      app.installDate,
                                      style: TextStyle(color: skin.textSecondary, fontSize: 12),
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
