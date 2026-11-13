import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../services/gpu_taskman_service.dart';
import '../services/system_telemetry_service.dart';
import '../widgets/trace_graph.dart';

class GpuInspectorView extends StatefulWidget {
  const GpuInspectorView({super.key});

  @override
  State<GpuInspectorView> createState() => _GpuInspectorViewState();
}

class _GpuInspectorViewState extends State<GpuInspectorView> {
  String _search = '';
  String _sortColumn = 'vram';
  bool _sortAsc = false;
  int? _selectedPid;
  bool _showAllProcesses = false;
  GgufModelInfo? _inspectedGguf;
  String? _inspectedGgufPath;
  GpuSnapshot? _baselineSnapshot;
  Map<int, String> _baselineProcessNames = const {};
  DateTime? _baselineTimestamp;
  Map<String, Map<String, int>>? _ollamaLogBuffers;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final metrics = provider.latestMetrics;
    final gpuSnap = metrics?.gpuSnapshot;
    final adapters = gpuSnap?.adapters ?? const <AdapterGpuTelemetry>[];
    final activeAdapter = provider.activeGpuAdapter;
    final gpuChannel = skin.getChannel('gpu');

    final allProcs = metrics?.processes ?? const <ProcessInfo>[];
    final gpuProcs = allProcs.where((p) {
      if (!_showAllProcesses) {
        final hasGpu = p.gpuDedicatedBytes > 0 ||
            p.gpuSharedBytes > 0 ||
            p.gpuCommittedBytes > 0 ||
            p.gpuPercent > 0.0 ||
            p.gpuRuntimes.isNotEmpty;
        if (!hasGpu) return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.pid.toString().contains(q) ||
            p.gpuCategory.toLowerCase().contains(q) ||
            p.gpuRuntimes.any((r) => r.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    gpuProcs.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'pid':
          cmp = a.pid.compareTo(b.pid);
          break;
        case 'shared':
          cmp = a.gpuSharedBytes.compareTo(b.gpuSharedBytes);
          break;
        case 'paged':
          cmp = a.gpuPagedBytes.compareTo(b.gpuPagedBytes);
          break;
        case 'gpu':
          cmp = a.gpuPercent.compareTo(b.gpuPercent);
          break;
        case 'vram':
        default:
          cmp = a.gpuDedicatedBytes.compareTo(b.gpuDedicatedBytes);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });

    ProcessInfo? selectedProc;
    if (_selectedPid != null) {
      for (final p in gpuProcs) {
        if (p.pid == _selectedPid) {
          selectedProc = p;
          break;
        }
      }
    }
    selectedProc ??= gpuProcs.isNotEmpty ? gpuProcs.first : null;

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.processing, size: 20, color: gpuChannel.accent),
            const SizedBox(width: 8),
            Text(
              'GPU & AI Inspector',
              style: TextStyle(
                color: skin.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 10),
            if (activeAdapter != null) ...[
              _badge(
                activeAdapter.adapter.vendorName,
                gpuChannel.accent,
              ),
              const SizedBox(width: 8),
              if (adapters.length > 1)
                Flexible(
                  child: ComboBox<int>(
                    value: provider.selectedGpuIndex.clamp(0, adapters.length - 1),
                    items: List.generate(adapters.length, (i) {
                      final a = adapters[i].adapter;
                      return ComboBoxItem<int>(
                        value: i,
                        child: Text(
                          'GPU $i: ${a.name}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }),
                    onChanged: (idx) {
                      if (idx != null) provider.selectGpuIndex(idx);
                    },
                  ),
                )
              else
                Expanded(
                  child: Text(
                    activeAdapter.adapter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: skin.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
        commandBar: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                onPressed: gpuSnap == null
                    ? null
                    : () {
                        final names = {for (final p in allProcs) p.pid: p.name};
                        setState(() {
                          _baselineSnapshot = gpuSnap;
                          _baselineProcessNames = names;
                          _baselineTimestamp = DateTime.now();
                        });
                        displayInfoBar(
                          context,
                          builder: (ctx, close) => InfoBar(
                            title: const Text('GPU Baseline Captured'),
                            content: Text(
                              'Captured ${gpuSnap.processMap.length} GPU processes. Load or close an app/model, then click "Compare Diff".',
                            ),
                            severity: InfoBarSeverity.info,
                            onClose: close,
                          ),
                        );
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FluentIcons.pin, size: 13),
                    const SizedBox(width: 5),
                    Text(_baselineSnapshot == null ? 'Baseline' : 'Re-Capture'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Button(
                onPressed: (_baselineSnapshot != null && gpuSnap != null)
                    ? () => _showSnapshotDiffDialog(context, gpuSnap, allProcs, provider.selectedGpuIndex, skin, gpuChannel)
                    : null,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.history, size: 13),
                    SizedBox(width: 5),
                    Text('Compare Diff'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Button(
                onPressed: () => _showGgufInspectDialog(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.document_search, size: 13),
                    SizedBox(width: 5),
                    Text('Inspect .gguf'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ToggleButton(
                checked: provider.gpuSlimMode,
                onChanged: (_) => provider.toggleGpuSlimMode(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.gpuSlimMode ? FluentIcons.expand_all : FluentIcons.collapse_content,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(provider.gpuSlimMode ? 'Full Mode' : 'Slim Mode'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Adapter & WDDM VRAM Attribution Card
            if (activeAdapter != null) _buildAdapterCard(activeAdapter, skin, gpuChannel),
            const SizedBox(height: 10),

            // Engine Activity & History Strip (hidden in Slim Mode)
            if (!provider.gpuSlimMode) ...[
              SizedBox(
                height: 145,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TraceGraph(
                        title: 'GPU Core',
                        currentValText: '${(activeAdapter?.gpuUtilizationPercent ?? 0).toStringAsFixed(1)}%',
                        history: provider.gpuUtilizationHistory,
                        channelColor: gpuChannel,
                        maxY: 100.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 280,
                      child: TraceGraph(
                        title: 'VRAM Usage',
                        currentValText: '${(activeAdapter?.vramUsagePercent ?? 0).toStringAsFixed(1)}%',
                        history: provider.gpuVramHistory,
                        channelColor: skin.getChannel('memory'),
                        maxY: 100.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 280,
                      child: TraceGraph(
                        title: '3D / Graphics',
                        currentValText: '${(activeAdapter?.engineUtilization['3d'] ?? 0).toStringAsFixed(1)}%',
                        history: provider.gpu3dHistory,
                        channelColor: skin.getChannel('cpu'),
                        maxY: 100.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 280,
                      child: TraceGraph(
                        title: 'Compute / CUDA',
                        currentValText: '${(activeAdapter?.engineUtilization['compute'] ?? 0).toStringAsFixed(1)}%',
                        history: provider.gpuComputeHistory,
                        channelColor: skin.getChannel('disk'),
                        maxY: 100.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 280,
                      child: TraceGraph(
                        title: 'Copy / DMA',
                        currentValText: '${(activeAdapter?.engineUtilization['copy'] ?? 0).toStringAsFixed(1)}%',
                        history: provider.gpuCopyHistory,
                        channelColor: skin.getChannel('network'),
                        maxY: 100.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 280,
                      child: TraceGraph(
                        title: 'Video Enc/Dec',
                        currentValText: '${[
                          activeAdapter?.engineUtilization['decode'] ?? 0,
                          activeAdapter?.engineUtilization['encode'] ?? 0,
                        ].reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}%',
                        history: provider.gpuVideoHistory,
                        channelColor: gpuChannel,
                        maxY: 100.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Split Bottom Area: Per-Process WDDM GPU Table + Selected Process Inspector
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left/Main: WDDM GPU Process Table
                  Expanded(
                    flex: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: skin.tileBackground,
                        borderRadius: BorderRadius.circular(skin.tileCornerRadius),
                        border: Border.all(color: skin.tileStroke),
                      ),
                      child: Column(
                        children: [
                          // Filter toolbar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 240,
                                  child: TextBox(
                                    placeholder: 'Filter by process, PID, runtime...',
                                    prefix: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(FluentIcons.search, size: 13),
                                    ),
                                    onChanged: (v) => setState(() => _search = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Checkbox(
                                  checked: _showAllProcesses,
                                  onChanged: (v) => setState(() => _showAllProcesses = v ?? false),
                                  content: Text(
                                    'Show idle processes',
                                    style: TextStyle(fontSize: 11, color: skin.textSecondary),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${gpuProcs.length} GPU Processes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: skin.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            color: skin.headerBackground.withValues(alpha: 0.55),
                            child: Row(
                              children: [
                                _headerCell('Process', 'name', flex: 3, skin: skin),
                                _headerCell('PID', 'pid', flex: 1, skin: skin),
                                _headerCell('Category / Runtimes', '', flex: 3, skin: skin),
                                _headerCell('VRAM (Local)', 'vram', flex: 2, skin: skin, rightAlign: true),
                                _headerCell('Shared (Spill)', 'shared', flex: 2, skin: skin, rightAlign: true),
                                _headerCell('Paged (Est.)', 'paged', flex: 2, skin: skin, rightAlign: true),
                                _headerCell('GPU %', 'gpu', flex: 1, skin: skin, rightAlign: true),
                              ],
                            ),
                          ),
                          // Rows
                          Expanded(
                            child: gpuProcs.isEmpty
                                ? Center(
                                    child: Text(
                                      'No active GPU processes matching filter.',
                                      style: TextStyle(color: skin.textSecondary, fontSize: 12),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: gpuProcs.length,
                                    itemExtent: 38,
                                    itemBuilder: (context, index) {
                                      final proc = gpuProcs[index];
                                      final isSel = selectedProc?.pid == proc.pid;
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(() => _selectedPid = proc.pid),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: isSel
                                                ? gpuChannel.accent.withValues(alpha: 0.18)
                                                : (index.isEven
                                                    ? skin.windowBackground.withValues(alpha: 0.25)
                                                    : Colors.transparent),
                                            border: isSel
                                                ? Border(left: BorderSide(color: gpuChannel.accent, width: 3))
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  proc.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                                    color: isSel ? gpuChannel.accent : skin.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  '${proc.pid}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'Consolas',
                                                    color: skin.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    if (proc.gpuCategory.isNotEmpty)
                                                      _miniTag(proc.gpuCategory, gpuChannel.accent),
                                                    if (proc.gpuRuntimes.isNotEmpty) ...[
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          proc.gpuRuntimes.take(2).join(', '),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: skin.textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  proc.formattedGpuVram,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'Consolas',
                                                    fontWeight: FontWeight.w600,
                                                    color: proc.gpuDedicatedBytes > 0
                                                        ? skin.textPrimary
                                                        : skin.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  proc.formattedGpuShared,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'Consolas',
                                                    color: proc.gpuSharedBytes > (256 * 1024 * 1024)
                                                        ? const Color(0xFFFFB900)
                                                        : skin.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  proc.formattedGpuPaged,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'Consolas',
                                                    color: skin.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  '${proc.gpuPercent.toStringAsFixed(1)}%',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'Consolas',
                                                    fontWeight: proc.gpuPercent > 5.0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: proc.gpuPercent > 5.0
                                                        ? gpuChannel.accent
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right: Process GPU & AI Inspector Panel
                  Expanded(
                    flex: 4,
                    child: _buildInspectorPanel(selectedProc, skin, gpuChannel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdapterCard(AdapterGpuTelemetry adapter, SkinTheme skin, ChannelColor gpuChannel) {
    final info = adapter.adapter;
    final usedStr = GpuTaskManService.formatBytes(adapter.dedicatedUsedBytes);
    final totalStr = GpuTaskManService.formatBytes(info.dedicatedVramBytes);
    final attrStr = GpuTaskManService.formatBytes(adapter.attributedVramBytes);
    final unattrStr = GpuTaskManService.formatBytes(adapter.unattributedVramBytes);
    final sharedUsedStr = GpuTaskManService.formatBytes(adapter.sharedUsedBytes);
    final sharedCapStr = GpuTaskManService.formatBytes(info.sharedSystemBytes);
    final ratio = (adapter.vramUsagePercent / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        borderRadius: BorderRadius.circular(skin.tileCornerRadius),
        border: Border.all(color: skin.tileStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'DEDICATED VRAM: $usedStr / $totalStr (${adapter.vramUsagePercent.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Consolas',
                  color: skin.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'LUID: ${info.formattedLuid}',
                style: TextStyle(fontSize: 11, fontFamily: 'Consolas', color: skin.textSecondary),
              ),
              if (info.isIntegratedIntel) ...[
                const SizedBox(width: 8),
                _badge('Integrated (DXGI Heuristic)', const Color(0xFFFFB900)),
              ],
              const Spacer(),
              Text(
                'GPU Busy: ${adapter.gpuUtilizationPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Consolas',
                  color: gpuChannel.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: skin.windowBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: gpuChannel.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              _statChip('Attributed (Local Usage)', attrStr, skin),
              _statChip('Unattributed / Kernel', unattrStr, skin),
              _statChip('Shared System Spill', '$sharedUsedStr / $sharedCapStr', skin),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorPanel(ProcessInfo? proc, SkinTheme skin, ChannelColor gpuChannel) {
    final modelInfo = proc?.gpuModelInfo ?? _inspectedGguf;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        borderRadius: BorderRadius.circular(skin.tileCornerRadius),
        border: Border.all(color: skin.tileStroke),
      ),
      child: proc == null
          ? Center(
              child: Text(
                'Select a process to inspect its WDDM memory breakdown, engines, and loaded AI/GPU runtimes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: skin.textSecondary, fontSize: 12),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(FluentIcons.info, size: 15, color: gpuChannel.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${proc.name} (PID ${proc.pid})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: skin.textPrimary,
                          ),
                        ),
                      ),
                      if (proc.gpuCategory.isNotEmpty) _badge(proc.gpuCategory, gpuChannel.accent),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Section 1: WDDM Memory Accounting
                  Text(
                    'WDDM MEMORY ACCOUNTING',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: skin.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _kvRow('Local Usage (Dedicated VRAM)', proc.formattedGpuVram, skin),
                  _kvRow('Non Local Usage (Shared Spill)', proc.formattedGpuShared, skin),
                  _kvRow('Total Committed', GpuTaskManService.formatBytes(proc.gpuCommittedBytes), skin),
                  _kvRow('Estimated Paged Out', proc.formattedGpuPaged, skin),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: skin.windowBackground.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: skin.tileStroke),
                    ),
                    child: Text(
                      proc.name.toLowerCase() == 'dwm.exe'
                          ? 'Note: Local Usage isolates private VRAM charged to dwm.exe so shared desktop surfaces are not double-counted against applications.'
                          : (proc.gpuSharedBytes > 128 * 1024 * 1024
                              ? 'Note: Non Local Usage is GPU-accessible system RAM (pinned host buffers or VRAM spill).'
                              : 'Note: Paged Out = max(Committed - Local - Non Local, 0), a non-residency estimate rather than an eviction trace.'),
                      style: TextStyle(fontSize: 10.5, color: skin.textSecondary),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Section 2: Per-Engine Breakdown
                  Text(
                    'PER-ENGINE UTILIZATION',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: skin.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _engineBar('3D / Graphics', proc.enginesValue('3d'), gpuChannel.accent, skin),
                  _engineBar('Compute / CUDA', proc.enginesValue('compute'), skin.getChannel('disk').accent, skin),
                  _engineBar('Copy / DMA', proc.enginesValue('copy'), skin.getChannel('cpu').accent, skin),
                  _engineBar('Video Decode', proc.enginesValue('decode'), skin.getChannel('network').accent, skin),
                  _engineBar('Video Encode', proc.enginesValue('encode'), skin.getChannel('memory').accent, skin),

                  const SizedBox(height: 14),

                  // Section 3: Loaded Runtimes
                  Text(
                    'LOADED GPU & AI RUNTIMES',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: skin.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (proc.gpuRuntimes.isEmpty)
                    Text(
                      'No GPU/AI runtime DLLs enumerated (or process is protected).',
                      style: TextStyle(fontSize: 11, color: skin.textSecondary),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: proc.gpuRuntimes.map((rt) => _badge(rt, skin.textAccent)).toList(),
                    ),

                  const SizedBox(height: 14),

                  // Section 4: LLM / GGUF Breakdown
                  Row(
                    children: [
                      Text(
                        'AI / GGUF MODEL INSPECTOR',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: skin.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (_inspectedGguf != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _inspectedGguf = null;
                            _inspectedGgufPath = null;
                          }),
                          child: Text(
                            'Clear',
                            style: TextStyle(fontSize: 10.5, color: skin.textAccent),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (modelInfo != null) ...[
                    _kvRow('Model Name', modelInfo.fileName, skin),
                    if (_inspectedGgufPath != null)
                      if (GpuTaskManService.resolveModelStoreFriendlyName(_inspectedGgufPath!)
                          case final storeName?)
                        _kvRow('Model Store', storeName, skin),
                    _kvRow('Architecture', modelInfo.architecture, skin),
                    _kvRow('Quantization', modelInfo.quantization, skin),
                    _kvRow('Est. Weights', GpuTaskManService.formatBytes(modelInfo.estimatedWeightsBytes), skin),
                    _kvRow('Est. KV Cache (4K ctx)', GpuTaskManService.formatBytes(modelInfo.estimatedKvCacheBytes), skin),
                    _kvRow('Est. Compute Buffer', GpuTaskManService.formatBytes(modelInfo.estimatedComputeBytes), skin),
                    _kvRow('Evidence', modelInfo.evidence, skin),
                  ] else
                    Text(
                      'Use "Inspect .gguf..." above to parse any local GGUF header and estimate Weights vs. KV Cache vs. Compute buffers.',
                      style: TextStyle(fontSize: 11, color: skin.textSecondary),
                    ),
                  if (proc.gpuCategory == 'LLM / AI' || _ollamaLogBuffers != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'OLLAMA / LLAMA.CPP LOAD LOG',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: skin.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Button(
                          onPressed: () {
                            final parsed = GpuTaskManService.readOllamaServerLogBuffers();
                            setState(() => _ollamaLogBuffers = parsed);
                            if (parsed == null && mounted) {
                              displayInfoBar(
                                context,
                                builder: (ctx, close) => InfoBar(
                                  title: const Text('No Ollama Log Buffers Found'),
                                  content: const Text(r'Checked %LOCALAPPDATA%\Ollama\server.log for recent model/KV allocations.'),
                                  severity: InfoBarSeverity.info,
                                  onClose: close,
                                ),
                              );
                            }
                          },
                          child: const Text('Probe Server Log', style: TextStyle(fontSize: 10.5)),
                        ),
                      ],
                    ),
                    if (_ollamaLogBuffers != null) ...[
                      const SizedBox(height: 6),
                      for (final entry in _ollamaLogBuffers!.entries)
                        _kvRow(
                          '${entry.key} (W / KV / C)',
                          '${GpuTaskManService.formatBytes(entry.value['weights'] ?? 0)} / '
                              '${GpuTaskManService.formatBytes(entry.value['kv'] ?? 0)} / '
                              '${GpuTaskManService.formatBytes(entry.value['compute'] ?? 0)}',
                          skin,
                        ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  void _showSnapshotDiffDialog(
    BuildContext context,
    GpuSnapshot currentSnap,
    List<ProcessInfo> currentProcs,
    int adapterIndex,
    SkinTheme skin,
    ChannelColor gpuChannel,
  ) {
    final currentNames = {for (final p in currentProcs) p.pid: p.name};
    final diff = GpuTaskManService.diffSnapshots(
      _baselineSnapshot!,
      currentSnap,
      adapterIndex: adapterIndex,
      beforeNames: _baselineProcessNames,
      afterNames: currentNames,
    );

    bool filterNoise = true;
    String formatSignedBytes(int delta) {
      if (delta == 0) return '0 B';
      final sign = delta > 0 ? '+' : '-';
      return '$sign${GpuTaskManService.formatBytes(delta.abs())}';
    }

    Color deltaColor(int delta) {
      if (delta > 0) return const Color(0xFFFF7043);
      if (delta < 0) return const Color(0xFF00E676);
      return skin.textSecondary;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final rows = filterNoise ? diff.significantProcesses() : diff.processes;
          return ContentDialog(
            constraints: const BoxConstraints(maxWidth: 780, maxHeight: 560),
            title: Row(
              children: [
                Icon(FluentIcons.history, size: 18, color: gpuChannel.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GPU Snapshot Diff — ${diff.adapterName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_baselineTimestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Comparing baseline captured at '
                      '${_baselineTimestamp!.hour.toString().padLeft(2, '0')}:'
                      '${_baselineTimestamp!.minute.toString().padLeft(2, '0')}:'
                      '${_baselineTimestamp!.second.toString().padLeft(2, '0')} -> Live',
                      style: TextStyle(fontSize: 11.5, color: skin.textSecondary),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: skin.windowBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: skin.tileStroke),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _diffStat('Dedicated Δ', formatSignedBytes(diff.dedicatedDelta), deltaColor(diff.dedicatedDelta), skin),
                      _diffStat('Shared Δ', formatSignedBytes(diff.sharedDelta), deltaColor(diff.sharedDelta), skin),
                      _diffStat('Attributed Δ', formatSignedBytes(diff.attributedDelta), deltaColor(diff.attributedDelta), skin),
                      _diffStat('Unattributed Δ', formatSignedBytes(diff.unattributedDelta), deltaColor(diff.unattributedDelta), skin),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      checked: filterNoise,
                      onChanged: (v) => setDialogState(() => filterNoise = v ?? true),
                      content: const Text('Hide changes < 16 MB (WDDM noise filter)', style: TextStyle(fontSize: 12)),
                    ),
                    const Spacer(),
                    Text('${rows.length} process(es)', style: TextStyle(fontSize: 11.5, color: skin.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            'No GPU memory changes detected above threshold.',
                            style: TextStyle(color: skin.textSecondary, fontSize: 12),
                          ),
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, idx) {
                            final r = rows[idx];
                            final badgeColor = r.status == 'new'
                                ? const Color(0xFF00E676)
                                : (r.status == 'gone' ? Colors.orange : gpuChannel.accent);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        _badge(r.status.toUpperCase(), badgeColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: skin.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Ded: ${formatSignedBytes(r.dedicatedDelta)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'Consolas',
                                        fontWeight: FontWeight.bold,
                                        color: deltaColor(r.dedicatedDelta),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Shr: ${formatSignedBytes(r.sharedDelta)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'Consolas',
                                        color: deltaColor(r.sharedDelta),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Com: ${formatSignedBytes(r.committedDelta)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'Consolas',
                                        color: deltaColor(r.committedDelta),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _diffStat(String label, String value, Color valueColor, SkinTheme skin) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: skin.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontFamily: 'Consolas',
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showGgufInspectDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => ContentDialog(
        title: const Text('Inspect Local GGUF Model Header'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the full path to a .gguf file to parse its metadata and estimate VRAM breakdown:'),
            const SizedBox(height: 10),
            TextBox(
              controller: controller,
              placeholder: r'e.g. C:\models\qwen2.5-7b-instruct-q4_k_m.gguf',
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final path = controller.text.trim().replaceAll('"', '');
              final info = GpuTaskManService.inspectGgufFile(path);
              Navigator.pop(dialogCtx);
              if (info != null) {
                setState(() {
                  _inspectedGguf = info;
                  _inspectedGgufPath = path;
                });
              } else if (context.mounted) {
                displayInfoBar(
                  context,
                  builder: (ctx, close) => InfoBar(
                    title: const Text('Invalid GGUF File'),
                    content: Text('Could not read a valid GGUF header from "$path".'),
                    severity: InfoBarSeverity.warning,
                    onClose: close,
                  ),
                );
              }
            },
            child: const Text('Inspect'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String val, SkinTheme skin) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 11, color: skin.textSecondary)),
        Text(
          val,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Consolas',
            color: skin.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _kvRow(String k, String v, SkinTheme skin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(k, style: TextStyle(fontSize: 11.5, color: skin.textSecondary)),
          ),
          const SizedBox(width: 8),
          Text(
            v,
            style: TextStyle(
              fontSize: 11.5,
              fontFamily: 'Consolas',
              fontWeight: FontWeight.bold,
              color: skin.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _engineBar(String label, double pct, Color color, SkinTheme skin) {
    final ratio = (pct / 100.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(label, style: TextStyle(fontSize: 11, color: skin.textSecondary)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                height: 6,
                decoration: BoxDecoration(
                  color: skin.windowBackground,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10.5, fontFamily: 'Consolas', color: skin.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _headerCell(
    String title,
    String colKey, {
    required int flex,
    required SkinTheme skin,
    bool rightAlign = false,
  }) {
    final isSorted = colKey.isNotEmpty && _sortColumn == colKey;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
        child: Row(
          mainAxisAlignment: rightAlign ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSorted ? skin.textAccent : skin.textSecondary,
                ),
              ),
            ),
            if (isSorted) ...[
              const SizedBox(width: 3),
              Icon(
                _sortAsc ? FluentIcons.chevron_up_small : FluentIcons.chevron_down_small,
                size: 10,
                color: skin.textAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _ProcGpuExt on ProcessInfo {
  double enginesValue(String key) => gpuEngines[key] ?? 0.0;
}
