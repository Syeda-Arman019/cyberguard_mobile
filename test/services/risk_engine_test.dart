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

    // --- URL normalization + decoding / traversal / encoding heuristics ---

    test('percent-encoded keyword is decoded and scored (+10)', () async {
      // %6C%6F%67%69%6E == "login" — must be caught after safe decoding.
      final result = await engine.analyzeUrl(
          'https://example.com/%6C%6F%67%69%6E', ScanSource.manual);

      expect(result.riskScore, 10);
      expect(result.reasons,
          contains('The web address contains sensitive account or security-related keywords.'));
    });

    test('path traversal pattern adds +10', () async {
      final result = await engine.analyzeUrl(
          'https://example.com/download?file=../../etc/passwd', ScanSource.manual);

      expect(result.riskScore, 10);
      expect(result.reasons, contains('Suspicious path traversal pattern detected.'));
    });

    test('double-encoded traversal adds suspicious-encoding +10', () async {
      final result = await engine.analyzeUrl(
          'https://example.com/a?x=%252e%252e%252f', ScanSource.manual);

      // %252e%252e%252f decodes to ../ so BOTH traversal (+10) and
      // suspicious-encoding (+10) fire.
      expect(result.riskScore, 20);
      expect(result.reasons, contains('Suspicious encoded URL pattern detected.'));
      expect(result.reasons, contains('Suspicious path traversal pattern detected.'));
    });

    test('legitimate percent-encoding alone does not flag', () async {
      // Ordinary escaped-space URL: decodes cleanly, no suspicious pattern.
      final result = await engine.analyzeUrl(
          'https://example.com/my%20page', ScanSource.manual);

      expect(result.riskScore, 0);
      expect(result.threatType, ThreatType.none);
    });

    test('original URL is preserved on the result (no decoded rewrite)', () async {
      const raw = 'https://example.com/%6C%6F%67%69%6E';
      final result = await engine.analyzeUrl(raw, ScanSource.manual);

      expect(result.url, raw);
    });

    // --- Verified brand registry ---

    test('official brand domains and subdomains are NOT flagged', () async {
      for (final url in [
        'https://www.paypal.com/',
        'https://google.com',
        'https://icloud.com',
        'https://mail.google.com',
      ]) {
        final result = await engine.analyzeUrl(url, ScanSource.manual);
        expect(result.threatType, ThreatType.none, reason: url);
        expect(result.riskScore, 0, reason: url);
      }
    });

    test('newly verified brands flag on non-official domains', () async {
      final result = await engine.analyzeUrl(
          'https://wellsfargo-alerts.com', ScanSource.manual);

      expect(result.threatType, ThreatType.brandImpersonation);
      expect(result.riskLevel, RiskLevel.suspicious); // override
      expect(result.riskScore, 15);
    });

    test('brand mention in PATH or QUERY is not impersonation', () async {
      final result = await engine.analyzeUrl(
          'https://www.example.com/news/paypal-announces-new-feature?q=netflix',
          ScanSource.manual);

      expect(result.threatType, ThreatType.none);
    });

    test('shared-infrastructure hosts are not flagged as impersonation', () async {
      final result = await engine.analyzeUrl(
          'https://mybucket.s3.amazonaws.com/paypal-info.html', ScanSource.manual);

      // Host is AWS infra: no impersonation. The word "paypal" in the path
      // must not contribute either.
      expect(result.threatType, ThreatType.none);
    });

    test('word containing a short brand token is not flagged', () async {
      // "purchase" contains "cha"? No — but "citizens" contains "citi".
      // citizensbank.com is a real unrelated bank: must NOT flag citi.
      final result = await engine.analyzeUrl(
          'https://www.citizensbank.com', ScanSource.manual);

      expect(result.threatType, ThreatType.none);
    });

    test('concatenated phishing pattern flags (applesupport-style)', () async {
      final result = await engine.analyzeUrl(
          'https://applesupport-verify.com', ScanSource.manual);

      expect(result.threatType, ThreatType.brandImpersonation);
    });

    test('punycode host adds suspicious-encoding +10', () async {
      final result = await engine.analyzeUrl(
          'https://xn--pple-43d.com', ScanSource.manual);

      expect(result.riskScore, 10);
      expect(result.reasons, contains('Suspicious encoded URL pattern detected.'));
    });

    // --- Registry audit regression: brand-owned infra must NOT flag ---

    test('Citi corporate domain is official, not impersonation', () async {
      final result = await engine.analyzeUrl(
          'https://www.citigroup.com/global/about-us', ScanSource.manual);

      expect(result.threatType, ThreatType.none);
    });

    test('Apple CDN, WhatsApp/Facebook net domains are official', () async {
      for (final url in [
        'https://cdn-apple.com/resource/some-asset',
        'https://static.whatsapp.net/rsrc.php/style.css',
        'https://www.facebook.net/some-page',
      ]) {
        final result = await engine.analyzeUrl(url, ScanSource.manual);
        expect(result.threatType, ThreatType.none, reason: url);
      }
    });

    test('Google infrastructure hosts are not brand impersonation', () async {
      for (final url in [
        'https://rr1---sn-xyz.googlevideo.com/videoplayback?id=abc',
        'https://www.googleadservices.com/pagead/conversion',
        'https://www.googletagmanager.com/gtm.js',
        'https://www.google-analytics.com/collect',
        'https://pagead2.googlesyndication.com/ads',
      ]) {
        final result = await engine.analyzeUrl(url, ScanSource.manual);
        expect(result.threatType, ThreatType.none, reason: url);
      }
    });

    test('Microsoft AAD login host is official, not impersonation', () async {
      final result = await engine.analyzeUrl(
          'https://login.microsoftonline.com/common/oauth2', ScanSource.manual);

      expect(result.threatType, ThreatType.none);
    });
  });
}
