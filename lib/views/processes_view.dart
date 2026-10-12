import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';
import '../services/system_telemetry_service.dart';

class ProcessesView extends StatelessWidget {
  const ProcessesView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final processes = provider.filteredProcesses;
    final selectedPid = provider.selectedPid;

    ProcessInfo? selectedProc;
    if (selectedPid != null) {
      try {
        selectedProc = processes.firstWhere((p) => p.pid == selectedPid);
      } catch (_) {}
    }

    return Column(
      children: [
        // Top Action Bar: Search, Stats, Always-Visible Action Buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: skin.tileBackground,
            border: Border(bottom: BorderSide(color: skin.tileStroke)),
          ),
          child: Row(
            children: [
              // Search input
              SizedBox(
                width: 200,
                child: TextBox(
                  placeholder: 'Search processes...',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(FluentIcons.search, size: 14),
                  ),
                  onChanged: (text) => provider.setSearchQuery(text),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${processes.length} Processes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: skin.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Open File Location Button (Always Visible)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Button(
                  onPressed: (selectedProc != null && selectedProc.fullPath.isNotEmpty)
                      ? () => provider.openProcessLocation(selectedProc!)
                      : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.open_folder_horizontal, size: 12),
                      SizedBox(width: 5),
                      Text('Open Location'),
                    ],
                  ),
                ),
              ),

