import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import '../models/skin_theme.dart';
import '../services/skin_loader_service.dart';
import '../services/system_extended_service.dart';
import '../services/system_telemetry_service.dart';

enum ProcessSortField {
  name,
  pid,
  memory,
  threads,
}

class TaskManProvider extends ChangeNotifier {
  final SystemTelemetryService _service = SystemTelemetryService();
  Timer? _timer;

  // Available skins (built-in + local imported)
  List<SkinTheme> _availableSkins = [];
  List<SkinTheme> get availableSkins => _availableSkins;

  SkinTheme _currentSkin = SkinTheme.builtInSkins[0];
  SkinTheme get currentSkin => _currentSkin;

  // Metrics
  SystemMetrics? _latestMetrics;
  SystemMetrics? get latestMetrics => _latestMetrics;

  // History buffers (last 60 samples)
  final List<double> cpuHistory = List.filled(60, 0.0, growable: true);
  final List<double> kernelCpuHistory = List.filled(60, 0.0, growable: true);
  final List<double> memoryHistory = List.filled(60, 0.0, growable: true);
  final List<double> diskHistory = List.filled(60, 0.0, growable: true);
  final List<double> networkHistory = List.filled(60, 0.0, growable: true);
  final List<double> cpuThermalHistory = List.filled(60, 40.0, growable: true);
  final List<double> gpuThermalHistory = List.filled(60, 42.0, growable: true);

  // Per-core history buffers
  late final List<List<double>> coreHistories;

  // Visual toggles
  bool _showPerCoreCpu = false;
  bool get showPerCoreCpu => _showPerCoreCpu;

  bool _showKernelTimes = false;
  bool get showKernelTimes => _showKernelTimes;

  bool _isMiniHudMode = false;
  bool get isMiniHudMode => _isMiniHudMode;

  // Settings preferences
  bool _confirmKill = true;
  bool get confirmKill => _confirmKill;

  bool _hideWhenMinimized = false;
  bool get hideWhenMinimized => _hideWhenMinimized;

  bool _soundAlerts = false;
  bool get soundAlerts => _soundAlerts;

  bool _alertOnHighTemp = true;
  bool get alertOnHighTemp => _alertOnHighTemp;

  bool _alertOnHighRam = true;
  bool get alertOnHighRam => _alertOnHighRam;

  bool _alertOnHighCpu = false;
  bool get alertOnHighCpu => _alertOnHighCpu;

  String? _activeAlertMessage;
  String? get activeAlertMessage => _activeAlertMessage;

  // Enthusiast & Power state
  bool _isTurboMode = false;
  bool get isTurboMode => _isTurboMode;

  bool _isCleaningRam = false;
  bool get isCleaningRam => _isCleaningRam;

  String? _lastRamCleanResult;
  String? get lastRamCleanResult => _lastRamCleanResult;

  bool _isTreeView = false;
  bool get isTreeView => _isTreeView;

  // Process list state
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  ProcessSortField _sortField = ProcessSortField.memory;
  ProcessSortField get sortField => _sortField;

  bool _sortAscending = false;
  bool get sortAscending => _sortAscending;

  int? _selectedPid;
  int? get selectedPid => _selectedPid;

  Duration _refreshInterval = const Duration(seconds: 1);
  Duration get refreshInterval => _refreshInterval;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  int get coreCount => _service.logicalCoreCount;

  TaskManProvider() {
    coreHistories = List.generate(
      _service.logicalCoreCount,
      (_) => List.filled(60, 0.0, growable: true),
    );
    _loadSkins();
    _loadSettings();
    _startPolling();
  }

