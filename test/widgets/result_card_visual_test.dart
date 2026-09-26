// Verifies the compact 0–100 risk-score visualization added to ResultCard.
// Purely presentational checks: the existing score, RiskBadge level, reasons
// and recommendation rendering are untouched.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/screens/widgets/result_card.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';

ScanResult _scan(int score, RiskLevel level, ThreatType type) {
  final scan = ScanResult(
    url: 'https://example.com/test',
    riskScore: score,
    riskLevel: level,
    threatType: type,
    reasons: const ['Test reason'],
    recommendation: 'Test recommendation',
    source: ScanSource.manual,
    timestamp: DateTime(2026, 9, 26, 12, 0),
  );
  return scan;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('ResultCard renders score, level badge and range labels',
      (tester) async {
    await tester.pumpWidget(_wrap(ResultCard(
      scanResult: _scan(65, RiskLevel.malicious, ThreatType.phishing),
    )));

    // Score and badge unchanged.
    expect(find.text('65/100'), findsOneWidget);
    expect(find.text('MALICIOUS'), findsOneWidget);

    // Gauge band captions are present.
    expect(find.text('0–40 Safe'), findsOneWidget);
    expect(find.text('41–70 Suspicious'), findsOneWidget);
    expect(find.text('71–100 Malicious'), findsOneWidget);

    // Existing content still renders.
    expect(find.text('Test reason'), findsOneWidget);
    expect(find.text('Test recommendation'), findsOneWidget);
  });

  testWidgets('Safe and suspicious scans also render the gauge captions',
      (tester) async {
    await tester.pumpWidget(_wrap(ResultCard(
      scanResult: _scan(20, RiskLevel.safe, ThreatType.none),
    )));
    expect(find.text('20/100'), findsOneWidget);
    expect(find.text('SAFE'), findsOneWidget);
    expect(find.text('0–40 Safe'), findsOneWidget);

    await tester.pumpWidget(_wrap(ResultCard(
      scanResult: _scan(50, RiskLevel.suspicious, ThreatType.suspiciousDomain),
    )));
    expect(find.text('50/100'), findsOneWidget);
    expect(find.text('SUSPICIOUS'), findsOneWidget);
    expect(find.text('41–70 Suspicious'), findsOneWidget);
  });
}
