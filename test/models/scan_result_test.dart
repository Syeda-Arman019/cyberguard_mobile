import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';

void main() {
  group('ScanResult', () {
    final testTime = DateTime.parse('2026-09-18T12:00:00.000Z');

    test('instantiates with valid fields', () {
      final result = ScanResult(
        url: 'https://example.com',
        riskScore: 25,
        riskLevel: RiskLevel.safe,
        threatType: ThreatType.none,
        reasons: ['Valid SSL certificate', 'No blacklists reported'],
        recommendation: 'Safe to browse',
        source: ScanSource.manual,
        timestamp: testTime,
      );

      expect(result.url, 'https://example.com');
      expect(result.riskScore, 25);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.threatType, ThreatType.none);
      expect(result.reasons.length, 2);
      expect(result.recommendation, 'Safe to browse');
      expect(result.source, ScanSource.manual);
      expect(result.timestamp, testTime);
    });

    test('serializes to JSON correctly', () {
      final result = ScanResult(
        url: 'https://malicious-phish.xyz',
        riskScore: 92,
        riskLevel: RiskLevel.malicious,
        threatType: ThreatType.phishing,
        reasons: ['Suspicious TLD', 'Detected in Google Safe Browsing'],
        recommendation: 'Do not open or enter credentials',
        source: ScanSource.qr,
        timestamp: testTime,
      );

      final json = result.toJson();

      expect(json['url'], 'https://malicious-phish.xyz');
      expect(json['riskScore'], 92);
      expect(json['riskLevel'], 'malicious');
      expect(json['threatType'], 'phishing');
      expect(json['reasons'], contains('Suspicious TLD'));
      expect(json['recommendation'], 'Do not open or enter credentials');
      expect(json['source'], 'qr');
      expect(json['timestamp'], testTime.toIso8601String());
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'url': 'http://suspicious-site.tk',
        'riskScore': 65,
        'riskLevel': 'suspicious',
        'threatType': 'suspiciousDomain',
        'reasons': ['Unencrypted HTTP connection', 'Newly registered domain'],
        'recommendation': 'Proceed with extreme caution',
        'source': 'share',
        'timestamp': testTime.toIso8601String(),
      };

      final result = ScanResult.fromJson(json);

      expect(result.url, 'http://suspicious-site.tk');
      expect(result.riskScore, 65);
      expect(result.riskLevel, RiskLevel.suspicious);
      expect(result.threatType, ThreatType.suspiciousDomain);
      expect(result.reasons.length, 2);
      expect(result.recommendation, 'Proceed with extreme caution');
      expect(result.source, ScanSource.share);
      expect(result.timestamp, testTime);
    });

    test('handles fallback defaults on unknown/null JSON values gracefully', () {
      final result = ScanResult.fromJson({
        'url': 'https://unknown.com',
      });

      expect(result.url, 'https://unknown.com');
      expect(result.riskScore, 0);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.threatType, ThreatType.none);
      expect(result.reasons, isEmpty);
      expect(result.recommendation, '');
      expect(result.source, ScanSource.manual);
    });

    test('enforces riskScore 0-100 assertion', () {
      expect(
        () => ScanResult(
          url: 'https://test.com',
          riskScore: -1,
          riskLevel: RiskLevel.safe,
          threatType: ThreatType.none,
          reasons: const [],
          recommendation: '',
          source: ScanSource.manual,
          timestamp: testTime,
        ),
        throwsAssertionError,
      );

      expect(
        () => ScanResult(
          url: 'https://test.com',
          riskScore: 101,
          riskLevel: RiskLevel.safe,
          threatType: ThreatType.none,
          reasons: const [],
          recommendation: '',
          source: ScanSource.manual,
          timestamp: testTime,
        ),
        throwsAssertionError,
      );
    });
  });
}
