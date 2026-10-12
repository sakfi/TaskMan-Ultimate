import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/taskman_provider.dart';
import '../services/system_extended_service.dart';

class ConnectionsView extends StatefulWidget {
  const ConnectionsView({super.key});

  @override
  State<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends State<ConnectionsView> {
  List<NetworkConnectionInfo> _connections = [];
  bool _loading = true;
  String _search = '';
  String _stateFilter = 'All'; // All, ESTABLISHED, LISTENING
  NetworkConnectionInfo? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final list = await SystemExtendedService.instance.getConnections(force: force);
    if (mounted) {
      setState(() {
        _connections = list;
        _loading = false;
        if (_selected != null) {
          _selected = _connections.firstWhere(
            (c) => c.localAddress == _selected!.localAddress && c.foreignAddress == _selected!.foreignAddress,
            orElse: () => _connections.first,
          );
        }
      });
    }
  }

  Color _getStateColor(String state) {
    switch (state.toUpperCase()) {
      case 'ESTABLISHED':
        return const Color(0xFF00E676);
      case 'LISTENING':
        return const Color(0xFF29B6F6);
      case 'TIME_WAIT':
        return Colors.orange;
      case 'CLOSE_WAIT':
        return const Color(0xFFFF5252);
      default:
        return Colors.grey[100];
    }
  }

  (String, Color) _resolveNetworkScope(String foreignAddress) {
    final ip = foreignAddress.split(':').first.trim().replaceAll('[', '').replaceAll(']', '');
    if (ip == '*' || ip == '0.0.0.0' || ip == '::' || ip == '') {
      return ('Listening', Colors.grey[100]);
    }
    if (ip.startsWith('127.')) {
      return ('Loopback', Colors.teal);
    }
    if (ip.startsWith('10.') || ip.startsWith('192.168.') || RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(ip)) {
      return ('LAN (Private)', const Color(0xFF64D2FF));
    }
    if (ip.startsWith('1.1.1.') || ip.startsWith('1.0.0.') || ip.startsWith('104.1') || ip.startsWith('162.15')) {
      return ('Cloudflare', Colors.orange);
    }
    if (ip.startsWith('8.8.') || ip.startsWith('142.25') || ip.startsWith('172.217') || ip.startsWith('216.58')) {
      return ('Google WAN', const Color(0xFF4285F4));
    }
    if (ip.startsWith('13.') || ip.startsWith('20.') || ip.startsWith('40.') || ip.startsWith('52.')) {
      return ('Azure / MS', const Color(0xFF0078D4));
    }
    if (ip.startsWith('3.') || ip.startsWith('54.') || ip.startsWith('44.')) {
      return ('AWS Cloud', const Color(0xFFFF9900));
    }
    if (ip.startsWith('23.') || ip.startsWith('104.')) {
      return ('Akamai CDN', const Color(0xFF00B0FF));
    }
    return ('Public WAN', const Color(0xFFAB47BC));
  }

