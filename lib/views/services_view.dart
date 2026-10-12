import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  List<WindowsServiceInfo> _services = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'All'; // All, Running, Stopped
  WindowsServiceInfo? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final list = await SystemExtendedService.instance.getServices(force: force);
    if (mounted) {
      setState(() {
        _services = list;
        _loading = false;
        if (_selected != null) {
          _selected = _services.firstWhere(
            (s) => s.name == _selected!.name,
            orElse: () => _services.first,
          );
        }
      });
    }
  }

  Future<void> _controlService(String command, String name) async {
    await Process.run('sc.exe', [command, name]);
    await Future.delayed(const Duration(milliseconds: 600));
    _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    final filtered = _services.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_search.toLowerCase()) ||
          s.displayName.toLowerCase().contains(_search.toLowerCase());
      if (!matchesSearch) return false;
      if (_statusFilter == 'Running') return s.isRunning;
      if (_statusFilter == 'Stopped') return !s.isRunning;
      return true;
    }).toList();

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.repair, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Services', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.textAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filtered.length} services (${_services.where((s) => s.isRunning).length} running)',
                style: TextStyle(color: skin.textAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Button(
              onPressed: () => _load(force: true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 14),
                  SizedBox(width: 6),
                  Text('Refresh'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Process.run('services.msc', []),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.open_in_new_window, size: 14),
                  SizedBox(width: 6),
                  Text('Open Services (msc)'),
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
            // Search & Filter Toolbar
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextBox(
                    placeholder: 'Search service name or description...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (val) => setState(() => _search = val),
                  ),
                ),
                const SizedBox(width: 12),
                ComboBox<String>(
                  value: _statusFilter,
                  items: const [
                    ComboBoxItem(value: 'All', child: Text('All Statuses')),
                    ComboBoxItem(value: 'Running', child: Text('Running Only')),
                    ComboBoxItem(value: 'Stopped', child: Text('Stopped Only')),
                  ],
                  onChanged: (val) => setState(() => _statusFilter = val ?? 'All'),
                ),
                const Spacer(),
                if (_selected != null) ...[
                  if (!_selected!.isRunning)
                    FilledButton(
                      onPressed: () => _controlService('start', _selected!.name),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.play, size: 14),
                          SizedBox(width: 6),
                          Text('Start Service'),
                        ],
                      ),
                    )
                  else ...[
                    Button(
                      onPressed: () => _controlService('stop', _selected!.name),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.stop, size: 14),
                          SizedBox(width: 6),
                          Text('Stop Service'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () async {
                        await Process.run('sc.exe', ['stop', _selected!.name]);
                        await Future.delayed(const Duration(milliseconds: 500));
                        await Process.run('sc.exe', ['start', _selected!.name]);
                        _load(force: true);
                      },
                      child: const Text('Restart'),
                    ),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Table Header
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
                  Expanded(flex: 5, child: Text('Display Name', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Startup Type', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

            // Table Body
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
                          final s = filtered[idx];
                          final isSelected = _selected?.name == s.name;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = s),
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
                                      s.name,
                                      style: TextStyle(
                                        color: skin.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      s.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: skin.textSecondary, fontSize: 12),
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
                                            color: s.isRunning ? const Color(0xFF00E676) : Colors.grey[100],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          s.status,
                                          style: TextStyle(
                                            color: s.isRunning ? const Color(0xFF00E676) : skin.textSecondary,
                                            fontWeight: s.isRunning ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      s.startType,
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
