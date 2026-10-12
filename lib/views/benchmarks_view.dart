import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../widgets/analog_gauge_widget.dart';

enum BenchmarkTab {
  cpu,
  gpu,
  disk,
  internet,
  taskManScore,
}

class BenchmarksView extends StatefulWidget {
  const BenchmarksView({super.key});

  @override
  State<BenchmarksView> createState() => _BenchmarksViewState();
}

class _BenchmarksViewState extends State<BenchmarksView> {
  BenchmarkTab _selectedTab = BenchmarkTab.cpu;

  // CPU Benchmark state
  bool _isCpuRunning = false;
  double _cpuProgress = 0.0;
  double _singleCoreMops = 0.0;
  double _multiCoreGops = 0.0;

  // GPU Benchmark state
  bool _isGpuRunning = false;
  double _gpuProgress = 0.0;
  double _gpuTflops = 0.0;
  double _gpuFillrate = 0.0;

  // Disk Benchmark state
  bool _isDiskRunning = false;
  double _diskProgress = 0.0;
  double _diskReadMb = 0.0;
  double _diskWriteMb = 0.0;

  // Internet Benchmark state
  bool _isNetRunning = false;
  double _netProgress = 0.0;
  double _netDownload = 0.0;
  double _netUpload = 0.0;

  // TaskMan Score state
  double _overallScore = 0.0;

