import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';
import '../services/system_telemetry_service.dart';

class DetailsView extends StatefulWidget {
  const DetailsView({super.key});

  @override
  State<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<DetailsView> {
  String _search = '';
  String _sortColumn = 'cpu';
  bool _sortAsc = false;
  int? _selectedPid;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final processes = List<ProcessInfo>.from(provider.latestMetrics?.processes ?? []);

    // Filter
    final filtered = processes.where((p) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return p.name.toLowerCase().contains(q) || p.pid.toString().contains(q);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'pid':
          cmp = a.pid.compareTo(b.pid);
          break;
        case 'threads':
          cmp = a.threadCount.compareTo(b.threadCount);
          break;
        case 'memory':
          cmp = a.memoryBytes.compareTo(b.memoryBytes);
          break;
        case 'priority':
          cmp = a.priorityClass.compareTo(b.priorityClass);
          break;
        case 'cpu':
        default:
          cmp = a.cpuPercent.compareTo(b.cpuPercent);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });

    ProcessInfo? selectedProc;
    if (_selectedPid != null) {
      try {
        selectedProc = filtered.firstWhere((p) => p.pid == _selectedPid);
      } catch (_) {
        _selectedPid = null;
      }
    }

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.list, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text(
              'Details',
              style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.textAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filtered.length} Processes',
                style: TextStyle(color: skin.textAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            if (selectedProc != null) ...[
              Button(
                onPressed: () {
                  provider.openProcessLocation(selectedProc!);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.folder_open, size: 13),
                    SizedBox(width: 6),
                    Text('Open File Location'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => _showAffinityDialog(context, selectedProc!, provider),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.speed_high, size: 13),
                    SizedBox(width: 6),
                    Text('CPU Affinity'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => _showSignatureDialog(context, selectedProc!),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.certificate, size: 13),
                    SizedBox(width: 6),
                    Text('Verify Sig'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => provider.searchVirusTotal(selectedProc!),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.shield, size: 13),
                    SizedBox(width: 6),
                    Text('VirusTotal'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () async {
                  final pid = selectedProc!.pid;
                  final name = selectedProc.name;
                  final ok = await provider.killProcessTree(pid);
                  if (context.mounted) {
                    displayInfoBar(
                      context,
                      builder: (ctx, close) => InfoBar(
                        title: Text(ok ? 'Process Tree Ended' : 'Action Failed'),
                        content: Text(ok ? 'Terminated $name and children' : 'Access denied'),
                        severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                        onClose: close,
                      ),
                    );
                  }
                  setState(() => _selectedPid = null);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.branch_fork2, size: 13, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text('End Tree', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(const Color(0xFFC42B1C)),
                ),
                onPressed: () {
                  final pid = selectedProc!.pid;
                  final name = selectedProc.name;
                  void doKill() {
                    provider.terminateProcess(pid);
                    setState(() => _selectedPid = null);
                  }

                  if (provider.confirmKill) {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => ContentDialog(
                        title: const Text('End Process?'),
                        content: Text('Are you sure you want to terminate "$name" (PID: $pid)?\nUnsaved data may be lost.'),
                        actions: [
                          Button(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                          FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(const Color(0xFFC42B1C)),
                            ),
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              doKill();
                            },
                            child: const Text('End Task'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    doKill();
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.cancel, size: 13),
                    SizedBox(width: 6),
                    Text('End Task'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // Search Bar & Info
            Row(
              children: [
                SizedBox(
                  width: 300,
                  child: TextBox(
                    placeholder: 'Filter processes by name or PID...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (val) => setState(() => _search = val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Header with Sortable Columns
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Row(
                children: [
                  _headerCell('Name', 'name', flex: 4, skin: skin),
                  _headerCell('PID', 'pid', flex: 2, skin: skin),
                  _headerCell('Status', '', flex: 2, skin: skin),
                  _headerCell('Threads', 'threads', flex: 2, skin: skin),
                  _headerCell('CPU %', 'cpu', flex: 2, skin: skin),
                  _headerCell('Memory', 'memory', flex: 3, skin: skin),
                  _headerCell('Architecture', '', flex: 2, skin: skin),
                  _headerCell('Priority', 'priority', flex: 2, skin: skin),
                ],
              ),
            ),

            // Process Rows List
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
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),
                  itemBuilder: (context, idx) {
                    final proc = filtered[idx];
                    final isSelected = proc.pid == _selectedPid;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedPid = proc.pid),
                      onSecondaryTapUp: (details) {
                        setState(() => _selectedPid = proc.pid);
                        _showContextMenu(context, details.globalPosition, proc, provider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: isSelected ? skin.textAccent.withValues(alpha: 0.15) : Colors.transparent,
                        child: Row(
                          children: [
                            // Name & Icon
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Icon(FluentIcons.process_meta_task, size: 14, color: skin.textAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      proc.name,
                                      style: TextStyle(
                                        color: skin.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // PID
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${proc.pid}',
                                style: TextStyle(color: skin.textSecondary, fontFamily: 'Consolas', fontSize: 12),
                              ),
                            ),
                            // Status
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Running',
                                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Threads
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${proc.threadCount}',
                                style: TextStyle(color: skin.textSecondary, fontSize: 12),
                              ),
                            ),
                            // CPU %
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${proc.cpuPercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: proc.cpuPercent > 10.0 ? skin.getChannel('cpu').accent : skin.textPrimary,
                                  fontWeight: proc.cpuPercent > 10.0 ? FontWeight.bold : FontWeight.normal,
                                  fontFamily: 'Consolas',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // Memory
                            Expanded(
                              flex: 3,
                              child: Text(
                                proc.formattedMemory,
                                style: TextStyle(color: skin.textPrimary, fontFamily: 'Consolas', fontSize: 12),
                              ),
                            ),
                            // Architecture
                            Expanded(
                              flex: 2,
                              child: Text(
                                'x64 (64-bit)',
                                style: TextStyle(color: skin.textSecondary, fontSize: 12),
                              ),
                            ),
                            // Priority
                            Expanded(
                              flex: 2,
                              child: Text(
                                proc.priorityName,
                                style: TextStyle(
                                  color: proc.priorityClass == priorityHigh || proc.priorityClass == priorityRealtime
                                      ? const Color(0xFFFF9500)
                                      : skin.textSecondary,
                                  fontSize: 12,
                                ),
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

  Widget _headerCell(String title, String colKey, {required int flex, required dynamic skin}) {
    final isSorted = _sortColumn == colKey;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: colKey.isEmpty
            ? null
            : () {
                setState(() {
                  if (_sortColumn == colKey) {
                    _sortAsc = !_sortAsc;
                  } else {
                    _sortColumn = colKey;
                    _sortAsc = false;
                  }
                });
              },
        child: MouseRegion(
          cursor: colKey.isEmpty ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSorted ? skin.textAccent : skin.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (isSorted) ...[
                const SizedBox(width: 4),
                Icon(
                  _sortAsc ? FluentIcons.chevron_up : FluentIcons.chevron_down,
                  size: 10,
                  color: skin.textAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset pos, ProcessInfo proc, TaskManProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('Process: ${proc.name} (PID ${proc.pid})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Path: ${proc.fullPath.isNotEmpty ? proc.fullPath : "System Process"}'),
            const SizedBox(height: 8),
            Text('Memory: ${proc.formattedMemory} | Threads: ${proc.threadCount}'),
            const SizedBox(height: 12),
            const Text('Set Priority:'),
            Wrap(
              spacing: 8,
              children: [
                Button(
                  onPressed: () {
                    provider.setPriority(proc.pid, priorityNormal);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Normal'),
                ),
                Button(
                  onPressed: () {
                    provider.setPriority(proc.pid, priorityAboveNormal);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Above Normal'),
                ),
                Button(
                  onPressed: () {
                    provider.setPriority(proc.pid, priorityHigh);
                    Navigator.pop(ctx);
                  },
                  child: const Text('High'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Advanced Actions:'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Button(
                  onPressed: () {
                    Navigator.pop(ctx);
                    provider.openProcessLocation(proc);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.folder_open, size: 12),
                      SizedBox(width: 4),
                      Text('Open Location'),
                    ],
                  ),
                ),
                Button(
                  onPressed: () {
                    Navigator.pop(ctx);
                    provider.searchVirusTotal(proc);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.shield, size: 12),
                      SizedBox(width: 4),
                      Text('VirusTotal'),
                    ],
                  ),
                ),
                Button(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSignatureDialog(context, proc);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.certificate, size: 12),
                      SizedBox(width: 4),
                      Text('Verify Sig'),
                    ],
                  ),
                ),
                Button(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAffinityDialog(context, proc, provider);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.speed_high, size: 12),
                      SizedBox(width: 4),
                      Text('CPU Affinity'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.killProcessTree(proc.pid);
              if (context.mounted) {
                displayInfoBar(
                  context,
                  builder: (bCtx, close) => InfoBar(
                    title: Text(ok ? 'Process Tree Ended' : 'Action Failed'),
                    content: Text(ok ? 'Terminated ${proc.name} and children' : 'Access denied'),
                    severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                    onClose: close,
                  ),
                );
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.branch_fork2, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Text('End Tree', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(const Color(0xFFC42B1C))),
            onPressed: () {
              provider.terminateProcess(proc.pid);
              Navigator.pop(ctx);
            },
            child: const Text('End Task'),
          ),
          Button(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAffinityDialog(
    BuildContext context,
    ProcessInfo proc,
    TaskManProvider provider,
  ) async {
    final currentMask = await provider.getProcessAffinity(proc.pid);
    final coreCount = provider.coreCount;
    int selectedMask = currentMask;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return ContentDialog(
              title: Text('CPU Affinity - ${proc.name} (PID: ${proc.pid})'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select CPU cores this process is allowed to run on:'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(coreCount, (i) {
                        final isSet = (selectedMask & (1 << i)) != 0;
                        return Checkbox(
                          checked: isSet,
                          content: Text('Core $i'),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedMask |= (1 << i);
                              } else {
                                if ((selectedMask & ~(1 << i)) != 0) {
                                  selectedMask &= ~(1 << i);
                                }
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                Button(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
                FilledButton(
                  child: const Text('Apply'),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final ok = await provider.setProcessAffinity(proc.pid, selectedMask);
                    if (context.mounted) {
                      displayInfoBar(
                        context,
                        builder: (c, close) => InfoBar(
                          title: Text(ok ? 'Affinity Applied' : 'Failed'),
                          content: Text(ok
                              ? 'Set CPU affinity mask 0x${selectedMask.toRadixString(16).toUpperCase()}'
                              : 'Access denied'),
                          severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                          onClose: close,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSignatureDialog(BuildContext context, ProcessInfo proc) async {
    final info = await SystemExtendedService.instance.verifyAuthenticodeSignature(proc.fullPath);
    if (!context.mounted) return;

    final isValid = info['status'] == 'Valid';

    showDialog(
      context: context,
      builder: (dialogCtx) => ContentDialog(
        title: Row(
          children: [
            Icon(
              isValid ? FluentIcons.completed_solid : FluentIcons.warning,
              color: isValid ? Colors.green : Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text('Digital Signature: ${proc.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${info['status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Signer: ${info['signer']}'),
            const SizedBox(height: 6),
            Text('Path: ${proc.fullPath.isNotEmpty ? proc.fullPath : "N/A"}',
                style: const TextStyle(fontSize: 11, fontFamily: 'Consolas')),
          ],
        ),
        actions: [
          Button(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }
}
