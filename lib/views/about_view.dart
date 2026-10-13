import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/skin_theme.dart';
import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';
import '../widgets/taskman_logo_widget.dart';

class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  SystemHardwareInfo? _sysInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHardwareInfo();
  }

  Future<void> _loadHardwareInfo() async {
    final info = await SystemExtendedService.instance.getSystemInfo();
    if (mounted) {
      setState(() {
        _sysInfo = info;
        _loading = false;
      });
    }
  }

  void _openUrl(String url) {
    Process.run('cmd.exe', ['/c', 'start', url]);
  }

  void _copyDiagnosticsToClipboard(TaskManProvider provider) {
    final info = _sysInfo;
    final text = StringBuffer();
    text.writeln('========================================');
    text.writeln('TASKMAN ULTIMATE - SYSTEM DIAGNOSTICS');
    text.writeln('========================================');
    text.writeln('Application: TaskMan Ultimate (PRO v2.0)');
    text.writeln('Architecture: Flutter Desktop + Native Win32 C-FFI');
    text.writeln('License: MIT License (Free & Open Source)');
    text.writeln('Developer: SakFi (github.com/sakfi)');
    text.writeln('Repository: https://github.com/sakfi/TaskMan-Ultimate');
    text.writeln('');
    text.writeln('[Host Hardware & OS]');
    if (info != null) {
      text.writeln('Computer Name: ${info.computerName}');
      text.writeln('OS: ${info.osName} (${info.osVersion}, Build ${info.osBuild})');
      text.writeln('Architecture: ${info.architecture}');
      text.writeln('Processor: ${info.processorName}');
      text.writeln('Cores: ${info.physicalCores} Physical, ${info.logicalCores} Logical');
      text.writeln('RAM: ${info.totalRamGB} GB ${info.ramType}-${info.ramSpeed}');
      text.writeln('GPU: ${info.gpuName} (${info.gpuVramGB} GB VRAM)');
      text.writeln('Display: ${info.displayResolution} @ ${info.displayRefreshRate}');
      text.writeln('Motherboard: ${info.systemManufacturer} ${info.systemModel}');
      text.writeln('BIOS: ${info.biosVersion}');
    } else {
      text.writeln('OS: Windows 10/11 x64');
    }
    text.writeln('');
    text.writeln('[Active Session Metrics]');
    text.writeln('Active Skin: ${provider.currentSkin.name}');
    final procCount = provider.latestMetrics?.processes.length ?? 0;
    text.writeln('Processes Monitored: $procCount');
    text.writeln('RAM Optimizer: Active (psapi.dll!EmptyWorkingSet)');
    text.writeln('Forensics Engine: Handle Hunter + Nuclear Tree Kill (/T)');
    text.writeln('Network Intelligence: Cloud Provider & GeoIP Scope Active');
    text.writeln('Smart Guardian: CPU >95%, RAM >90%, Temp >85°C Watcher');
    text.writeln('========================================');

    Clipboard.setData(ClipboardData(text: text.toString()));
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Diagnostics Copied!'),
        content: const Text('Complete system diagnostics copied to clipboard.'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.info, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text(
              'About',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: skin.textPrimary,
              ),
            ),
            const Spacer(),
            FilledButton(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.copy, size: 14),
                  SizedBox(width: 6),
                  Text('Copy Diagnostics'),
                ],
              ),
              onPressed: () => _copyDiagnosticsToClipboard(provider),
            ),
          ],
        ),
      ),
      children: [
        // 1. Hero Identity Banner
        _buildHeroBanner(skin),
        const SizedBox(height: 16),

        // 2. Developer & Community Card
        _buildDeveloperCard(skin),
        const SizedBox(height: 16),

        // 3. System Runtime & Diagnostics Card
        _buildSystemDiagnosticsCard(skin, provider),
        const SizedBox(height: 16),

        // 4. Forensics & Architecture Superpowers Grid
        _buildArchitectureCard(skin),
        const SizedBox(height: 16),

        // 5. Action Hub (GitHub, Telegram, Releases, Issues)
        _buildActionHub(skin, provider),
        const SizedBox(height: 24),

        // Footer copyright notice
        Center(
          child: Text(
            'TaskMan Ultimate PRO v2.0 • Licensed under the MIT License • Built with Flutter Desktop & Win32 FFI',
            style: TextStyle(
              fontSize: 12,
              color: skin.textSecondary.withValues(alpha:0.7),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeroBanner(SkinTheme skin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        border: Border.all(color: skin.textAccent.withValues(alpha:0.4), width: 1.2),
        borderRadius: BorderRadius.circular(skin.cornerRadius + 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: skin.windowBackground,
              borderRadius: BorderRadius.circular(skin.cornerRadius),
              border: Border.all(color: skin.tileStroke),
            ),
            child: const TaskManLogoWidget(width: 130, height: 50),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TASKMAN ULTIMATE',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: skin.textAccent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: skin.textAccent.withValues(alpha:0.15),
                        border: Border.all(color: skin.textAccent, width: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRO v2.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: skin.textAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Next-Gen Windows Telemetry & Advanced Process Forensics Workstation',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: skin.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildBadge('Platform: Windows 10 | 11 (x64)', FluentIcons.devices3, skin),
                    _buildBadge('Zero-Overhead Win32 C-FFI', FluentIcons.lightning_bolt, skin),
                    _buildBadge('100% Native Kernel Telemetry', FluentIcons.heart, skin),
                    _buildBadge('MIT Open Source', FluentIcons.certificate, skin),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon, SkinTheme skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: skin.windowBackground.withValues(alpha:0.6),
        border: Border.all(color: skin.tileStroke),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: skin.textAccent),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: skin.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(SkinTheme skin) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        border: Border.all(color: skin.tileStroke),
        borderRadius: BorderRadius.circular(skin.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.contact, size: 18),
              const SizedBox(width: 8),
              Text(
                'Developer & Maintainer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: skin.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: skin.textAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: skin.textAccent, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: skin.textAccent,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SakFi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: skin.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Creator of TaskMan Ultimate • Hardware Enthusiast & Systems Developer',
                      style: TextStyle(
                        fontSize: 12,
                        color: skin.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.send, size: 13),
                        SizedBox(width: 6),
                        Text('Telegram'),
                      ],
                    ),
                    onPressed: () => _openUrl('http://t.me/SakFi'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.contact_link, size: 13),
                        SizedBox(width: 6),
                        Text('GitHub'),
                      ],
                    ),
                    onPressed: () => _openUrl('https://github.com/sakfi'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemDiagnosticsCard(SkinTheme skin, TaskManProvider provider) {
    final info = _sysInfo;
    final procCount = provider.latestMetrics?.processes.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        border: Border.all(color: skin.tileStroke),
        borderRadius: BorderRadius.circular(skin.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.diagnostic, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Runtime Environment & Diagnostics',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: skin.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_loading)
                const ProgressRing(strokeWidth: 2)
              else
                Text(
                  'Diagnostic sensors synced',
                  style: TextStyle(fontSize: 11, color: skin.textAccent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (info != null) ...[
            _buildDiagGrid([
              _DiagItem('Host OS', '${info.osName} (Build ${info.osBuild})'),
              _DiagItem('Processor', info.processorName),
              _DiagItem('Architecture', '${info.architecture} (${info.physicalCores} Cores / ${info.logicalCores} Threads)'),
              _DiagItem('Installed Memory', '${info.totalRamGB} GB ${info.ramType}-${info.ramSpeed}'),
              _DiagItem('Active GPU', '${info.gpuName} (${info.gpuVramGB} GB VRAM)'),
              _DiagItem('Display Target', '${info.displayResolution} @ ${info.displayRefreshRate}'),
              _DiagItem('Motherboard & BIOS', '${info.systemManufacturer} ${info.systemModel} (BIOS ${info.biosVersion})'),
              _DiagItem('Telemetry Engine', 'Win32 C-FFI • $procCount Active Processes Monitored'),
            ], skin),
          ] else ...[
            const Text('Querying local hardware metrics via WMI & Win32 C-FFI...'),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagGrid(List<_DiagItem> items, SkinTheme skin) {
    return Column(
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: skin.windowBackground.withValues(alpha:0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: skin.textAccent,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: skin.textPrimary,
                    fontFamily: 'Consolas',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildArchitectureCard(SkinTheme skin) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        border: Border.all(color: skin.tileStroke),
        borderRadius: BorderRadius.circular(skin.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.shield, size: 18),
              const SizedBox(width: 8),
              Text(
                'Next-Gen Architecture & Forensic Superpowers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: skin.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeatureTile(
                '🛡️ Forensics & Lock Hunter',
                'Inspects file locking handles, recursive process tree kill (/T), Authenticode digital signatures, and VirusTotal SHA-256 hash intelligence.',
                skin,
              ),
              _buildFeatureTile(
                '⚡ Enthusiast Hardware Control',
                'psapi.dll!EmptyWorkingSet RAM compaction, core affinity bitmask assignment, sub-second Ryzen/Intel thermals, and Turbo power scheme boosting.',
                skin,
              ),
              _buildFeatureTile(
                '🌐 Network Intelligence',
                'Real-time socket inspector, port service discovery, and autonomous boundary resolution (Cloudflare, AWS, Google, Azure, Akamai, LAN, WAN).',
                skin,
              ),
              _buildFeatureTile(
                '📊 Black Box Flight Recorder',
                'Continuous 60-second hardware telemetry history buffer with interactive timeline scrubber and one-click CSV / JSON forensic export.',
                skin,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String title, String desc, SkinTheme skin) {
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: skin.windowBackground.withValues(alpha:0.5),
          border: Border.all(color: skin.tileStroke),
          borderRadius: BorderRadius.circular(skin.cornerRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: skin.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11.5,
                color: skin.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHub(SkinTheme skin, TaskManProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: skin.tileBackground,
        border: Border.all(color: skin.tileStroke),
        borderRadius: BorderRadius.circular(skin.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.globe, size: 18),
              const SizedBox(width: 8),
              Text(
                'Project Links & Support Hub',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: skin.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.open_enrollment, size: 14),
                    SizedBox(width: 6),
                    Text('View Repository on GitHub'),
                  ],
                ),
                onPressed: () => _openUrl('https://github.com/sakfi/TaskMan-Ultimate'),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.bug, size: 14),
                    SizedBox(width: 6),
                    Text('Report Issue / Bug'),
                  ],
                ),
                onPressed: () => _openUrl('https://github.com/sakfi/TaskMan-Ultimate/issues'),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.cloud_download, size: 14),
                    SizedBox(width: 6),
                    Text('Check for Updates / Releases'),
                  ],
                ),
                onPressed: () => _openUrl('https://github.com/sakfi/TaskMan-Ultimate/releases'),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.send, size: 14),
                    SizedBox(width: 6),
                    Text('Telegram Contact (@SakFi)'),
                  ],
                ),
                onPressed: () => _openUrl('http://t.me/SakFi'),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.favorite_star, size: 14),
                    SizedBox(width: 6),
                    Text('Star on GitHub ⭐'),
                  ],
                ),
                onPressed: () => _openUrl('https://github.com/sakfi/TaskMan-Ultimate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagItem {
  final String label;
  final String value;
  const _DiagItem(this.label, this.value);
}
