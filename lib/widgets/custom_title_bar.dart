import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/taskman_provider.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: skin.headerBackground,
        border: Border(
          bottom: BorderSide(color: skin.headerStroke, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          // App Logo / Icon
          Icon(
            FluentIcons.diagnostic_data_bar_tooltip,
            size: 16,
            color: skin.textAccent,
          ),
          const SizedBox(width: 8),
          Text(
            'TaskMan Ultimate',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: skin.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 14),

          // Skin selector combo (all available skins)
          DropDownButton(
            title: Text(
              skin.name,
              style: TextStyle(
                fontSize: 11,
                color: skin.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            items: provider.availableSkins.map((s) {
              return MenuFlyoutItem(
                text: Text(s.name),
                leading: Icon(
                  s.id == skin.id ? FluentIcons.check_mark : FluentIcons.color,
                  size: 12,
                ),
                onPressed: () {
                  provider.setSkin(s);
                },
              );
            }).toList(),
          ),

          const SizedBox(width: 8),

          // Pause / Resume Toggle Button
          IconButton(
            icon: Icon(
              provider.isPaused ? FluentIcons.play : FluentIcons.pause,
              size: 12,
              color: provider.isPaused ? Colors.warningPrimaryColor : skin.textSecondary,
            ),
            onPressed: () {
              provider.togglePause();
            },
          ),

          const SizedBox(width: 4),

          // Mini HUD Mode Toggle Button
          IconButton(
            icon: Tooltip(
              message: 'Compact Floating Mini HUD Mode',
              child: Icon(
                FluentIcons.mini_contract,
                size: 12,
                color: skin.textSecondary,
              ),
            ),
            onPressed: () {
              provider.toggleMiniHudMode();
            },
          ),

          // Drag area
          const Expanded(
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),

          // Window Controls
          WindowCaptionButton.minimize(
            brightness: Brightness.dark,
            onPressed: () async => await windowManager.minimize(),
          ),
          WindowCaptionButton.maximize(
            brightness: Brightness.dark,
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          WindowCaptionButton.close(
            brightness: Brightness.dark,
            onPressed: () async => await windowManager.close(),
          ),
        ],
      ),
    );
  }
}
