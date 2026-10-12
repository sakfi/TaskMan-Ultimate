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

  @override
  void initState() {
    super.initState();
    _checkAlwaysOnTop();
  }

  Future<void> _checkAlwaysOnTop() async {
    final onTop = await windowManager.isAlwaysOnTop();
    if (mounted) setState(() => _alwaysOnTop = onTop);
  }

  void _toggleAlwaysOnTop(bool val) async {
    setState(() => _alwaysOnTop = val);
    await windowManager.setAlwaysOnTop(val);
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