  void _loadSettings() {
    try {
      final file = File('taskman_settings.json');
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        _confirmKill = data['confirmKill'] as bool? ?? true;
        _hideWhenMinimized = data['hideWhenMinimized'] as bool? ?? false;
        _soundAlerts = data['soundAlerts'] as bool? ?? false;
        _alertOnHighTemp = data['alertOnHighTemp'] as bool? ?? true;
        _alertOnHighRam = data['alertOnHighRam'] as bool? ?? true;
        _alertOnHighCpu = data['alertOnHighCpu'] as bool? ?? false;
        if (data['skinId'] != null) {
          final skin = _availableSkins.firstWhere(
            (s) => s.id == data['skinId'],
            orElse: () => _currentSkin,
          );
          _currentSkin = skin;
        }
        if (data['intervalMs'] != null) {
          _refreshInterval = Duration(milliseconds: data['intervalMs'] as int);
        }
      }
    } catch (_) {}
  }

  void _saveSettings() {
    try {
      final file = File('taskman_settings.json');
      final data = {
        'confirmKill': _confirmKill,
        'hideWhenMinimized': _hideWhenMinimized,
        'soundAlerts': _soundAlerts,
        'alertOnHighTemp': _alertOnHighTemp,
        'alertOnHighRam': _alertOnHighRam,
        'alertOnHighCpu': _alertOnHighCpu,
        'skinId': _currentSkin.id,
        'intervalMs': _refreshInterval.inMilliseconds,
      };
      file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void setConfirmKill(bool val) {
    _confirmKill = val;
    _saveSettings();
    notifyListeners();
  }

  void setHideWhenMinimized(bool val) {
    _hideWhenMinimized = val;
    _saveSettings();
    notifyListeners();
  }

  void setSoundAlerts(bool val) {
    _soundAlerts = val;
    _saveSettings();
    notifyListeners();
  }

  void setAlertOnHighTemp(bool val) {
    _alertOnHighTemp = val;
    _saveSettings();
    notifyListeners();
  }

  void setAlertOnHighRam(bool val) {
    _alertOnHighRam = val;
    _saveSettings();
    notifyListeners();
  }

  void setAlertOnHighCpu(bool val) {
    _alertOnHighCpu = val;
    _saveSettings();
    notifyListeners();
  }

  void dismissAlert() {
    _activeAlertMessage = null;
    notifyListeners();
  }

  void dismissRamCleanResult() {
    _lastRamCleanResult = null;
    notifyListeners();
  }

  void toggleTreeView() {
    _isTreeView = !_isTreeView;
    notifyListeners();
  }

  Future<void> cleanRam() async {
    _isCleaningRam = true;
    notifyListeners();
    try {
      final count = await SystemExtendedService.instance.cleanMemoryWorkingSets();
      _lastRamCleanResult = 'Cleaned $count processes';
      _fetchMetrics();
      // Auto-dismiss notification after 6 seconds
      Future.delayed(const Duration(seconds: 6), () {
        if (_lastRamCleanResult != null) {
          _lastRamCleanResult = null;
          notifyListeners();
        }
      });
    } finally {
      _isCleaningRam = false;
      notifyListeners();
    }
  }

  Future<void> toggleTurboMode() async {
    _isTurboMode = !_isTurboMode;
    await SystemExtendedService.instance.setTurboPowerPlan(_isTurboMode);
    notifyListeners();
  }

  Future<bool> killProcessTree(int pid) async {
    final success = await SystemExtendedService.instance.killProcessTree(pid);
    refreshNow();
    return success;
  }

  Future<int> getProcessAffinity(int pid) => SystemExtendedService.instance.getProcessAffinity(pid);

  Future<bool> setProcessAffinity(int pid, int mask) => SystemExtendedService.instance.setProcessAffinity(pid, mask);

  void _loadSkins() {
    final local = SkinLoaderService.loadLocalSkins();
    final combined = <String, SkinTheme>{};

    for (final s in SkinTheme.builtInSkins) {
      combined[s.id] = s;
    }
    for (final s in local) {
      combined[s.id] = s;
    }

    _availableSkins = combined.values.toList();
    if (_availableSkins.isNotEmpty) {
      _currentSkin = _availableSkins[0];
    }
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchMetrics();
    _timer = Timer.periodic(_refreshInterval, (timer) {
      if (!_isPaused) {
        _fetchMetrics();
      }
    });
  }

  void refreshNow() {
    _fetchMetrics();
  }

  void _fetchMetrics() {
    final metrics = _service.collectMetrics();
    _latestMetrics = metrics;

    _pushHistory(cpuHistory, metrics.cpuPercent);
    _pushHistory(kernelCpuHistory, metrics.kernelCpuPercent);
    _pushHistory(memoryHistory, metrics.memoryPercent);
    _pushHistory(diskHistory, metrics.diskUsageMBs);
    _pushHistory(networkHistory, metrics.networkUsageKbps);
    _pushHistory(cpuThermalHistory, metrics.thermals.cpuTemperature);
    _pushHistory(gpuThermalHistory, metrics.thermals.gpuTemperature);

    for (int i = 0; i < metrics.perCoreCpu.length && i < coreHistories.length; i++) {
      _pushHistory(coreHistories[i], metrics.perCoreCpu[i]);
    }

    // Continuous Flight Recorder snapshot in background
    final extService = SystemExtendedService.instance;
    if (extService.isRecordingFlight) {
      String topProc = 'System';
      double topCpu = 0.0;
      if (metrics.processes.isNotEmpty) {
        topProc = metrics.processes.first.name;
        topCpu = metrics.processes.first.cpuPercent;
      }
      extService.recordSnapshot(
        cpu: metrics.cpuPercent,
        mem: metrics.memoryPercent,
        disk: metrics.diskUsageMBs,
        topProc: topProc,
        topProcCpu: topCpu,
      );
    }

    // Anomaly & Threshold Alert checks
    if (_alertOnHighTemp && metrics.thermals.cpuTemperature >= 85.0) {
      _activeAlertMessage = 'Thermal Warning: CPU package reached ${metrics.thermals.cpuTemperature.toStringAsFixed(1)}°C';
    } else if (_alertOnHighRam && metrics.memoryPercent >= 90.0) {
      _activeAlertMessage = 'High Memory Alert: System RAM is at ${metrics.memoryPercent.toStringAsFixed(1)}%';
    } else if (_alertOnHighCpu && metrics.cpuPercent >= 95.0) {
      _activeAlertMessage = 'High Load Warning: CPU utilization reached ${metrics.cpuPercent.toStringAsFixed(1)}%';
    }

    notifyListeners();
  }

  void _pushHistory(List<double> buffer, double value) {
    if (buffer.length >= 60) {
      buffer.removeAt(0);
    }
    buffer.add(value);
  }

  void setSkin(SkinTheme skin) {
    _currentSkin = skin;
    _saveSettings();
    notifyListeners();
  }

  void togglePerCoreCpu() {
    _showPerCoreCpu = !_showPerCoreCpu;
    notifyListeners();
  }

  void toggleKernelTimes() {
    _showKernelTimes = !_showKernelTimes;
    notifyListeners();
  }

  Future<void> toggleMiniHudMode() async {
    _isMiniHudMode = !_isMiniHudMode;
    notifyListeners();

    if (Platform.isWindows && Platform.environment['FLUTTER_TEST'] != 'true') {
      if (_isMiniHudMode) {
        await windowManager.setSize(const Size(340, 220));
        await windowManager.setAlwaysOnTop(true);
      } else {
        await windowManager.setSize(const Size(1050, 720));
        await windowManager.setAlwaysOnTop(false);
      }
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSort(ProcessSortField field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = false;
    }
    notifyListeners();
  }

  void selectPid(int? pid) {
    _selectedPid = pid;
    notifyListeners();
  }

  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }

  void setRefreshInterval(Duration duration) {
    _refreshInterval = duration;
    _saveSettings();
    _startPolling();
  }

  bool terminateProcess(int pid) {
    final success = _service.terminateProcess(pid);
    if (success) {
      if (_selectedPid == pid) {
        _selectedPid = null;
      }
      _fetchMetrics();
    }
    return success;
  }

  bool setPriority(int pid, int priorityClass) {
    final ok = _service.setProcessPriority(pid, priorityClass);
    if (ok) {
      _fetchMetrics();
    }
    return ok;
  }

  void openProcessLocation(ProcessInfo proc) {
    if (proc.fullPath.isNotEmpty) {
      Process.run('explorer.exe', ['/select,${proc.fullPath}']);
    }
  }

  void searchProcessOnline(ProcessInfo proc) {
    final query = Uri.encodeComponent('${proc.name} process windows');
    Process.run('cmd.exe', ['/c', 'start', 'https://www.google.com/search?q=$query']);
  }

  void searchVirusTotal(ProcessInfo proc) {
    Process.run('cmd.exe', ['/c', 'start', 'https://www.virustotal.com/gui/search/${proc.name}']);
  }

  List<ProcessInfo> get filteredProcesses {
    if (_latestMetrics == null) return [];
    var list = List<ProcessInfo>.from(_latestMetrics!.processes);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) || p.pid.toString().contains(q);
      }).toList();
    }

    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case ProcessSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case ProcessSortField.pid:
          cmp = a.pid.compareTo(b.pid);
          break;
        case ProcessSortField.memory:
          cmp = a.memoryBytes.compareTo(b.memoryBytes);
          break;
        case ProcessSortField.threads:
          cmp = a.threadCount.compareTo(b.threadCount);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
