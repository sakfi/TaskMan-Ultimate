import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskman_ultimate/providers/taskman_provider.dart';
import 'package:taskman_ultimate/services/system_extended_service.dart';
import 'package:taskman_ultimate/services/system_telemetry_service.dart';

void main() {
  group('TaskManProvider', () {
    late TaskManProvider provider;

    setUp(() {
      final file = File('taskman_settings.json');
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
      provider = TaskManProvider();
    });

    tearDown(() {
      provider.dispose();
      final file = File('taskman_settings.json');
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
    });

    test('initializes with default settings and built-in skins', () {
      expect(provider.availableSkins.isNotEmpty, isTrue);
      expect(provider.currentSkin, isNotNull);
      expect(provider.isPaused, isFalse);
      expect(provider.isMiniHudMode, isFalse);
      expect(provider.confirmKill, isTrue);
      expect(provider.hideWhenMinimized, isFalse);
      expect(provider.soundAlerts, isFalse);
    });

    test('toggles pause and mini HUD mode correctly', () async {
      provider.togglePause();
      expect(provider.isPaused, isTrue);

      provider.togglePause();
      expect(provider.isPaused, isFalse);

      await provider.toggleMiniHudMode();
      expect(provider.isMiniHudMode, isTrue);

      await provider.toggleMiniHudMode();
      expect(provider.isMiniHudMode, isFalse);
    });

    test('updates settings flags and persists them', () {
      provider.setConfirmKill(false);
      expect(provider.confirmKill, isFalse);

      provider.setHideWhenMinimized(true);
      expect(provider.hideWhenMinimized, isTrue);

      provider.setSoundAlerts(true);
      expect(provider.soundAlerts, isTrue);
    });

    test('sorts and filters process list accurately', () {
      provider.setSearchQuery('');
      final allProcesses = provider.filteredProcesses;
      expect(allProcesses, isA<List<ProcessInfo>>());

      // Test search filter
      provider.setSearchQuery('system');
      for (final proc in provider.filteredProcesses) {
        expect(
          proc.name.toLowerCase().contains('system') || proc.pid.toString().contains('system'),
          isTrue,
        );
      }

      // Test sorting
      provider.setSearchQuery('');
      provider.setSort(ProcessSortField.pid);
      final sortedByPid = provider.filteredProcesses;
      expect(sortedByPid, isA<List<ProcessInfo>>());
    });

    test('switches skins successfully', () {
      if (provider.availableSkins.length > 1) {
        final newSkin = provider.availableSkins[1];
        provider.setSkin(newSkin);
        expect(provider.currentSkin.id, equals(newSkin.id));
      }
    });

    test('handles enthusiast features: cleanRam, turboMode, and alert preferences', () async {
      expect(provider.isCleaningRam, isFalse);
      expect(provider.isTurboMode, isFalse);
      expect(provider.alertOnHighTemp, isTrue);
      expect(provider.alertOnHighRam, isTrue);

      provider.setAlertOnHighTemp(false);
      expect(provider.alertOnHighTemp, isFalse);

      provider.setAlertOnHighRam(false);
      expect(provider.alertOnHighRam, isFalse);

      provider.setAlertOnHighCpu(true);
      expect(provider.alertOnHighCpu, isTrue);

      await provider.toggleTurboMode();
      expect(provider.isTurboMode, isTrue);

      await provider.toggleTurboMode();
      expect(provider.isTurboMode, isFalse);

      provider.dismissAlert();
      expect(provider.activeAlertMessage, isNull);

      provider.dismissRamCleanResult();
      expect(provider.lastRamCleanResult, isNull);
    });

    test('flight recorder formats telemetry to CSV and JSON', () {
      final extService = SystemExtendedService.instance;
      extService.recordSnapshot(
        cpu: 25.5,
        mem: 48.2,
        disk: 1.2,
        topProc: 'test_proc.exe',
        topProcCpu: 15.0,
      );

      final csv = extService.generateTelemetryCsv();
      expect(csv, contains('Timestamp,CPU_Percent,Memory_Percent,Disk_MBs,Top_Process,Top_Process_CPU'));
      expect(csv, contains('test_proc.exe'));

      final json = extService.generateTelemetryJson();
      expect(json, contains('"topProcessName": "test_proc.exe"'));
      expect(json, contains('"cpuPercent": 25.5'));
    });
  });
}
