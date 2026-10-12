import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/taskman_provider.dart';
import 'views/app_history_view.dart';
import 'views/benchmarks_view.dart';
import 'views/connections_view.dart';
import 'views/details_view.dart';
import 'views/disk_space_view.dart';
import 'views/drivers_view.dart';
import 'views/flight_recorder_view.dart';
import 'views/installed_apps_view.dart';
import 'views/performance_view.dart';
import 'views/power_freq_view.dart';
import 'views/processes_view.dart';
import 'views/services_view.dart';
import 'views/settings_view.dart';
import 'views/skin_browser_view.dart';
import 'views/startup_apps_view.dart';
import 'views/summary_view.dart';
import 'views/system_info_view.dart';
import 'views/thermals_view.dart';
import 'views/users_view.dart';
import 'widgets/custom_title_bar.dart';
import 'widgets/mini_hud_widget.dart';
import 'widgets/taskman_logo_widget.dart';
import 'widgets/top_menu_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      const windowOptions = WindowOptions(
        size: Size(1180, 780),
        minimumSize: Size(360, 240),
        center: true,
        title: 'TaskMan Ultimate',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {}
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskManProvider()),
      ],
      child: const TaskManApp(),
    ),
  );
}

class TaskManApp extends StatelessWidget {
  const TaskManApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    final isLight = skin.windowBackground.computeLuminance() > 0.5;
    final brightness = isLight ? Brightness.light : Brightness.dark;

    final fluentTheme = FluentThemeData(
      brightness: brightness,
      accentColor: skin.textAccent.toAccentColor(),
      scaffoldBackgroundColor: skin.windowBackground,
      cardColor: skin.tileBackground,
      typography: Typography.fromBrightness(
        brightness: brightness,
        color: skin.textPrimary,
      ),
    );

    return FluentApp(
      title: 'TaskMan Ultimate',
      debugShowCheckedModeBanner: false,
      theme: fluentTheme,
      darkTheme: fluentTheme,
      themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final ScrollController _paneScrollController = ScrollController();

  @override
  void dispose() {
    _paneScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskManProvider>();
    final skin = provider.currentSkin;

    // Mini Floating HUD mode
    if (provider.isMiniHudMode) {
      return const MiniHudWidget();
    }

    return Container(
      decoration: BoxDecoration(
        color: skin.windowBackground,
        border: Border.all(color: skin.windowStroke, width: 1),
        borderRadius: BorderRadius.circular(skin.cornerRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(skin.cornerRadius),
        child: Column(
          children: [
            // Custom Title Bar with Snap Layouts & Controls
            const CustomTitleBar(),

            // Classic Windows Menu Bar (File, View, Help)
            const TopMenuBar(),

            // Main Navigation View
            Expanded(
              child: NavigationView(
                pane: NavigationPane(
                  selected: _selectedIndex,
                  onChanged: (i) => setState(() => _selectedIndex = i),
                  displayMode: PaneDisplayMode.auto,
                  scrollController: _paneScrollController,
                  size: const NavigationPaneSize(
                    openMaxWidth: 205,
                    openWidth: 195,
                  ),
                  items: [
                    // --- GROUP 1: Core System Activity ---
                    // 1. Summary
                    PaneItem(
                      icon: const Icon(FluentIcons.home),
                      title: const Text('Summary'),
                      body: const SummaryView(),
                    ),
                    // 2. Performance
                    PaneItem(
                      icon: const Icon(FluentIcons.line_chart),
                      title: const Text('Performance'),
                      body: const PerformanceView(),
                    ),
                    // 3. Processes
                    PaneItem(
                      icon: const Icon(FluentIcons.task_manager),
                      title: const Text('Processes'),
                      body: const ProcessesView(),
                    ),
                    // 4. App History
                    PaneItem(
                      icon: const Icon(FluentIcons.history),
                      title: const Text('App history'),
                      body: const AppHistoryView(),
                    ),
                    // 5. Startup Apps
                    PaneItem(
                      icon: const Icon(FluentIcons.play),
                      title: const Text('Startup apps'),
                      body: const StartupAppsView(),
                    ),
                    // 6. Users
                    PaneItem(
                      icon: const Icon(FluentIcons.people),
                      title: const Text('Users'),
                      body: const UsersView(),
                    ),
                    // 7. Details
                    PaneItem(
                      icon: const Icon(FluentIcons.list),
                      title: const Text('Details'),
                      body: const DetailsView(),
                    ),
                    // 8. Services
                    PaneItem(
                      icon: const Icon(FluentIcons.repair),
                      title: const Text('Services'),
                      body: const ServicesView(),
                    ),

                    // [DIVIDER 1]
                    PaneItemSeparator(),

                    // --- GROUP 2: Telemetry & Diagnostics ---
                    // 9. System Info
                    PaneItem(
                      icon: const Icon(FluentIcons.info),
                      title: const Text('System info'),
                      body: const SystemInfoView(),
                    ),
                    // 10. Thermals
                    PaneItem(
                      icon: const Icon(FluentIcons.flame_solid),
                      title: const Text('Thermals'),
                      body: const ThermalsView(),
                    ),
                    // 11. Power & Freq
                    PaneItem(
                      icon: const Icon(FluentIcons.lightning_bolt),
                      title: const Text('Power & freq'),
                      body: const PowerFreqView(),
                    ),
                    // 12. Flight Recorder
                    PaneItem(
                      icon: const Icon(FluentIcons.send),
                      title: const Text('Flight recorder'),
                      body: const FlightRecorderView(),
                    ),
                    // 13. Connections
                    PaneItem(
                      icon: const Icon(FluentIcons.globe),
                      title: const Text('Connections'),
                      body: const ConnectionsView(),
                    ),
                    // 14. Installed Apps
                    PaneItem(
                      icon: const Icon(FluentIcons.bulleted_list_text),
                      title: const Text('Installed apps'),
                      body: const InstalledAppsView(),
                    ),
                    // 15. Drivers
                    PaneItem(
                      icon: const Icon(FluentIcons.hard_drive),
                      title: const Text('Drivers'),
                      body: const DriversView(),
                    ),
                    // 16. Disk Space
                    PaneItem(
                      icon: const Icon(FluentIcons.hard_drive_group),
                      title: const Text('Disk space'),
                      body: const DiskSpaceView(),
                    ),
                    // 17. Benchmarks
                    PaneItem(
                      icon: const Icon(FluentIcons.speed_high),
                      title: const Text('Benchmarks'),
                      body: const BenchmarksView(),
                    ),

                    // [DIVIDER 2]
                    PaneItemSeparator(),

                    // --- GROUP 3: Preferences ---
                    // 18. Settings
                    PaneItem(
                      icon: const Icon(FluentIcons.settings),
                      title: const Text('Settings'),
                      body: const SettingsView(),
                    ),
                    // 19. Colors
                    PaneItem(
                      icon: const Icon(FluentIcons.color),
                      title: const Text('Colors'),
                      body: const SkinBrowserView(),
                    ),
                  ],
                  footerItems: [
                    // Glowing TaskMan neon logo
                    PaneItemHeader(
                      header: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: TaskManLogoWidget(width: 175, height: 42),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
