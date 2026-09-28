import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/screens/widgets/result_card.dart';

void main() {
  group('ResultCard', () {
    testWidgets('renders all ScanResult details accurately', (WidgetTester tester) async {
      bool actionTapped = false;

      final scanResult = ScanResult(
        url: 'https://malicious-phish.xyz/login',
        riskScore: 75,
        riskLevel: RiskLevel.malicious,
        threatType: ThreatType.phishing,
        reasons: const [
          'Google Safe Browsing flagged this URL as an active phishing threat.',
          'The web address contains sensitive account or security-related keywords.',
        ],
        recommendation: 'Do not enter passwords, OTPs, or any banking information.',
        source: ScanSource.qr,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(
              scanResult: scanResult,
              onAction: () => actionTapped = true,
              actionLabel: 'Scan Another QR Code',
            ),
          ),
        ),
      );

      // Verify Score & Level
      expect(find.text('75/100'), findsOneWidget);
      expect(find.text('MALICIOUS'), findsOneWidget);

      // Verify Threat Type & Source
      expect(find.text('Phishing'), findsOneWidget);
      expect(find.text('QR Code Scanner'), findsOneWidget);

      // Verify URL
      expect(find.text('URL: https://malicious-phish.xyz/login'), findsOneWidget);

      // Verify Reasons
      expect(
        find.text('Google Safe Browsing flagged this URL as an active phishing threat.'),
        findsOneWidget,
      );
      expect(
        find.text('The web address contains sensitive account or security-related keywords.'),
        findsOneWidget,
      );

      // Verify Recommendation
      expect(
        find.text('Do not enter passwords, OTPs, or any banking information.'),
        findsOneWidget,
      );

      // Verify Action Button
      expect(find.text('Scan Another QR Code'), findsOneWidget);
      await tester.tap(find.text('Scan Another QR Code'));
      expect(actionTapped, isTrue);
    });
  });
}
