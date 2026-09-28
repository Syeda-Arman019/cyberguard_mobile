import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/screens/dashboard_screen.dart';
import 'package:cyberguard_mobile/services/history_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  group('DashboardScreen', () {
    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('dashboard_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScanResultAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RiskLevelAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ThreatTypeAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ScanSourceAdapter());
      await HistoryService.instance.init();
    });

    setUp(() async {
      await HistoryService.instance.deleteAllScans();
    });

    testWidgets('renders empty state correctly when no scans exist', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('URL Security'), findsOneWidget);
      expect(find.text('Protection ON'), findsOneWidget);

      // Statistics showing 0
      expect(find.text('TOTAL SCANS'), findsOneWidget);
      expect(find.text('SAFE'), findsOneWidget);
      expect(find.text('SUSPICIOUS'), findsOneWidget);
      expect(find.text('MALICIOUS'), findsOneWidget);

      // Empty states
      expect(find.text('No Scan History Available'), findsOneWidget);
      expect(find.text('Scan more URLs to build your risk trend.'), findsOneWidget);
      expect(find.text('No scans available yet'), findsOneWidget);
      expect(find.text('Start scanning URLs to build your security insights.'), findsOneWidget);

      // Full Security CTA
      expect(find.text('View Full URL Security'), findsOneWidget);
    });

    testWidgets('renders real scan statistics and highest risk card when scans exist', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Add test scans
      final scan1 = ScanResult(
        url: 'https://safe-domain.com',
        riskScore: 10,
        riskLevel: RiskLevel.safe,
        threatType: ThreatType.none,
        reasons: ['Valid SSL certificate', 'No reputation flags'],
        recommendation: 'This site appears safe to visit.',
        source: ScanSource.manual,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final scan2 = ScanResult(
        url: 'https://phishing-bank-login.xyz',
        riskScore: 88,
        riskLevel: RiskLevel.malicious,
        threatType: ThreatType.phishing,
        reasons: ['Domain matches credential harvester pattern', 'Phishing keywords detected'],
        recommendation: 'Block this site immediately.',
        source: ScanSource.qr,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await HistoryService.instance.saveScan(scan1);
      await HistoryService.instance.saveScan(scan2);

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Stats counts
      expect(find.text('2'), findsWidgets); // Total scans
      expect(find.text('1'), findsWidgets); // Safe & Malicious counts

      // Donut Legend
      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Malicious'), findsOneWidget);

      // Highest Risk Detected
      expect(find.text('HIGH RISK'), findsOneWidget);
      expect(find.text('88 / 100'), findsOneWidget);
      expect(find.text('https://phishing-bank-login.xyz'), findsOneWidget);
      expect(find.text('Phishing-related threat'), findsOneWidget);

      // Security Insight
      expect(find.text('You have scanned 2 URLs. 1 was flagged as potentially risky.'), findsOneWidget);
    });
  });
}