              // Search Online Button (Always Visible)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Button(
                  onPressed: selectedProc != null
                      ? () => provider.searchProcessOnline(selectedProc!)
                      : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.globe, size: 12),
                      SizedBox(width: 5),
                      Text('Search Online'),
                    ],
                  ),
                ),
              ),

              // Unlock File / Find Locks Button
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Button(
                  onPressed: () => _showFileUnlockDialog(context, provider),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.lock, size: 12),
                      SizedBox(width: 5),
                      Text('Unlock File'),
                    ],
                  ),
                ),
              ),

              // Priority Selector (Always Visible)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: DropDownButton(
                  disabled: selectedProc == null,
                  title: Text(
                    selectedProc != null ? 'Priority: ${selectedProc.priorityName}' : 'Set Priority',
                    style: const TextStyle(fontSize: 12),
                  ),
                  items: selectedProc != null
                      ? [
                          MenuFlyoutItem(
                            text: const Text('Realtime'),
                            onPressed: () => provider.setPriority(selectedProc!.pid, PRIORITY_REALTIME),
                          ),
                          MenuFlyoutItem(
                            text: const Text('High'),
                            onPressed: () => provider.setPriority(selectedProc!.pid, PRIORITY_HIGH),
                          ),
                          MenuFlyoutItem(
                            text: const Text('Above Normal'),
                            onPressed: () => provider.setPriority(selectedProc!.pid, PRIORITY_ABOVE_NORMAL),
                          ),
                          MenuFlyoutItem(
                            text: const Text('Normal'),
                            onPressed: () => provider.setPriority(selectedProc!.pid, PRIORITY_NORMAL),
                          ),
                          MenuFlyoutItem(
                            text: const Text('Below Normal'),
                            onPressed: () => provider.setPriority(selectedProc!.pid, PRIORITY_BELOW_NORMAL),
                          ),
                          MenuFlyoutItem(
                            text: const Text('Low (Idle)'),
                            onPressed: () => provider.setPriority(selectedProc!.pid, PRIORITY_IDLE),
                          ),
                        ]
                      : [],
                ),
              ),

              // End Process Tree Button (If process selected)
              if (selectedProc != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Button(
                    onPressed: () async {
                      final pid = selectedProc!.pid;
                      final name = selectedProc.name;
                      final ok = await provider.killProcessTree(pid);
                      if (context.mounted) {
                        displayInfoBar(
                          context,
                          builder: (ctx, close) => InfoBar(
                            title: Text(ok ? 'Process Tree Ended' : 'Action Failed'),
                            content: Text(ok ? 'Terminated $name and all child processes' : 'Access denied'),
                            severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                            onClose: close,
                          ),
                        );
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.branch_fork2, size: 12),
                        SizedBox(width: 5),
                        Text('End Tree'),
                      ],
                    ),
                  ),
                ),

              // End Task Button (Always Visible)
              FilledButton(
                onPressed: selectedProc != null
                    ? () {
                        final pidToKill = selectedProc!.pid;
                        final name = selectedProc.name;
                        void doKill() {
                          final ok = provider.terminateProcess(pidToKill);
                          displayInfoBar(
                            context,
                            builder: (context, close) {
                              return InfoBar(
                                title: Text(ok ? 'Process Ended' : 'Action Failed'),
                                content: Text(
                                  ok
                                      ? 'Successfully terminated $name ($pidToKill)'
                                      : 'Access denied or unable to terminate $name',
                                ),
                                severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                                onClose: close,
                              );
                            },
                          );
                        }

                        if (provider.confirmKill) {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => ContentDialog(
                              title: const Text('End Process?'),
                              content: Text('Are you sure you want to terminate "$name" (PID: $pidToKill)?\nUnsaved data may be lost.'),
                              actions: [
                                Button(
                                  child: const Text('Cancel'),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                ),
                                FilledButton(
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(Colors.red),
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
                      }
                    : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.isDisabled) return null;
                    return Colors.red;
                  }),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 12),
                    SizedBox(width: 5),
                    Text('End Task'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),

        // Process Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: skin.headerBackground.withValues(alpha: 0.5),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => provider.setSort(ProcessSortField.name),
                  child: Row(
                    children: [
                      Text('Name', style: _headerStyle(skin)),
                      _sortIcon(provider, ProcessSortField.name),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => provider.setSort(ProcessSortField.pid),
                  child: Row(
                    children: [
                      Text('PID', style: _headerStyle(skin)),
                      _sortIcon(provider, ProcessSortField.pid),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => provider.setSort(ProcessSortField.memory),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Memory', style: _headerStyle(skin)),
                      _sortIcon(provider, ProcessSortField.memory),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Priority', style: _headerStyle(skin)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Process List
        Expanded(
          child: processes.isEmpty
              ? Center(
                  child: Text(
                    'No processes found',
                    style: TextStyle(color: skin.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: processes.length,
                  itemExtent: 36,
                  itemBuilder: (context, index) {
                    final proc = processes[index];
                    final isSelected = proc.pid == selectedPid;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => provider.selectPid(proc.pid),
                      onSecondaryTapDown: (details) {
                        provider.selectPid(proc.pid);
                        _showRowContextMenu(context, details.globalPosition, proc, provider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? skin.textAccent.withValues(alpha: 0.22)
                              : (index.isEven
                                  ? skin.tileBackground.withValues(alpha: 0.35)
                                  : Colors.transparent),
                          border: isSelected
                              ? Border(
                                  left: BorderSide(color: skin.textAccent, width: 3.0),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Icon + Name
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Icon(
                                    proc.name.endsWith('.exe')
                                        ? FluentIcons.app_icon_default
                                        : FluentIcons.page,
                                    size: 14,
                                    color: isSelected ? skin.textAccent : skin.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      proc.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? skin.textAccent : skin.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // PID
                            Expanded(
                              flex: 2,
                              child: Text(
                                proc.pid.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Consolas',
                                  color: isSelected ? skin.textPrimary : skin.textSecondary,
                                ),
                              ),
                            ),
                            // Memory
                            Expanded(
                              flex: 3,
                              child: Text(
                                proc.formattedMemory,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Consolas',
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? skin.textAccent : skin.textPrimary,
                                ),
                              ),
                            ),
                            // Priority
                            Expanded(
                              flex: 2,
                              child: Text(
                                proc.priorityName,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Consolas',
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: proc.priorityClass == PRIORITY_HIGH || proc.priorityClass == PRIORITY_REALTIME
                                      ? Colors.warningPrimaryColor
                                      : skin.textSecondary,
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

        // Selected Process Detail Status Bar at Bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: skin.tileBackground,
            border: Border(top: BorderSide(color: skin.tileStroke)),
          ),
          child: Row(
            children: [
              if (selectedProc != null) ...[
                Icon(FluentIcons.info, size: 13, color: skin.textAccent),
                const SizedBox(width: 8),
                Text(
                  '${selectedProc.name} (PID: ${selectedProc.pid})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: skin.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'RAM: ${selectedProc.formattedMemory}  |  Priority: ${selectedProc.priorityName}',
                  style: TextStyle(fontSize: 11, color: skin.textSecondary),
                ),
                if (selectedProc.fullPath.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedProc.fullPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        color: skin.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Icon(FluentIcons.touch, size: 13, color: skin.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Click or right-click any process in the list to inspect, change priority, open location, or end task.',
                  style: TextStyle(fontSize: 11, color: skin.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showRowContextMenu(
    BuildContext context,
    Offset position,
    ProcessInfo proc,
    TaskManProvider provider,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned(
              left: position.dx.clamp(20.0, MediaQuery.of(dialogContext).size.width - 240),
              top: position.dy.clamp(20.0, MediaQuery.of(dialogContext).size.height - 220),
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: provider.currentSkin.tileBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: provider.currentSkin.tileStroke),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(FluentIcons.open_folder_horizontal, size: 12),
                      title: const Text('Open File Location', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        provider.openProcessLocation(proc);
                        Navigator.pop(dialogContext);
                      },
                    ),
                    ListTile(
                      leading: const Icon(FluentIcons.globe, size: 12),
                      title: const Text('Search Online', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        provider.searchProcessOnline(proc);
                        Navigator.pop(dialogContext);
                      },
                    ),
                    ListTile(
                      leading: const Icon(FluentIcons.shield, size: 12),
                      title: const Text('Check VirusTotal', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        provider.searchVirusTotal(proc);
                        Navigator.pop(dialogContext);
                      },
                    ),
                    ListTile(
                      leading: const Icon(FluentIcons.certificate, size: 12),
                      title: const Text('Verify Signature', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showSignatureDialog(context, proc);
                      },
                    ),
                    ListTile(
                      leading: const Icon(FluentIcons.speed_high, size: 12),
                      title: const Text('Set CPU Affinity...', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showAffinityDialog(context, proc, provider);
                      },
                    ),
                    ListTile(
                      leading: Icon(FluentIcons.branch_fork2, size: 12, color: Colors.orange),
                      title: Text('End Process Tree', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final ok = await provider.killProcessTree(proc.pid);
                        if (context.mounted) {
                          displayInfoBar(
                            context,
                            builder: (ctx, close) => InfoBar(
                              title: Text(ok ? 'Process Tree Ended' : 'Action Failed'),
                              content: Text(ok ? 'Terminated ${proc.name} and children' : 'Access denied'),
                              severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                              onClose: close,
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(FluentIcons.delete, size: 12, color: Colors.red),
                      title: Text('End Task', style: TextStyle(fontSize: 12, color: Colors.red)),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        final pidToKill = proc.pid;
                        final name = proc.name;
                        void doKill() {
                          final ok = provider.terminateProcess(pidToKill);
                          displayInfoBar(
                            context,
                            builder: (ctx, close) => InfoBar(
                              title: Text(ok ? 'Process Ended' : 'Action Failed'),
                              content: Text(ok ? 'Successfully terminated $name ($pidToKill)' : 'Access denied for $name'),
                              severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
                              onClose: close,
                            ),
                          );
                        }

                        if (provider.confirmKill) {
                          showDialog(
                            context: context,
                            builder: (confirmCtx) => ContentDialog(
                              title: const Text('End Process?'),
                              content: Text('Are you sure you want to terminate "$name" (PID: $pidToKill)?\nUnsaved data may be lost.'),
                              actions: [
                                Button(
                                  child: const Text('Cancel'),
                                  onPressed: () => Navigator.pop(confirmCtx),
                                ),
                                FilledButton(
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(Colors.red),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(confirmCtx);
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
                          content: Text(ok ? 'Set CPU affinity mask 0x${selectedMask.toRadixString(16).toUpperCase()}' : 'Access denied'),
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
            Text('Path: ${proc.fullPath.isNotEmpty ? proc.fullPath : "N/A"}', style: const TextStyle(fontSize: 11, fontFamily: 'Consolas')),
          ],
        ),
        actions: [
          Button(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          FilledButton(
            child: const Text('Check VirusTotal'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<TaskManProvider>().searchVirusTotal(proc);
            },
          ),
        ],
      ),
    );
  }

  void _showFileUnlockDialog(BuildContext context, TaskManProvider provider) {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return ContentDialog(
              title: const Row(
                children: [
                  Icon(FluentIcons.lock, size: 16),
                  SizedBox(width: 8),
                  Text('Find Locking Processes (Handle Search)'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter file or directory path to see what process is locking it:'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: controller,
                            placeholder: r'e.g. C:\MyFolder\locked_file.dll',
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSearching
                              ? null
                              : () async {
                                  if (controller.text.trim().isEmpty) return;
                                  setState(() => isSearching = true);
                                  final res = await SystemExtendedService.instance.searchLockingProcesses(controller.text.trim());
                                  setState(() {
                                    results = res;
                                    isSearching = false;
                                  });
                                },
                          child: isSearching
                              ? const SizedBox(width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
                              : const Text('Search'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (results.isEmpty && !isSearching)
                      const Text('No locking processes found.', style: TextStyle(color: Colors.grey))
                    else
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (c, i) {
                            final item = results[i];
                            final pid = item['Id'] as int? ?? 0;
                            final name = item['ProcessName']?.toString() ?? 'Process';
                            return ListTile(
                              title: Text('$name (PID: $pid)'),
                              trailing: Button(
                                child: Text('End Process', style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  provider.terminateProcess(pid);
                                  setState(() => results.removeAt(i));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Button(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            );
          },
        );
      },
    );
  }

  TextStyle _headerStyle(dynamic skin) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: skin.textSecondary,
      letterSpacing: 0.5,
    );
  }

  Widget _sortIcon(TaskManProvider provider, ProcessSortField field) {
    if (provider.sortField != field) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        provider.sortAscending ? FluentIcons.chevron_up_small : FluentIcons.chevron_down_small,
        size: 10,
      ),
    );
  }
}
