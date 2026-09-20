// lib/models/scan_result.dart
import 'package:hive/hive.dart';

part 'scan_result.g.dart';

@HiveType(typeId: 1)
enum RiskLevel {
  @HiveField(0)
  safe,
  @HiveField(1)
  suspicious,
  @HiveField(2)
  malicious,
}

@HiveType(typeId: 2)
enum ThreatType {
  @HiveField(0)
  none,
  @HiveField(1)
  phishing,
  @HiveField(2)
  malware,
  @HiveField(3)
  suspiciousDomain,
  @HiveField(4)
  brandImpersonation,
}

@HiveType(typeId: 3)
enum ScanSource {
  @HiveField(0)
  manual,
  @HiveField(1)
  qr,
  @HiveField(2)
  share,
  @HiveField(3)
  autoProtection,
}

@HiveType(typeId: 0)
class ScanResult extends HiveObject {
  @HiveField(0)
  final String url;
  @HiveField(1)
  final int riskScore; // 0-100
  @HiveField(2)
  final RiskLevel riskLevel;
  @HiveField(3)
  final ThreatType threatType;
  @HiveField(4)
  final List<String> reasons;
  @HiveField(5)
  final String recommendation;
  @HiveField(6)
  final ScanSource source;
  @HiveField(7)
  final DateTime timestamp;

  const ScanResult({
    required this.url,
    required this.riskScore,
    required this.riskLevel,
    required this.threatType,
    required this.reasons,
    required this.recommendation,
    required this.source,
    required this.timestamp,
  }) : assert(riskScore >= 0 && riskScore <= 100);

  Map<String, dynamic> toJson() => {
        'url': url,
        'riskScore': riskScore,
        'riskLevel': riskLevel.name,
        'threatType': threatType.name,
        'reasons': reasons,
        'recommendation': recommendation,
        'source': source.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        url: json['url'] as String,
        riskScore: json['riskScore'] as int,
        riskLevel: RiskLevel.values.byName(json['riskLevel'] as String),
        threatType: ThreatType.values.byName(json['threatType'] as String),
        reasons: List<String>.from(json['reasons'] as List),
        recommendation: json['recommendation'] as String,
        source: ScanSource.values.byName(json['source'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}