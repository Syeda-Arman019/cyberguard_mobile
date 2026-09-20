import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scan_result.dart';

/// Google Safe Browsing API Key constant.
/// Replace with your actual API key from Google Cloud Console.
// ignore: constant_identifier_names
const String GOOGLE_SAFE_BROWSING_API_KEY = 'AIzaSyCcORbkM9slYc0K-T7BdisM4CMrmQwsUP8';

/// Analysis engine that evaluates URL threats using Google Safe Browsing API
/// alongside heuristic local rule-based checks.
class RiskEngine {
  final String _apiKey;
  final http.Client _httpClient;

  /// Creates a [RiskEngine] with an optional [apiKey] and [http.Client].
  RiskEngine({
    String? apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey ?? GOOGLE_SAFE_BROWSING_API_KEY,
        _httpClient = httpClient ?? http.Client();

  /// Phishing-related keywords evaluated during heuristic analysis.
  static const List<String> _phishingKeywords = [
    'verify',
    'login',
    'secure',
    'bank',
    'update',
    'confirm',
    'account',
  ];

  /// Brand name to legitimate domain patterns mapping.
  static const Map<String, List<String>> _knownBrands = {
    'paypal': ['paypal.com'],
    'google': ['google.com'],
    'facebook': ['facebook.com', 'fb.com'],
    'amazon': ['amazon.com'],
    'apple': ['apple.com', 'icloud.com'],
  };

  /// Analyzes a [url] for security risks and returns a [ScanResult].
  ///
  /// Incorporates Google Safe Browsing lookup and local heuristic checks.
  /// Fully safeguarded against network and parsing failures.
  Future<ScanResult> analyzeUrl(String url, ScanSource source) async {
    try {
      final trimmedUrl = url.trim();
      final lowerUrl = trimmedUrl.toLowerCase();

      // Normalize URL for host parsing
      final parsedUri = _tryParseUri(trimmedUrl);
      final host = parsedUri?.host.toLowerCase() ?? '';

      // 1. Google Safe Browsing API Check
      final googleThreat = await _checkGoogleSafeBrowsing(trimmedUrl);

      // 2. Local Heuristic Checks
      final bool hasGoogleThreat = googleThreat != null;
      final bool isNoHttps = !lowerUrl.startsWith('https://');
      final bool isIpAddress = _isIpAddress(host);
      final bool hasPhishingKeyword = _hasPhishingKeywords(lowerUrl);
      final bool isLongUrl = trimmedUrl.length > 75;
      final bool isBrandImpersonation = _isBrandImpersonation(host);

      // Calculate risk score with defined weights
      int score = 0;
      final List<String> reasons = [];
      int localFlagsCount = 0;

      if (hasGoogleThreat) {
        score += 50;
        if (googleThreat == 'SOCIAL_ENGINEERING') {
          reasons.add('Google Safe Browsing flagged this URL as an active phishing threat.');
        } else {
          reasons.add('Google Safe Browsing flagged this URL as distributing malware or harmful software.');
        }
      }

      if (isNoHttps) {
        score += 15;
        localFlagsCount++;
        reasons.add('This website does not use a secure HTTPS connection.');
      }

      if (isIpAddress) {
        score += 20;
        localFlagsCount++;
        reasons.add('This link uses a raw IP address instead of a standard domain name.');
      }

      if (hasPhishingKeyword) {
        score += 10;
        localFlagsCount++;
        reasons.add('The web address contains sensitive account or security-related keywords.');
      }

      if (isLongUrl) {
        score += 5;
        localFlagsCount++;
        reasons.add('The URL is unusually long, which attackers often use to hide malicious parameters.');
      }

      if (isBrandImpersonation) {
        score += 15;
        localFlagsCount++;
        reasons.add('The domain resembles a well-known brand but is not an official domain.');
      }

      // Cap risk score between 0 and 100
      final int riskScore = score.clamp(0, 100);

      // Determine Risk Level: 0-30 safe, 31-60 suspicious, 61-100 malicious
      final RiskLevel riskLevel;
      if (riskScore <= 30) {
        riskLevel = RiskLevel.safe;
      } else if (riskScore <= 60) {
        riskLevel = RiskLevel.suspicious;
      } else {
        riskLevel = RiskLevel.malicious;
      }

      // Determine Threat Type based on triggered checks
      final ThreatType threatType;
      if (hasGoogleThreat) {
        if (googleThreat == 'SOCIAL_ENGINEERING') {
          threatType = ThreatType.phishing;
        } else {
          threatType = ThreatType.malware;
        }
      } else if (isBrandImpersonation) {
        threatType = ThreatType.brandImpersonation;
      } else if (localFlagsCount >= 2) {
        threatType = ThreatType.suspiciousDomain;
      } else {
        threatType = ThreatType.none;
      }

      // Default reason if no indicators detected
      if (reasons.isEmpty) {
        reasons.add('No major security threats or suspicious indicators were detected.');
      }

      // Determine Recommendation based on threatType
      final String recommendation = _buildRecommendation(threatType);

      return ScanResult(
        url: trimmedUrl,
        riskScore: riskScore,
        riskLevel: riskLevel,
        threatType: threatType,
        reasons: reasons,
        recommendation: recommendation,
        source: source,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      // Robust fallback in case of any unhandled parsing or system failure
      return ScanResult(
        url: url,
        riskScore: 0,
        riskLevel: RiskLevel.safe,
        threatType: ThreatType.none,
        reasons: const ['Unable to complete full analysis due to an invalid URL format.'],
        recommendation: 'Exercise caution and verify the URL manually.',
        source: source,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Calls the Google Safe Browsing v4 threatMatches:find endpoint.
  /// Returns the matched threatType string if flagged, or null if clean / failed.
  Future<String?> _checkGoogleSafeBrowsing(String url) async {
    // Skip if placeholder key is still in place or empty
    if (_apiKey.isEmpty || _apiKey == 'YOUR_API_KEY_HERE') {
      return null;
    }

    final endpoint = Uri.parse(
      'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$_apiKey',
    );

    final requestBody = jsonEncode({
      'client': {
        'clientId': 'cyberguard_mobile',
        'clientVersion': '1.0.0',
      },
      'threatInfo': {
        'threatTypes': [
          'MALWARE',
          'SOCIAL_ENGINEERING',
          'UNWANTED_SOFTWARE',
          'POTENTIALLY_HARMFUL_APPLICATION',
        ],
        'platformTypes': ['ANY_PLATFORM'],
        'threatEntryTypes': ['URL'],
        'threatEntries': [
          {'url': url}
        ],
      },
    });

    try {
      final response = await _httpClient
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final matches = data['matches'] as List<dynamic>?;
        if (matches != null && matches.isNotEmpty) {
          final firstMatch = matches.first as Map<String, dynamic>;
          return firstMatch['threatType'] as String?;
        }
      }
    } catch (_) {
      // Gracefully fall back to local rule-based checks upon network or timeout errors
    }

    return null;
  }

  /// Checks if the host represents a raw IPv4 or IPv6 address.
  bool _isIpAddress(String host) {
    if (host.isEmpty) return false;

    // IPv4 pattern: 4 numeric segments separated by dots
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipv4Regex.hasMatch(host)) {
      return true;
    }

    // IPv6 pattern: hexadecimal groups separated by colons
    final ipv6Regex = RegExp(r'^[0-9a-fA-F:]+$');
    if (host.contains(':') && ipv6Regex.hasMatch(host)) {
      return true;
    }

    return false;
  }

  /// Checks if the URL contains any common phishing keywords.
  bool _hasPhishingKeywords(String lowerUrl) {
    return _phishingKeywords.any((keyword) => lowerUrl.contains(keyword));
  }

  /// Checks if the host imitates a known brand without being their official domain.
  bool _isBrandImpersonation(String host) {
    if (host.isEmpty) return false;

    for (final entry in _knownBrands.entries) {
      final brand = entry.key;
      final legitDomains = entry.value;

      if (host.contains(brand)) {
        bool isLegitimate = false;

        for (final legit in legitDomains) {
          if (host == legit || host.endsWith('.$legit')) {
            isLegitimate = true;
            break;
          }
        }

        // Support international country-code TLDs for google and amazon (e.g., google.co.uk, amazon.de)
        if (!isLegitimate && (brand == 'google' || brand == 'amazon')) {
          final cctldPattern = RegExp('^([a-z0-9-]+\\.)*$brand\\.[a-z]{2,3}(\\.[a-z]{2})?\$');
          if (cctldPattern.hasMatch(host)) {
            isLegitimate = true;
          }
        }

        if (!isLegitimate) {
          return true;
        }
      }
    }

    return false;
  }

  /// Generates clear, actionable recommendation text based on the threat type.
  String _buildRecommendation(ThreatType threatType) {
    switch (threatType) {
      case ThreatType.phishing:
        return 'Do not enter passwords, OTPs, or any banking and personal information on this site.';
      case ThreatType.malware:
        return 'Do not open this link or download files, as it may infect your device.';
      case ThreatType.brandImpersonation:
        return 'Exercise extreme caution. This site appears to imitate a legitimate brand to deceive visitors.';
      case ThreatType.suspiciousDomain:
        return 'Proceed with caution. Multiple risk indicators were detected on this domain.';
      case ThreatType.none:
        return 'No major security indicators detected. Safe to browse.';
    }
  }

  /// Safely attempts to parse the URL, adding a scheme if necessary to extract the host.
  Uri? _tryParseUri(String url) {
    try {
      if (url.contains('://')) {
        return Uri.parse(url);
      }
      return Uri.parse('http://$url');
    } catch (_) {
      return null;
    }
  }
}
