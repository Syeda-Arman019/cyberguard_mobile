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

  testWidgets('BUG 1: low-score safe result is never displayed as Suspicious',
      (tester) async {
    // Engine verdict: score 15, safe, suspiciousDomain (2 local flags).
    // The badge must mirror the engine's riskLevel (SAFE), never escalate
    // the display to SUSPICIOUS for a within-Safe-range score.
    await tester.pumpWidget(_wrap(ResultCard(
      scanResult: _scan(15, RiskLevel.safe, ThreatType.suspiciousDomain),
    )));
    expect(find.text('15/100'), findsOneWidget);
    expect(find.text('SAFE'), findsOneWidget);
    expect(find.text('SUSPICIOUS'), findsNothing);
  });

  testWidgets('BUG 2: result card displays the EXACT submitted URL (scheme preserved)',
      (tester) async {
    const raw = 'http://example.com';
    final scan = ScanResult(
      url: raw,
      riskScore: 15,
      riskLevel: RiskLevel.safe,
      threatType: ThreatType.none,
      reasons: const ['This website does not use a secure HTTPS connection.'],
      recommendation: 'Test recommendation',
      source: ScanSource.manual,
      timestamp: DateTime(2026, 9, 27, 12, 0),
    );
    await tester.pumpWidget(_wrap(ResultCard(scanResult: scan)));

    // ResultCard prints scanResult.url verbatim; the http:// scheme must
    // never be rewritten to https:// anywhere in the display path.
    expect(find.textContaining('http://example.com'), findsOneWidget);
    expect(find.textContaining('https://example.com'), findsNothing);
  });
}
