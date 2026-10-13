import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/taskman_provider.dart';

class TopMenuBar extends StatelessWidget {
  const TopMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: skin.headerBackground,
        border: Border(
          bottom: BorderSide(color: skin.windowStroke, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // File Menu
          DropDownButton(
            title: Text('File', style: TextStyle(color: skin.textPrimary, fontSize: 12)),
            items: [
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.play, size: 12),
                text: const Text('Run new task...'),
                onPressed: () {
                  Process.run('explorer.exe', ['Shell:::{2559a1f3-21d7-11d4-bdaf-00c04f60b9f0}']);
                },
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.command_prompt, size: 12),
                text: const Text('Launch Command Prompt'),
                onPressed: () {
                  Process.run('cmd.exe', ['/c', 'start']);
                },
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.code, size: 12),
                text: const Text('Launch PowerShell'),
                onPressed: () {
                  Process.run('powershell.exe', ['-NoExit']);
                },
              ),
              const MenuFlyoutSeparator(),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.chrome_close, size: 12),
                text: const Text('Exit'),
                onPressed: () async {
                  await windowManager.close();
                },
              ),
            ],
          ),

          const SizedBox(width: 4),

          // View Menu
          DropDownButton(
            title: Text('View', style: TextStyle(color: skin.textPrimary, fontSize: 12)),
            items: [
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.refresh, size: 12),
                text: const Text('Refresh Now'),
                onPressed: () {
                  provider.refreshNow();
                },
              ),
              MenuFlyoutSubItem(
                leading: const Icon(FluentIcons.timer, size: 12),
                text: const Text('Update Speed'),
                items: (context) => [
                  MenuFlyoutItem(
                    text: const Text('High (0.5s)'),
                    onPressed: () => provider.setRefreshInterval(const Duration(milliseconds: 500)),
                  ),
                  MenuFlyoutItem(
                    text: const Text('Normal (1.0s)'),
                    onPressed: () => provider.setRefreshInterval(const Duration(seconds: 1)),
                  ),
                  MenuFlyoutItem(
                    text: const Text('Low (2.5s)'),
                    onPressed: () => provider.setRefreshInterval(const Duration(milliseconds: 2500)),
                  ),
                  MenuFlyoutItem(
                    text: const Text('Paused'),
                    onPressed: () {
                      if (!provider.isPaused) provider.togglePause();
                    },
                  ),
                ],
              ),
              const MenuFlyoutSeparator(),
              MenuFlyoutItem(
                leading: Icon(
                  provider.showPerCoreCpu ? FluentIcons.check_mark : FluentIcons.line_chart,
                  size: 12,
                ),
                text: const Text('Show Logical Core Grid'),
                onPressed: () => provider.togglePerCoreCpu(),
              ),
              MenuFlyoutItem(
                leading: Icon(
                  provider.showKernelTimes ? FluentIcons.check_mark : FluentIcons.line_chart,
                  size: 12,
                ),
                text: const Text('Show Kernel Times'),
                onPressed: () => provider.toggleKernelTimes(),
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.mini_contract, size: 12),
                text: const Text('Mini HUD Mode'),
                onPressed: () => provider.toggleMiniHudMode(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
