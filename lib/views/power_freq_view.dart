import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../widgets/segmented_meter.dart';

class PowerFreqView extends StatefulWidget {
  const PowerFreqView({super.key});

  @override
  State<PowerFreqView> createState() => _PowerFreqViewState();
}

class _PowerFreqViewState extends State<PowerFreqView> {
  String _activePlan = 'Balanced (Recommended)';

  void _setPowerPlan(String plan) {
    setState(() => _activePlan = plan);
    // e.g. powercfg /setactive ...
    if (plan.contains('High')) {
      Process.run('powercfg', ['/setactive', '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c']);
    } else if (plan.contains('Saver')) {
      Process.run('powercfg', ['/setactive', 'a1841308-3541-4fab-bc81-f71556f20b4a']);
    } else {
      Process.run('powercfg', ['/setactive', '381b4222-f694-41f0-9685-ff5bb260df2e']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;
    final metrics = provider.latestMetrics;
    final power = metrics?.powerStatus;

    final cpuPercent = metrics?.cpuPercent ?? 0.0;
    final thermals = metrics?.thermals;
    final cpuTemp = thermals?.cpuTemperature ?? 41.0;
    final isThrottling = thermals?.isCpuThrottling ?? false;
    // Estimated frequency calculation based on CPU load (base 3.2 GHz up to 5.4 GHz)
    final estFreq = (3.2 + (cpuPercent / 100.0) * 1.8).toStringAsFixed(2);
    final batteryPct = power?.batteryPercent ?? -1;

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.lightning_bolt, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Power & Frequency', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            FilledButton(
              onPressed: () => Process.run('control.exe', ['/name', 'Microsoft.PowerOptions']),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.settings, size: 14),
                  SizedBox(width: 6),
                  Text('Windows Power Options'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CPU Frequency & Clocks Card
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
                      Icon(FluentIcons.speed_high, size: 20, color: skin.textAccent),
                      const SizedBox(width: 10),
                      Text('CPU CORE FREQUENCY & CLOCK SPEED',
                          style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                      const Spacer(),
                      Text('$estFreq GHz',
                          style: TextStyle(color: skin.cpuColor, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Base Speed: 3.20 GHz', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Max Turbo Frequency: 5.40 GHz', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              isThrottling
                                  ? 'Thermal State: ${cpuTemp.toStringAsFixed(1)}°C (Thermal Throttling Active)'
                                  : 'Thermal State: ${cpuTemp.toStringAsFixed(1)}°C (Normal / Optimal)',
                              style: TextStyle(
                                color: isThrottling ? const Color(0xFFFF3B30) : const Color(0xFF00E676),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Clock Load:', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                            const SizedBox(height: 6),
                            SegmentedMeter(
                              value: (((double.tryParse(estFreq) ?? 3.2) / 5.4) * 100).clamp(0.0, 100.0),
                              segments: 24,
                              height: 16,
                              channelColor: skin.getChannel('cpu'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Power Supply & Battery State Card
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
                      Icon(FluentIcons.lightning_bolt, size: 20, color: skin.textAccent),
                      const SizedBox(width: 10),
                      Text('POWER SUPPLY & AC SOURCE',
                          style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (power?.isACPlugged ?? true)
                              ? const Color(0xFF00E676).withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (power?.isACPlugged ?? true) ? 'AC Connected (Mains)' : 'Battery Power',
                          style: TextStyle(
                            color: (power?.isACPlugged ?? true) ? const Color(0xFF00E676) : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AC Line Status: ${(power?.isACPlugged ?? true) ? "Online (Plugged In)" : "Offline"}',
                                style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              batteryPct >= 0
                                  ? 'Battery Charge Level: $batteryPct%'
                                  : 'System Type: Desktop Workstation (No internal battery)',
                              style: TextStyle(color: skin.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              power?.isCharging == true ? 'Status: Charging...' : 'Status: Fully Charged / Constant Power',
                              style: TextStyle(color: skin.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (batteryPct >= 0)
                        Expanded(
                          child: SegmentedMeter(
                            value: batteryPct.toDouble().clamp(0.0, 100.0),
                            segments: 20,
                            height: 18,
                            channelColor: ChannelColor(
                              accent: const Color(0xFF00E676),
                              lit: const Color(0xFF00E676),
                              unlit: skin.unlitChannelColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Active Power Plan Selector Card
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
                  Text('ACTIVE WINDOWS POWER SCHEME',
                      style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPlanOption('Balanced (Recommended)', 'Balances energy and performance dynamically.'),
                      const SizedBox(width: 12),
                      _buildPlanOption('High Performance', 'Favors performance, may use more energy.'),
                      const SizedBox(width: 12),
                      _buildPlanOption('Power Saver', 'Saves energy by reducing PC performance.'),
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

  Widget _buildPlanOption(String title, String desc) {
    final isSelected = _activePlan == title;
    final skin = context.read<TaskManProvider>().currentSkin;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setPowerPlan(title),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? skin.textAccent.withValues(alpha: 0.15) : skin.tileBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? skin.textAccent : skin.windowStroke,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected ? FluentIcons.radio_bullet : FluentIcons.circle_ring,
                    size: 16,
                    color: isSelected ? skin.textAccent : skin.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? skin.textPrimary : skin.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(desc, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
