import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/screens/settings_screen.dart';
import 'package:cyberguard_mobile/services/history_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen', () {
    setUpAll(() async {
      Hive.init('./test_settings_hive');
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScanResultAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RiskLevelAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ThreatTypeAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ScanSourceAdapter());
      await HistoryService.instance.init();
    });

    setUp(() async {
      await HistoryService.instance.deleteAllScans();
    });

    testWidgets('renders all settings elements and toggles switches', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('URL Security Settings'), findsWidgets);
      expect(find.text('Manage your URL security preferences and permissions.'), findsOneWidget);

      // Section headers
      expect(find.text('SECURITY PREFERENCES'), findsOneWidget);
      expect(find.text('DEVICE PERMISSIONS'), findsOneWidget);
      expect(find.text('SECURITY ACTIVITY'), findsOneWidget);
      expect(find.text('DATA & STORAGE'), findsOneWidget);
      expect(find.text('SYSTEM INFORMATION'), findsOneWidget);

      // Toggles verification
      expect(find.text('🛡 Protection Mode'), findsOneWidget);
      expect(find.text('🔔 Security Notifications'), findsOneWidget);

      // Find and tap switches to test responsiveness
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // Toggle Protection Mode switch
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Permissions section verification
      expect(find.text('📷 Camera Permission'), findsOneWidget);
      expect(find.text('💬 SMS Permission'), findsOneWidget);

      // Total URLs scanned (initially 0)
      expect(find.text('Total URLs Scanned'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('displays correct total URLs scanned when history has scans', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed 3 scans
      for (int i = 1; i <= 3; i++) {
        await HistoryService.instance.saveScan(
          ScanResult(
            url: 'https://test$i.org',
            riskScore: i * 20,
            riskLevel: RiskLevel.safe,
            threatType: ThreatType.none,
            reasons: ['No threats detected'],
            recommendation: 'Safe to proceed.',
            source: ScanSource.manual,
            timestamp: DateTime.now(),
          ),
        );
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Expect total count 3
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Total URLs Scanned'), findsOneWidget);

      // Test "Clear All Scan History" button
      expect(find.text('Clear All Scan History'), findsOneWidget);
      await tester.tap(find.text('Clear All Scan History'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Clear All Scan History?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Total URLs count updates to 0
      expect(find.text('0'), findsOneWidget);
    });
  });
}
