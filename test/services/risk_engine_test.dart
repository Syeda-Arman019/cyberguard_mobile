import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/services/risk_engine.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) _handler;
  MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('RiskEngine', () {
    late RiskEngine engine;

    setUp(() {
      engine = RiskEngine();
    });

    test('clean HTTPS domain returns safe score and none threatType', () async {
      final result = await engine.analyzeUrl('https://example.com', ScanSource.manual);

      expect(result.url, 'https://example.com');
      expect(result.riskScore, 0);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.threatType, ThreatType.none);
      expect(result.source, ScanSource.manual);
      expect(result.reasons, contains('No major security threats or suspicious indicators were detected.'));
      expect(result.recommendation, contains('No major security indicators detected'));
    });

    test('scores No HTTPS (+15)', () async {
      final result = await engine.analyzeUrl('http://example.com', ScanSource.manual);

      expect(result.riskScore, 15);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.reasons, contains('This website does not use a secure HTTPS connection.'));
    });

    test('scores IP address instead of domain (+20)', () async {
      // https://192.168.1.1 -> IP(+20), HTTPS is present
      final result = await engine.analyzeUrl('https://192.168.1.1', ScanSource.manual);

      expect(result.riskScore, 20);
      expect(result.reasons, contains('This link uses a raw IP address instead of a standard domain name.'));
    });

    test('scores phishing keywords (+10)', () async {
      // https://example.com/login -> phishing keyword (+10)
      final result = await engine.analyzeUrl('https://example.com/login', ScanSource.manual);

      expect(result.riskScore, 10);
      expect(result.reasons, contains('The web address contains sensitive account or security-related keywords.'));
    });

    test('scores long URL > 75 chars (+5)', () async {
      final longPath = 'a' * 80;
      final result = await engine.analyzeUrl('https://example.com/$longPath', ScanSource.manual);

      expect(result.riskScore, 5);
      expect(result.reasons, contains('The URL is unusually long, which attackers often use to hide malicious parameters.'));
    });

    test('identifies brand impersonation (+15) and sets threatType to brandImpersonation', () async {
      // Resembles paypal but is not legitimate paypal
      final result = await engine.analyzeUrl('https://paypal-security-alert.com', ScanSource.qr);

      expect(result.riskScore, 15);
      expect(result.threatType, ThreatType.brandImpersonation);
      expect(result.reasons, contains('The domain resembles a well-known brand but is not an official domain.'));
      expect(result.recommendation, contains('imitate a legitimate brand'));
      expect(result.source, ScanSource.qr);
    });

    test('does not flag legitimate brand domain as impersonation', () async {
      final result = await engine.analyzeUrl('https://paypal.com', ScanSource.manual);

      expect(result.threatType, ThreatType.none);
      expect(result.riskScore, 0);
    });

    test('triggers multiple local flags and classifies as suspiciousDomain', () async {
      // http://192.168.1.1/login -> No HTTPS (+15) + IP (+20) + Keyword (+10) = 45 -> suspicious
      final result = await engine.analyzeUrl('http://192.168.1.1/login', ScanSource.share);

      expect(result.riskScore, 45);
      expect(result.riskLevel, RiskLevel.suspicious);
      expect(result.threatType, ThreatType.suspiciousDomain);
      expect(result.source, ScanSource.share);
      expect(result.recommendation, contains('Multiple risk indicators'));
    });

    test('caps riskScore at 100 and classifies as malicious for high cumulative risk', () async {
      // http://192.168.1.1/login-verify-account-update-bank-security-now-immediately-long-path-exceeding-seventy-five-characters-total-length.xyz
      // No HTTPS (15) + IP (20) + Phishing Keyword (10) + Long URL (5) = 50.
      // Now combined with Google flag (50) -> 100
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'matches': [
              {'threatType': 'SOCIAL_ENGINEERING'}
            ]
          }),
          200,
        );
      });

      // Temporary engine using mock client
      final engineWithMock = RiskEngine(httpClient: mockClient);
      final longUrl = 'http://192.168.1.1/login-${'x' * 80}';

      final result = await engineWithMock.analyzeUrl(longUrl, ScanSource.autoProtection);

      expect(result.riskScore, 100); // 50 (Google match) + 15 (No HTTPS) + 20 (IP) + 10 (Keywords) + 5 (Length) = 100
      expect(result.riskLevel, RiskLevel.malicious);
    });

    test('Google Safe Browsing SOCIAL_ENGINEERING flags phishing threat (+50) and malware flag (+50)', () async {
      final mockPhishingClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'matches': [
              {'threatType': 'SOCIAL_ENGINEERING'}
            ]
          }),
          200,
        );
      });

      final phishingEngine = RiskEngine(apiKey: 'TEST_KEY', httpClient: mockPhishingClient);
      final phishResult = await phishingEngine.analyzeUrl('https://example.com', ScanSource.manual);

      expect(phishResult.riskScore, 50);
      expect(phishResult.riskLevel, RiskLevel.suspicious);
      expect(phishResult.threatType, ThreatType.phishing);
      expect(phishResult.reasons, contains('Google Safe Browsing flagged this URL as an active phishing threat.'));
      expect(phishResult.recommendation, contains('Do not enter passwords, OTPs'));

      // Test MALWARE flag
      final mockMalwareClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'matches': [
              {'threatType': 'MALWARE'}
            ]
          }),
          200,
        );
      });

      final malwareEngine = RiskEngine(apiKey: 'TEST_KEY', httpClient: mockMalwareClient);
      final malwareResult = await malwareEngine.analyzeUrl('https://example.com', ScanSource.manual);

      expect(malwareResult.threatType, ThreatType.malware);
      expect(malwareResult.reasons, contains('Google Safe Browsing flagged this URL as distributing malware or harmful software.'));
      expect(malwareResult.recommendation, contains('Do not open this link or download files'));
    });

    test('reaches 100 max score and malicious level when multiple flags and Google match trigger', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'matches': [
              {'threatType': 'SOCIAL_ENGINEERING'}
            ]
          }),
          200,
        );
      });

      // Google (50) + No HTTPS (15) + IP (20) + Phishing Keyword (10) + Long (5) + Brand (15) = 115 -> clamped to 100
      final engineWithMock = RiskEngine(apiKey: 'TEST_KEY', httpClient: mockClient);
      final complexUrl = 'http://192.168.1.1/paypal-login-account-update-${'x' * 80}';

      final result = await engineWithMock.analyzeUrl(complexUrl, ScanSource.autoProtection);

      expect(result.riskScore, 100);
      expect(result.riskLevel, RiskLevel.malicious);
      expect(result.threatType, ThreatType.phishing);
      expect(result.source, ScanSource.autoProtection);
    });

    test('handles network exceptions gracefully without crashing', () async {
      final mockClient = MockHttpClient((request) async {
        throw Exception('Connection reset by peer');
      });

      final engineWithException = RiskEngine(apiKey: 'TEST_KEY', httpClient: mockClient);
      final result = await engineWithException.analyzeUrl('https://example.com', ScanSource.manual);

      expect(result.riskScore, 0);
      expect(result.riskLevel, RiskLevel.safe);
    });
  });
}
