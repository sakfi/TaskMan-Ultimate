import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taskman_ultimate/main.dart';
import 'package:taskman_ultimate/providers/taskman_provider.dart';
import 'package:taskman_ultimate/views/about_view.dart';
import 'package:taskman_ultimate/views/gpu_inspector_view.dart';

void main() {
  testWidgets('TaskManApp renders main navigation', (WidgetTester tester) async {
    final provider = TaskManProvider();
    if (!provider.isPaused) provider.togglePause();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskManProvider>.value(
        value: provider,
        child: const TaskManApp(),
      ),
    );
    expect(find.text('Processes'), findsOneWidget);
    expect(find.byIcon(FluentIcons.info), findsWidgets);

    // Unmount widget tree to dispose all widgets and animation controllers
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('AboutView renders branding and developer credits', (WidgetTester tester) async {
    final provider = TaskManProvider();
    if (!provider.isPaused) provider.togglePause();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskManProvider>.value(
        value: provider,
        child: const FluentApp(
          home: AboutView(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TASKMAN ULTIMATE'), findsOneWidget);
    expect(find.text('SakFi'), findsOneWidget);
    expect(find.text('Copy Diagnostics'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('GpuInspectorView renders adapter telemetry and WDDM process table', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = TaskManProvider();
    if (!provider.isPaused) provider.togglePause();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskManProvider>.value(
        value: provider,
        child: const FluentApp(
          home: GpuInspectorView(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GPU & AI Inspector'), findsOneWidget);
    expect(find.textContaining('DEDICATED VRAM:'), findsOneWidget);
    expect(find.text('WDDM MEMORY ACCOUNTING'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
