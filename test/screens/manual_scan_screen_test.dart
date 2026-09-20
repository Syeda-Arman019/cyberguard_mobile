import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/screens/manual_scan_screen.dart';
import 'package:cyberguard_mobile/services/risk_engine.dart';

class FakeRiskEngine extends RiskEngine {
  final ScanResult resultToReturn;

  FakeRiskEngine(this.resultToReturn);

  @override
  Future<ScanResult> analyzeUrl(String url, ScanSource source) async {
    return resultToReturn;
  }
}

void main() {
  group('ManualScanScreen', () {
    testWidgets('renders input field, button, and initial state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ManualScanScreen(),
        ),
      );

      expect(find.text('Manual URL Scanner'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Analyze'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows validation error when analyzing with empty input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ManualScanScreen(),
        ),
      );

      await tester.tap(find.text('Analyze'));
      await tester.pump();

      expect(find.text('Please enter a URL to scan.'), findsOneWidget);
    });

    testWidgets('analyzes URL and displays risk score, badge, reasons, and recommendation',
        (WidgetTester tester) async {
      final fakeResult = ScanResult(
        url: 'http://testsafebrowsing.appspot.com/s/phishing.html',
        riskScore: 65,
        riskLevel: RiskLevel.malicious,
        threatType: ThreatType.phishing,
        reasons: const [
          'Google Safe Browsing flagged this URL as an active phishing threat.',
          'This website does not use a secure HTTPS connection.',
        ],
        recommendation: 'Do not enter passwords, OTPs, or any banking information.',
        source: ScanSource.manual,
        timestamp: DateTime.now(),
      );

      final fakeEngine = FakeRiskEngine(fakeResult);

      await tester.pumpWidget(
        MaterialApp(
          home: ManualScanScreen(riskEngine: fakeEngine),
        ),
      );

      // Enter URL
      await tester.enterText(
        find.byType(TextField),
        'http://testsafebrowsing.appspot.com/s/phishing.html',
      );

      // Tap Analyze
      await tester.tap(find.text('Analyze'));
      await tester.pump(); // Start async work
      await tester.pump(); // Finish async work

      // Verify Card appears
      expect(find.byType(Card), findsOneWidget);

      // Verify Risk Score and Badge
      expect(find.text('65/100'), findsOneWidget);
      expect(find.text('MALICIOUS'), findsOneWidget);
      expect(find.text('Threat Type: '), findsOneWidget);
      expect(find.text('Phishing'), findsOneWidget);

      // Verify reasons
      expect(
        find.text('Google Safe Browsing flagged this URL as an active phishing threat.'),
        findsOneWidget,
      );
      expect(
        find.text('This website does not use a secure HTTPS connection.'),
        findsOneWidget,
      );

      // Verify recommendation
      expect(
        find.text('Do not enter passwords, OTPs, or any banking information.'),
        findsOneWidget,
      );
    });
  });
}
