import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taskman_ultimate/main.dart';
import 'package:taskman_ultimate/providers/taskman_provider.dart';

void main() {
  testWidgets('TaskManApp renders main navigation', (WidgetTester tester) async {
    final provider = TaskManProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskManProvider>.value(
        value: provider,
        child: const TaskManApp(),
      ),
    );
    expect(find.text('Processes'), findsOneWidget);

    // Unmount widget tree to dispose all widgets and animation controllers
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
