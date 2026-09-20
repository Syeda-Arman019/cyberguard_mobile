// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/services/risk_engine.dart';

void main() async {
  final engine = RiskEngine();

  final sampleUrls = [
    {
      'title': '1. Legitimate Safe Website',
      'url': 'https://flutter.dev',
      'source': ScanSource.manual,
    },
    {
      'title': '2. Heuristic Phishing & Brand Impersonation (Local Checks)',
      'url': 'http://192.168.1.1/paypal-login-account-update-verify-credentials',
      'source': ScanSource.share,
    },
    {
      'title': '3. Official Google Safe Browsing Phishing Test URL',
      'url': 'http://testsafebrowsing.appspot.com/s/phishing.html',
      'source': ScanSource.qr,
    },
    {
      'title': '4. Official Google Safe Browsing Malware Test URL',
      'url': 'http://malware.testing.google.test/testing/malware/',
      'source': ScanSource.autoProtection,
    },
  ];

  print('====================================================');
  print('       CYBERGUARD MOBILE - RISK ENGINE TEST         ');
  print('====================================================\n');

  for (final sample in sampleUrls) {
    final title = sample['title'] as String;
    final url = sample['url'] as String;
    final source = sample['source'] as ScanSource;

    print('----------------------------------------------------');
    print('TEST CASE: $title');
    print('Testing URL: $url');
    print('Source: ${source.name}');
    print('Analyzing...');

    final stopwatch = Stopwatch()..start();
    final result = await engine.analyzeUrl(url, source);
    stopwatch.stop();

    print('\n[RESULT]');
    print(' Risk Score:      ${result.riskScore}/100');
    print(' Risk Level:      ${result.riskLevel.name.toUpperCase()}');
    print(' Threat Type:     ${result.threatType.name}');
    print(' Elapsed Time:    ${stopwatch.elapsedMilliseconds}ms');
    print(' Recommendation:  ${result.recommendation}');
    print(' Triggered Reasons:');
    for (final reason in result.reasons) {
      print('   • $reason');
    }
    print('\n JSON Output:');
    final encoder = const JsonEncoder.withIndent('  ');
    print(encoder.convert(result.toJson()));
    print('----------------------------------------------------\n');
  }

  print('====================================================');
  print('              ALL LIVE CHECKS COMPLETED             ');
  print('====================================================');
}