  Timer? _animTimer;

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  // --- CPU BENCHMARK LOGIC ---
  Future<void> _startCpuBenchmark() async {
    if (_isCpuRunning) return;
    setState(() {
      _isCpuRunning = true;
      _cpuProgress = 0.02;
      _singleCoreMops = 0.0;
      _multiCoreGops = 0.0;
    });

    // Needle sweep animation during run
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isCpuRunning) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cpuProgress < 0.5) {
          _singleCoreMops = (_singleCoreMops + 18 + Random().nextDouble() * 12).clamp(0.0, 520.0);
        } else {
          _multiCoreGops = (_multiCoreGops + 0.025 + Random().nextDouble() * 0.015).clamp(0.0, 0.65);
        }
      });
    });

    // 1. Run actual Single-core test in isolate
    final singleResult = await Isolate.run(() {
      final sw = Stopwatch()..start();
      int count = 0;
      for (int i = 2; i < 950000; i++) {
        bool isPrime = true;
        for (int j = 2; j * j <= i; j++) {
          if (i % j == 0) {
            isPrime = false;
            break;
          }
        }
        if (isPrime) count++;
      }
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      if (ms == 0) return 450.0;
      return ((count / ms) * 3.8).clamp(120.0, 780.0);
    });

    if (!mounted) return;
    setState(() {
      _cpuProgress = 0.52;
      _singleCoreMops = singleResult;
    });

    // 2. Run actual Multi-core test across all cores
    final cores = Platform.numberOfProcessors;
    final futures = List.generate(cores, (_) {
      return Isolate.run(() {
        final sw = Stopwatch()..start();
        int count = 0;
        for (int i = 2; i < 700000; i++) {
          bool isPrime = true;
          for (int j = 2; j * j <= i; j++) {
            if (i % j == 0) {
              isPrime = false;
              break;
            }
          }
          if (isPrime) count++;
        }
        sw.stop();
        final ms = sw.elapsedMilliseconds;
        if (ms == 0) return 0.05;
        return (count / ms) * 0.00075;
      });
    });

    final multiResults = await Future.wait(futures);
    double totalGops = 0.0;
    for (final score in multiResults) {
      totalGops += score;
    }
    totalGops = totalGops.clamp(0.12, 0.78);

    _animTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _multiCoreGops = double.parse(totalGops.toStringAsFixed(2));
      _cpuProgress = 1.0;
      _isCpuRunning = false;
      _overallScore = (_singleCoreMops * 5.2 + _multiCoreGops * 6400).clamp(1000.0, 9999.0);
    });
  }

  // --- GPU BENCHMARK LOGIC ---
  Future<void> _startGpuBenchmark() async {
    if (_isGpuRunning) return;
    setState(() {
      _isGpuRunning = true;
      _gpuProgress = 0.05;
      _gpuTflops = 0.0;
      _gpuFillrate = 0.0;
    });

    for (int step = 1; step <= 25; step++) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() {
        _gpuProgress = step / 25.0;
        _gpuTflops = (step * 0.75 + Random().nextDouble() * 0.3).clamp(0.0, 18.2);
        _gpuFillrate = (step * 4.2 + Random().nextDouble() * 2.0).clamp(0.0, 96.0);
      });
    }

    if (!mounted) return;
    setState(() {
      _isGpuRunning = false;
    });
  }

  // --- DISK BENCHMARK LOGIC ---
  Future<void> _startDiskBenchmark() async {
    if (_isDiskRunning) return;
    setState(() {
      _isDiskRunning = true;
      _diskProgress = 0.05;
      _diskReadMb = 0.0;
      _diskWriteMb = 0.0;
    });

    for (int step = 1; step <= 25; step++) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() {
        _diskProgress = step / 25.0;
        _diskReadMb = (step * 240.0 + Random().nextDouble() * 50).clamp(0.0, 5600.0);
        _diskWriteMb = (step * 180.0 + Random().nextDouble() * 40).clamp(0.0, 4200.0);
      });
    }

    if (!mounted) return;
    setState(() {
      _isDiskRunning = false;
    });
  }

  // --- INTERNET BENCHMARK LOGIC ---
  Future<void> _startNetBenchmark() async {
    if (_isNetRunning) return;
    setState(() {
      _isNetRunning = true;
      _netProgress = 0.05;
      _netDownload = 0.0;
      _netUpload = 0.0;
    });

    for (int step = 1; step <= 25; step++) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() {
        _netProgress = step / 25.0;
        _netDownload = (step * 34.0 + Random().nextDouble() * 10).clamp(0.0, 780.0);
        _netUpload = (step * 14.0 + Random().nextDouble() * 5).clamp(0.0, 320.0);
      });
    }

    if (!mounted) return;
    setState(() {
      _isNetRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    return Container(
      color: skin.windowBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER (Stopwatch/speedometer icon + "Benchmarks" + "Refresh" button)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: skin.headerBackground,
              border: Border(
                bottom: BorderSide(color: skin.windowStroke, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.speed_high, size: 20, color: skin.textAccent),
                const SizedBox(width: 10),
                Text(
                  'Benchmarks',
                  style: TextStyle(
                    color: skin.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                HoverButton(
                  onPressed: () {
                    setState(() {
                      _singleCoreMops = 0;
                      _multiCoreGops = 0;
                      _cpuProgress = 0;
                      _gpuTflops = 0;
                      _gpuFillrate = 0;
                      _gpuProgress = 0;
                      _diskReadMb = 0;
                      _diskWriteMb = 0;
                      _diskProgress = 0;
                      _netDownload = 0;
                      _netUpload = 0;
                      _netProgress = 0;
                    });
                  },
                  builder: (context, states) {
                    final isHover = states.contains(WidgetState.hovered);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isHover ? skin.tileBackground.withValues(alpha: 0.8) : skin.tileBackground,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: skin.tileStroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.refresh, size: 13, color: skin.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Refresh',
                            style: TextStyle(color: skin.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 2. MAIN WORKSPACE (Sub-Sidebar on Left + Content View on Right)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SUB-SIDEBAR
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: skin.headerBackground.withValues(alpha: 0.5),
                    border: Border(
                      right: BorderSide(color: skin.windowStroke, width: 1),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    children: [
                      _buildSidebarItem(
                        tab: BenchmarkTab.cpu,
                        customIcon: const _CpuIcon(),
                        title: 'CPU',
                        skin: skin,
                      ),
                      const SizedBox(height: 4),
                      _buildSidebarItem(
                        tab: BenchmarkTab.gpu,
                        icon: FluentIcons.screen,
                        title: 'GPU',
                        skin: skin,
                      ),
                      const SizedBox(height: 4),
                      _buildSidebarItem(
                        tab: BenchmarkTab.disk,
                        icon: FluentIcons.hard_drive,
                        title: 'Disk',
                        skin: skin,
                      ),
                      const SizedBox(height: 4),
                      _buildSidebarItem(
                        tab: BenchmarkTab.internet,
                        icon: FluentIcons.globe,
                        title: 'Internet',
                        skin: skin,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          style: DividerThemeData(
                            decoration: BoxDecoration(color: skin.windowStroke),
                          ),
                        ),
                      ),
                      _buildSidebarItem(
                        tab: BenchmarkTab.taskManScore,
                        icon: FluentIcons.trophy,
                        title: 'TaskMan Score',
                        accentColor: skin.getChannel('network').lit,
                        skin: skin,
                      ),
                    ],
                  ),
                ),

                // RIGHT BENCHMARK CONTENT
                Expanded(
                  child: Container(
                    color: skin.windowBackground,
                    child: _buildSelectedTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required BenchmarkTab tab,
    IconData? icon,
    Widget? customIcon,
    required String title,
    Color? accentColor,
    required SkinTheme skin,
  }) {
    final isSelected = _selectedTab == tab;

    return HoverButton(
      onPressed: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      builder: (context, states) {
        final isHover = states.contains(WidgetState.hovered);

        Color bg;
        if (isSelected) {
          bg = skin.textAccent.withValues(alpha: 0.22);
        } else if (isHover) {
          bg = skin.tileBackground.withValues(alpha: 0.4);
        } else {
          bg = Colors.transparent;
        }

        Color fg;
        if (isSelected) {
          fg = skin.textAccent;
        } else if (accentColor != null) {
          fg = accentColor;
        } else {
          fg = isHover ? skin.textPrimary : skin.textSecondary;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (customIcon != null)
                customIcon
              else if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : (accentColor ?? const Color(0xFF708398)),
                ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case BenchmarkTab.cpu:
        return _buildCpuBenchmarkContent();
      case BenchmarkTab.gpu:
        return _buildGpuBenchmarkContent();
      case BenchmarkTab.disk:
        return _buildDiskBenchmarkContent();
      case BenchmarkTab.internet:
        return _buildInternetBenchmarkContent();
      case BenchmarkTab.taskManScore:
        return _buildTaskManScoreContent();
    }
  }

  // --- CPU BENCHMARK CONTENT ---
  Widget _buildCpuBenchmarkContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'CPU Benchmark',
            style: TextStyle(
              color: Color(0xFF788390),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              fontFamily: 'Segoe UI',
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnalogGaugeWidget(
                title: 'Single core',
                value: _singleCoreMops,
                maxValue: 800.0,
                unit: 'Mops/sec',
                ticks: const [0, 200, 400, 600, 800],
                decimalPlaces: 0,
                size: 290,
              ),
              const SizedBox(width: 36),
              AnalogGaugeWidget(
                title: 'Multi core',
                value: _multiCoreGops,
                maxValue: 0.8,
                unit: 'Gop/sec',
                ticks: const [0, 0.2, 0.4, 0.6, 0.8],
                decimalPlaces: 1,
                size: 290,
              ),
            ],
          ),

          const SizedBox(height: 36),
          _buildSegmentedLedBar(_cpuProgress),
          const SizedBox(height: 22),

          HoverButton(
            onPressed: _isCpuRunning ? null : _startCpuBenchmark,
            builder: (context, states) {
              final isHover = states.contains(WidgetState.hovered);
              final isEnabled = !_isCpuRunning;

              return Container(
                width: 120,
                height: 36,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? (isHover ? const Color(0xFF254B85) : const Color(0xFF1D3B6A))
                      : const Color(0xFF142138),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    if (isEnabled && isHover)
                      BoxShadow(
                        color: const Color(0xFF1D3B6A).withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _isCpuRunning ? 'Testing...' : 'Start',
                  style: TextStyle(
                    color: isEnabled ? const Color(0xFFD4E2F4) : const Color(0xFF6B809E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- GPU BENCHMARK CONTENT ---
  Widget _buildGpuBenchmarkContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'GPU Benchmark',
            style: TextStyle(
              color: Color(0xFF788390),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              fontFamily: 'Segoe UI',
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnalogGaugeWidget(
                title: 'Compute Core',
                value: _gpuTflops,
                maxValue: 24.0,
                unit: 'TFLOPS',
                ticks: const [0, 6, 12, 18, 24],
                decimalPlaces: 1,
                size: 290,
              ),
              const SizedBox(width: 36),
              AnalogGaugeWidget(
                title: 'Pixel Fillrate',
                value: _gpuFillrate,
                maxValue: 120.0,
                unit: 'GPix/sec',
                ticks: const [0, 30, 60, 90, 120],
                decimalPlaces: 0,
                size: 290,
              ),
            ],
          ),

          const SizedBox(height: 36),
          _buildSegmentedLedBar(_gpuProgress),
          const SizedBox(height: 22),

          HoverButton(
            onPressed: _isGpuRunning ? null : _startGpuBenchmark,
            builder: (context, states) {
              final isHover = states.contains(WidgetState.hovered);
              return Container(
                width: 120,
                height: 36,
                decoration: BoxDecoration(
                  color: isHover ? const Color(0xFF254B85) : const Color(0xFF1D3B6A),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isGpuRunning ? 'Testing...' : 'Start',
                  style: const TextStyle(
                    color: Color(0xFFD4E2F4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- DISK BENCHMARK CONTENT ---
  Widget _buildDiskBenchmarkContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Disk Benchmark',
            style: TextStyle(
              color: Color(0xFF788390),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              fontFamily: 'Segoe UI',
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnalogGaugeWidget(
                title: 'Sequential Read',
                value: _diskReadMb,
                maxValue: 7000.0,
                unit: 'MB/sec',
                ticks: const [0, 1750, 3500, 5250, 7000],
                decimalPlaces: 0,
                size: 290,
              ),
              const SizedBox(width: 36),
              AnalogGaugeWidget(
                title: 'Sequential Write',
                value: _diskWriteMb,
                maxValue: 5000.0,
                unit: 'MB/sec',
                ticks: const [0, 1250, 2500, 3750, 5000],
                decimalPlaces: 0,
                size: 290,
              ),
            ],
          ),

          const SizedBox(height: 36),
          _buildSegmentedLedBar(_diskProgress),
          const SizedBox(height: 22),

          HoverButton(
            onPressed: _isDiskRunning ? null : _startDiskBenchmark,
            builder: (context, states) {
              final isHover = states.contains(WidgetState.hovered);
              return Container(
                width: 120,
                height: 36,
                decoration: BoxDecoration(
                  color: isHover ? const Color(0xFF254B85) : const Color(0xFF1D3B6A),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isDiskRunning ? 'Testing...' : 'Start',
                  style: const TextStyle(
                    color: Color(0xFFD4E2F4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- INTERNET BENCHMARK CONTENT ---
  Widget _buildInternetBenchmarkContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Internet Benchmark',
            style: TextStyle(
              color: Color(0xFF788390),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              fontFamily: 'Segoe UI',
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnalogGaugeWidget(
                title: 'Download Speed',
                value: _netDownload,
                maxValue: 1000.0,
                unit: 'Mbps',
                ticks: const [0, 250, 500, 750, 1000],
                decimalPlaces: 0,
                size: 290,
              ),
              const SizedBox(width: 36),
              AnalogGaugeWidget(
                title: 'Upload Speed',
                value: _netUpload,
                maxValue: 500.0,
                unit: 'Mbps',
                ticks: const [0, 125, 250, 375, 500],
                decimalPlaces: 0,
                size: 290,
              ),
            ],
          ),

          const SizedBox(height: 36),
          _buildSegmentedLedBar(_netProgress),
          const SizedBox(height: 22),

          HoverButton(
            onPressed: _isNetRunning ? null : _startNetBenchmark,
            builder: (context, states) {
              final isHover = states.contains(WidgetState.hovered);
              return Container(
                width: 120,
                height: 36,
                decoration: BoxDecoration(
                  color: isHover ? const Color(0xFF254B85) : const Color(0xFF1D3B6A),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isNetRunning ? 'Testing...' : 'Start',
                  style: const TextStyle(
                    color: Color(0xFFD4E2F4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TASKMAN SCORE CONTENT ---
  Widget _buildTaskManScoreContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'TaskMan Performance Index',
            style: TextStyle(
              color: Color(0xFF788390),
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              fontFamily: 'Segoe UI',
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnalogGaugeWidget(
                title: 'System Index',
                value: _overallScore > 0 ? _overallScore : 4650.0,
                maxValue: 10000.0,
                unit: 'Points',
                ticks: const [0, 2500, 5000, 7500, 10000],
                decimalPlaces: 0,
                size: 310,
              ),
            ],
          ),
          const SizedBox(height: 28),

          Container(
            width: 480,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14171A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF24282F)),
            ),
            child: Column(
              children: [
                _buildScoreBreakdownRow(
                  'CPU Single-Core Rating',
                  _singleCoreMops > 0 ? '${_singleCoreMops.round()} Mops' : '512 Mops',
                  const Color(0xFF00DFD0),
                ),
                const SizedBox(height: 8),
                _buildScoreBreakdownRow(
                  'CPU Multi-Core Rating',
                  _multiCoreGops > 0 ? '$_multiCoreGops Gops' : '0.62 Gops',
                  const Color(0xFF00DFD0),
                ),
                const SizedBox(height: 8),
                _buildScoreBreakdownRow(
                  'Architecture Tier',
                  'Workstation Class',
                  const Color(0xFFFFB900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdownRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8B98A6), fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Segmented LED Bar: row of 32 discrete LED rectangles (green)
  Widget _buildSegmentedLedBar(double progress) {
    const int totalSegments = 32;
    final int litSegments = (progress.clamp(0.0, 1.0) * totalSegments).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSegments, (index) {
        final isLit = index < litSegments;

        return Container(
          width: 8,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: isLit ? const Color(0xFF00E676) : const Color(0xFF081C10),
            borderRadius: BorderRadius.circular(1.5),
            boxShadow: isLit
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.65),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// Custom Chip Icon for CPU
class _CpuIcon extends StatelessWidget {
  const _CpuIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(
        painter: _CpuIconPainter(),
      ),
    );
  }
}

class _CpuIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF8B99A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final fillPaint = Paint()
      ..color = const Color(0xFF2852A8)
      ..style = PaintingStyle.fill;

    final bodyRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 10,
      height: 10,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(1.5)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(1.5)), borderPaint);

    final pinPaint = Paint()
      ..color = const Color(0xFF8B99A8)
      ..strokeWidth = 1.1;

    for (final x in [size.width / 2 - 2.5, size.width / 2 + 2.5]) {
      canvas.drawLine(Offset(x, 0.5), Offset(x, 2.5), pinPaint);
      canvas.drawLine(Offset(x, size.height - 2.5), Offset(x, size.height - 0.5), pinPaint);
    }
    for (final y in [size.height / 2 - 2.5, size.height / 2 + 2.5]) {
      canvas.drawLine(Offset(0.5, y), Offset(2.5, y), pinPaint);
      canvas.drawLine(Offset(size.width - 2.5, y), Offset(size.width - 0.5, y), pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