  String _resolveCommonService(String address) {
    final parts = address.split(':');
    if (parts.length < 2) return '';
    final port = parts.last;
    switch (port) {
      case '80':
        return 'HTTP';
      case '443':
        return 'HTTPS';
      case '53':
        return 'DNS';
      case '22':
        return 'SSH';
      case '21':
        return 'FTP';
      case '3389':
        return 'RDP';
      case '8080':
        return 'HTTP-Alt';
      case '445':
        return 'SMB';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    final filtered = _connections.where((c) {
      final matchesSearch = c.localAddress.toLowerCase().contains(_search.toLowerCase()) ||
          c.foreignAddress.toLowerCase().contains(_search.toLowerCase()) ||
          c.pid.toString().contains(_search) ||
          c.protocol.toLowerCase().contains(_search.toLowerCase());
      if (!matchesSearch) return false;
      if (_stateFilter != 'All' && c.state.toUpperCase() != _stateFilter.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();

    String selectedProcName = '';
    if (_selected != null) {
      final match = provider.latestMetrics?.processes.where((p) => p.pid == _selected!.pid).firstOrNull;
      selectedProcName = match?.name ?? 'PID ${_selected!.pid}';
    }

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.globe, size: 22, color: skin.textAccent),
            const SizedBox(width: 10),
            Text('Network Intelligence', style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: skin.textAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filtered.length} active sockets',
                style: TextStyle(color: skin.textAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Button(
              onPressed: () => _load(force: true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 14),
                  SizedBox(width: 6),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // Filter Toolbar
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextBox(
                    placeholder: 'Filter by IP, port, protocol, PID...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (val) => setState(() => _search = val),
                  ),
                ),
                const SizedBox(width: 12),
                ComboBox<String>(
                  value: _stateFilter,
                  items: const [
                    ComboBoxItem(value: 'All', child: Text('All States')),
                    ComboBoxItem(value: 'ESTABLISHED', child: Text('ESTABLISHED Only')),
                    ComboBoxItem(value: 'LISTENING', child: Text('LISTENING Only')),
                  ],
                  onChanged: (val) => setState(() => _stateFilter = val ?? 'All'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: skin.tileBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border.all(color: skin.windowStroke),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Proto', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 4, child: Text('Local Address', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 4, child: Text('Foreign Address', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('ISP / Scope', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('State', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Process (PID)', style: TextStyle(color: skin.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

            // Connections Table
            Expanded(
              child: _loading
                  ? const Center(child: ProgressRing())
                  : Container(
                      decoration: BoxDecoration(
                        color: skin.tileBackground,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(_selected != null ? 0 : 6)),
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
                          final c = filtered[idx];
                          final isSelected = _selected?.localAddress == c.localAddress && _selected?.foreignAddress == c.foreignAddress;
                          final (scopeLabel, scopeColor) = _resolveNetworkScope(c.foreignAddress);
                          final svc = _resolveCommonService(c.foreignAddress);
                          final procMatch = provider.latestMetrics?.processes.where((p) => p.pid == c.pid).firstOrNull;
                          final procLabel = procMatch != null ? '${procMatch.name} (${c.pid})' : '${c.pid}';

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = c),
                            child: Container(
                              color: isSelected
                                  ? skin.textAccent.withValues(alpha: 0.18)
                                  : (idx.isEven ? skin.tileBackground : skin.tileBackground.withValues(alpha: 0.7)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      c.protocol,
                                      style: TextStyle(
                                        color: c.protocol == 'TCP' ? const Color(0xFF64D2FF) : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      c.localAddress,
                                      style: TextStyle(color: skin.textPrimary, fontFamily: 'Consolas', fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.foreignAddress,
                                            style: TextStyle(color: skin.textSecondary, fontFamily: 'Consolas', fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (svc.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: skin.textAccent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              svc,
                                              style: TextStyle(color: skin.textAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Scope / ISP Badge
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: scopeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: scopeColor.withValues(alpha: 0.4), width: 0.8),
                                          ),
                                          child: Text(
                                            scopeLabel,
                                            style: TextStyle(
                                              color: scopeColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      c.state.isEmpty ? '-' : c.state,
                                      style: TextStyle(
                                        color: _getStateColor(c.state),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      procLabel,
                                      style: TextStyle(color: skin.textPrimary, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
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

            // Selected Socket Inspector Card
            if (_selected != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: skin.tileBackground,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                  border: Border.all(color: skin.windowStroke),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.plug_connected, size: 16, color: skin.textAccent),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_selected!.protocol} ${_selected!.localAddress} ➔ ${_selected!.foreignAddress}',
                              style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${_selected!.state.isEmpty ? 'ACTIVE' : _selected!.state})',
                              style: TextStyle(color: _getStateColor(_selected!.state), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Owner: $selectedProcName (PID: ${_selected!.pid})',
                          style: TextStyle(color: skin.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Button(
                      onPressed: () {
                        final ip = _selected!.foreignAddress.split(':').first;
                        Clipboard.setData(ClipboardData(text: ip));
                        displayInfoBar(
                          context,
                          builder: (c, close) => InfoBar(
                            title: const Text('Copied'),
                            content: Text('Copied foreign IP $ip to clipboard'),
                            severity: InfoBarSeverity.info,
                            onClose: close,
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.copy, size: 12),
                          SizedBox(width: 4),
                          Text('Copy IP'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selected!.pid > 4)
                      FilledButton(
                        style: ButtonStyle(backgroundColor: WidgetStateProperty.all(const Color(0xFFC42B1C))),
                        onPressed: () {
                          provider.terminateProcess(_selected!.pid);
                          _load(force: true);
                        },
                        child: Text('Kill PID ${_selected!.pid}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
