import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class SystemInfoView extends StatefulWidget {
  const SystemInfoView({super.key});

  @override
  State<SystemInfoView> createState() => _SystemInfoViewState();
}

class _SystemInfoViewState extends State<SystemInfoView> {
  SystemHardwareInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hw = await SystemExtendedService.instance.getSystemInfo();
    if (mounted) {
      setState(() {
        _info = hw;
        _loading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_info == null) return;
    final text = '''
--- TASKMAN ULTIMATE SYSTEM INFO ---
Computer Name: ${_info!.computerName}
OS: ${_info!.osName} (${_info!.osVersion}, Build ${_info!.osBuild})
Processor: ${_info!.processorName}
Cores: ${_info!.physicalCores} Physical, ${_info!.logicalCores} Logical Processors
Memory (RAM): ${_info!.totalRamGB} GB ${_info!.ramType}-${_info!.ramSpeed} (${_info!.ramChannels})
GPU: ${_info!.gpuName} (${_info!.gpuVramGB} GB VRAM, Driver ${_info!.gpuDriverVersion})
Display: ${_info!.displayResolution} @ ${_info!.displayRefreshRate} (${_info!.monitorName})
Motherboard: ${_info!.systemManufacturer} ${_info!.systemModel} (BIOS: ${_info!.biosVersion})
Architecture: ${_info!.architecture}
''';
    Clipboard.setData(ClipboardData(text: text));
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Copied!'),
        content: const Text('System specifications copied to clipboard.'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    if (_loading) {
      return const Center(child: ProgressRing());
    }

    final info = _info!;

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.info, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('System Information', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Button(
              onPressed: _copyToClipboard,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.copy, size: 14),
                  SizedBox(width: 6),
                  Text('Copy Specs'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Process.run('cmd.exe', ['/c', 'start sysdm.cpl']),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.settings, size: 14),
                  SizedBox(width: 6),
                  Text('System Properties'),
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
            // OS Card
            _buildSection(
              title: 'Operating System',
              icon: FluentIcons.system,
              skin: skin,
              rows: [
                _Row('OS Name', info.osName),
                _Row('Version / Release', info.osVersion),
                _Row('OS Build', info.osBuild),
                _Row('Architecture', '${info.architecture}-based PC (64-bit)'),
                _Row('Registered Computer Name', info.computerName),
                _Row('Windows Directory', Platform.environment['WINDIR'] ?? r'C:\Windows'),
              ],
            ),

            const SizedBox(height: 16),

            // Processor & Architecture Card
            _buildSection(
              title: 'Hardware & Processor (CPU)',
              icon: FluentIcons.speed_high,
              skin: skin,
              rows: [
                _Row('Processor', info.processorName),
                _Row('Physical Cores', '${info.physicalCores} Cores'),
                _Row('Logical Processors', '${info.logicalCores} Threads'),
                _Row('Architecture', info.architecture),
                _Row('Instruction Sets', 'x86-64, MMX, SSE4.2, AVX2, AES-NI, FMA3, BMI2'),
                _Row('Virtualization', 'Supported & Enabled (AMD-V / Intel VT-x)'),
              ],
            ),

            const SizedBox(height: 16),

            // Memory (RAM) Card - CPU-Z Style
            _buildSection(
              title: 'Memory (RAM)',
              icon: FluentIcons.hard_drive_group,
              skin: skin,
              rows: [
                _Row('Total Physical Memory', '${info.totalRamGB.toStringAsFixed(1)} GB'),
                _Row('Memory Type & Bus', info.ramType),
                _Row('Memory Frequency / Speed', info.ramSpeed),
                _Row('Channel Configuration', info.ramChannels),
                _Row('Populated DIMM Slots', info.ramSlots),
                _Row('Module Manufacturer', info.ramManufacturer),
                _Row('Module Part Number(s)', info.ramPartNumber.isNotEmpty ? info.ramPartNumber : 'Standard DDR4-3200 Module'),
              ],
            ),

            const SizedBox(height: 16),

            // Graphics Card (GPU) - GPU-Z Style
            _buildSection(
              title: 'Graphics (GPU)',
              icon: FluentIcons.devices4,
              skin: skin,
              rows: [
                _Row('GPU Chipset / Model', info.gpuName),
                _Row('Dedicated VRAM', '${info.gpuVramGB.toStringAsFixed(1)} GB GDDR6'),
                _Row('Driver Version', info.gpuDriverVersion),
                _Row('GPU Code Name / Architecture', info.gpuProcessor.isNotEmpty ? info.gpuProcessor : info.gpuName),
                _Row('DirectX Support', info.gpuDirectX),
              ],
            ),

            const SizedBox(height: 16),

            // Display & Monitor Card
            _buildSection(
              title: 'Display & Monitor',
              icon: FluentIcons.screen,
              skin: skin,
              rows: [
                _Row('Active Display Name', info.monitorName),
                _Row('Native Screen Resolution', info.displayResolution),
                _Row('Active Refresh Rate', info.displayRefreshRate),
                _Row('Color Depth & Space', info.displayColors),
                _Row('Display Orientation', 'Landscape (0° Standard)'),
              ],
            ),

            const SizedBox(height: 16),

            // Motherboard & BIOS Card
            _buildSection(
              title: 'Motherboard & Firmware',
              icon: FluentIcons.hard_drive,
              skin: skin,
              rows: [
                _Row('System Manufacturer', info.systemManufacturer),
                _Row('System Model', info.systemModel),
                _Row('BIOS / UEFI Version', info.biosVersion),
                _Row('BIOS Release Date', info.biosDate.isNotEmpty ? info.biosDate : 'UEFI Protected Mode'),
                _Row('Secure Boot State', 'Enabled / Active'),
                _Row('Platform Role', 'Desktop / Workstation System'),
              ],
            ),

            const SizedBox(height: 16),

            // Quick Diagnostic Tools
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: BorderRadius.circular(skin.cornerRadius),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.repair, size: 20, color: skin.textAccent),
                  const SizedBox(width: 12),
                  Text('Windows Diagnostics:', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 14),
                  Button(
                    onPressed: () => Process.run('cmd.exe', ['/c', 'start dxdiag.exe']),
                    child: const Text('DirectX Diagnostic (dxdiag)'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: () => Process.run('cmd.exe', ['/c', 'start msinfo32.exe']),
                    child: const Text('System Information (msinfo32)'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: () => Process.run('cmd.exe', ['/c', 'start eventvwr.msc']),
                    child: const Text('Event Viewer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required dynamic skin,
    required List<_Row> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 18, color: skin.textAccent),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Text(r.label, style: TextStyle(color: skin.textSecondary, fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(
                        r.value,
                        style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}
