import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/taskman_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _alwaysOnTop = false;
  bool _isDefaultTaskManager = false;
  bool _isBusyTaskManager = false;

  @override
  void initState() {
    super.initState();
    _checkAlwaysOnTop();
    _checkDefaultTaskManager();
  }

  Future<void> _checkAlwaysOnTop() async {
    final onTop = await windowManager.isAlwaysOnTop();
    if (mounted) setState(() => _alwaysOnTop = onTop);
  }

  void _toggleAlwaysOnTop(bool val) async {
    setState(() => _alwaysOnTop = val);
    await windowManager.setAlwaysOnTop(val);
  }

  Future<void> _checkDefaultTaskManager() async {
    try {
      final res = await Process.run('reg.exe', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\taskmgr.exe',
        '/v',
        'Debugger',
      ]);
      if (mounted) {
        final out = (res.stdout as String).toLowerCase();
        setState(() {
          _isDefaultTaskManager = res.exitCode == 0 && out.contains('taskman_ultimate');
        });
      }
    } catch (_) {}
  }

  String _getTargetExePath() {
    final current = Platform.resolvedExecutable;
    if (current.toLowerCase().endsWith('taskman_ultimate.exe')) {
      return current;
    }
    final releaseExe = File(r'build\windows\x64\runner\Release\taskman_ultimate.exe');
    if (releaseExe.existsSync()) {
      return releaseExe.absolute.path;
    }
    return current;
  }

  static int _shellExecuteRunAs(String file, String params) {
    if (!Platform.isWindows) return 0;
    try {
      final shell32 = DynamicLibrary.open('shell32.dll');
      final shellExecute = shell32.lookupFunction<
          Int32 Function(
              IntPtr hwnd,
              Pointer<Utf16> lpOperation,
              Pointer<Utf16> lpFile,
              Pointer<Utf16> lpParameters,
              Pointer<Utf16> lpDirectory,
              Int32 nShowCmd),
          int Function(
              int hwnd,
              Pointer<Utf16> lpOperation,
              Pointer<Utf16> lpFile,
              Pointer<Utf16> lpParameters,
              Pointer<Utf16> lpDirectory,
              int nShowCmd)>('ShellExecuteW');

      final opPtr = 'runas'.toNativeUtf16();
      final filePtr = file.toNativeUtf16();
      final paramsPtr = params.toNativeUtf16();

      try {
        return shellExecute(0, opPtr, filePtr, paramsPtr, nullptr, 0 /* SW_HIDE */);
      } finally {
        calloc.free(opPtr);
        calloc.free(filePtr);
        calloc.free(paramsPtr);
      }
    } catch (e) {
      debugPrint('ShellExecute error: $e');
      return 0;
    }
  }

  Future<void> _toggleReplaceTaskManager(bool enable) async {
    setState(() => _isBusyTaskManager = true);
    final exePath = _getTargetExePath();

    try {
      if (enable) {
        var res = await Process.run('reg.exe', [
          'add',
          r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\taskmgr.exe',
          '/v',
          'Debugger',
          '/t',
          'REG_SZ',
          '/d',
          exePath,
          '/f',
        ]);
        if (res.exitCode != 0) {
          _shellExecuteRunAs(
            'reg.exe',
            'add "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\taskmgr.exe" /v Debugger /t REG_SZ /d "$exePath" /f',
          );
        }
      } else {
        var res = await Process.run('reg.exe', [
          'delete',
          r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\taskmgr.exe',
          '/v',
          'Debugger',
          '/f',
        ]);
        if (res.exitCode != 0) {
          _shellExecuteRunAs(
            'reg.exe',
            'delete "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\taskmgr.exe" /v Debugger /f',
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling Task Manager replacement: $e');
    }

    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkDefaultTaskManager();
      if (_isDefaultTaskManager == enable) break;
    }
    if (mounted) {
      setState(() => _isBusyTaskManager = false);
      final success = _isDefaultTaskManager == enable;
      if (success) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(enable
                ? 'TaskMan Ultimate is now Default!'
                : 'Default Task Manager Restored'),
            content: Text(enable
                ? 'Pressing Ctrl+Shift+Esc or taskbar clicks will now launch TaskMan Ultimate.'
                : 'Standard Windows Task Manager restored for Ctrl+Shift+Esc.'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      } else {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Administrator Permission Required'),
            content: const Text(
              'Windows requires Administrator approval (UAC) to modify the Task Manager registry hook. Please click "Yes" when the Windows prompt appears.',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    String currentSpeed = 'Normal (1.0s)';
    if (provider.refreshInterval.inMilliseconds == 500) currentSpeed = 'High (0.5s)';
    if (provider.refreshInterval.inMilliseconds == 2500) currentSpeed = 'Low (2.5s)';
    if (provider.isPaused) currentSpeed = 'Paused';

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.settings, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Settings', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // General Preferences
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: BorderRadius.circular(skin.cornerRadius),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GENERAL PREFERENCES',
                      style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Telemetry Update Speed', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Controls sampling frequency of CPU, RAM, and processes', style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                        ],
                      ),
                      ComboBox<String>(
                        value: currentSpeed,
                        items: const [
                          ComboBoxItem(value: 'High (0.5s)', child: Text('High (0.5s)')),
                          ComboBoxItem(value: 'Normal (1.0s)', child: Text('Normal (1.0s)')),
                          ComboBoxItem(value: 'Low (2.5s)', child: Text('Low (2.5s)')),
                          ComboBoxItem(value: 'Paused', child: Text('Paused')),
                        ],
                        onChanged: (val) {
                          if (val == 'High (0.5s)') {
                            provider.setRefreshInterval(const Duration(milliseconds: 500));
                          } else if (val == 'Low (2.5s)') {
                            provider.setRefreshInterval(const Duration(milliseconds: 2500));
                          } else if (val == 'Paused') {
                            if (!provider.isPaused) provider.togglePause();
                          } else {
                            provider.setRefreshInterval(const Duration(seconds: 1));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ToggleSwitch(
                    checked: _alwaysOnTop,
                    onChanged: _toggleAlwaysOnTop,
                    content: Text('Always on Top', style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  ToggleSwitch(
                    checked: provider.confirmKill,
                    onChanged: (v) => provider.setConfirmKill(v),
                    content: Text('Confirm before ending process / service', style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  ToggleSwitch(
                    checked: provider.hideWhenMinimized,
                    onChanged: (v) => provider.setHideWhenMinimized(v),
                    content: Text('Hide when minimized (Minimize to Notification Tray)', style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  ToggleSwitch(
                    checked: provider.soundAlerts,
                    onChanged: (v) => provider.setSoundAlerts(v),
                    content: Text('Audio beep when CPU exceeds 90%', style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Smart Guardian & Anomaly Alerts
            Container(
              padding: const EdgeInsets.all(18),
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
                      Icon(FluentIcons.shield_alert, size: 16, color: skin.textAccent),
                      const SizedBox(width: 8),
                      Text(
                        'SMART GUARDIAN & ANOMALY ALERTS',
                        style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time automated hardware safeguards and threshold alerts shown directly in the Summary Dashboard.',
                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ToggleSwitch(
                    checked: provider.alertOnHighTemp,
                    onChanged: (v) => provider.setAlertOnHighTemp(v),
                    content: Text('Warn when CPU or GPU temperature exceeds 85°C (Thermal Throttle Risk)',
                        style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  ToggleSwitch(
                    checked: provider.alertOnHighRam,
                    onChanged: (v) => provider.setAlertOnHighRam(v),
                    content: Text('Warn when RAM memory usage exceeds 90% (Low Working Set Warning)',
                        style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  ToggleSwitch(
                    checked: provider.alertOnHighCpu,
                    onChanged: (v) => provider.setAlertOnHighCpu(v),
                    content: Text('Warn when CPU utilization exceeds 95% (Sustained Workload Spike)',
                        style: TextStyle(color: skin.textPrimary, fontSize: 13)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Windows Shell & Task Manager Integration
            Container(
              padding: const EdgeInsets.all(18),
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
                      Icon(FluentIcons.task_manager, size: 16, color: skin.textAccent),
                      const SizedBox(width: 8),
                      Text(
                        'WINDOWS SHELL INTEGRATION',
                        style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure system-wide hotkeys and replace default Windows utilities with TaskMan Ultimate.',
                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replace Default Windows Task Manager',
                              style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Overrides taskmgr.exe via Image File Execution Options (IFEO). Pressing Ctrl+Shift+Esc, Ctrl+Alt+Del, or right-clicking the taskbar will automatically launch TaskMan Ultimate.',
                              style: TextStyle(color: skin.textSecondary, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_isBusyTaskManager)
                        const ProgressRing(strokeWidth: 2)
                      else
                        ToggleSwitch(
                          checked: _isDefaultTaskManager,
                          onChanged: _toggleReplaceTaskManager,
                          content: Text(
                            _isDefaultTaskManager ? 'Enabled' : 'Disabled',
                            style: TextStyle(
                              color: _isDefaultTaskManager ? skin.textAccent : skin.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_isDefaultTaskManager) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: skin.windowBackground.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: skin.textAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(FluentIcons.completed, size: 14, color: skin.textAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'TaskMan Ultimate is active as your primary Windows Task Manager (Ctrl+Shift+Esc hook armed).',
                              style: TextStyle(fontSize: 11.5, color: skin.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // About TaskMan Ultimate
            Container(
              padding: const EdgeInsets.all(18),
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
                      Icon(FluentIcons.info, size: 20, color: skin.textAccent),
                      const SizedBox(width: 10),
                      Text('ABOUT TASKMAN ULTIMATE',
                          style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TaskMan Ultimate is a modern, ultra-high-performance Windows desktop task manager and hardware telemetry suite.',
                    style: TextStyle(color: skin.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Built with native Win32 FFI APIs, automatic CPU (AMD Ryzen & Intel) & GPU thermal sensing, real-time telemetry graphs, and customizable themes.',
                    style: TextStyle(color: skin.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: skin.textAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Version 2.0.0 PRO (Release)',
                          style: TextStyle(color: skin.textAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Pure Flutter Desktop + Win32 FFI Engine', style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
