import 'package:flutter/material.dart';
import '../../models/scan_result.dart';
import 'package:intl/intl.dart';

/// Reusable card widget to display the complete security scan results.
class ResultCard extends StatelessWidget {
  final ScanResult scanResult;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onDelete; // optional delete callback

  const ResultCard({
    super.key,
    required this.scanResult,
    this.onAction,
    this.actionLabel,
    this.onDelete,
  });

  /// Maps [RiskLevel] to thematic status colors.
  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return Colors.green;
      case RiskLevel.suspicious:
        return Colors.orange;
      case RiskLevel.malicious:
        return Colors.red;
    }
  }

  /// Converts [ThreatType] into human-readable English text.
  String _formatThreatType(ThreatType type) {
    switch (type) {
      case ThreatType.none:
        return 'None (Clean)';
      case ThreatType.phishing:
        return 'Phishing';
      case ThreatType.malware:
        return 'Malware';
      case ThreatType.suspiciousDomain:
        return 'Suspicious Domain';
      case ThreatType.brandImpersonation:
        return 'Brand Impersonation';
    }
  }

  /// Converts [ScanSource] into human-readable label.
  String _formatSource(ScanSource source) {
    switch (source) {
      case ScanSource.manual:
        return 'Manual Input';
      case ScanSource.qr:
        return 'QR Code Scanner';
      case ScanSource.share:
        return 'Shared Link';
      case ScanSource.autoProtection:
        return 'Auto Protection';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayRiskLevel = scanResult.threatType == ThreatType.suspiciousDomain ? RiskLevel.suspicious : scanResult.riskLevel;
    final riskColor = _getRiskColor(displayRiskLevel);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Score',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '${scanResult.riskScore}/100',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    scanResult.riskLevel.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Threat Type & Source Info
            Row(
              children: [
                const Text(
                  'Threat Type: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_formatThreatType(scanResult.threatType)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Source: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_formatSource(scanResult.source)),
              ],
            ),
            const SizedBox(height: 12),

            // Scanned URL
            Text(
              'URL: ${scanResult.url}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // Bulleted Reasons
            const Text(
              'Reasons:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...scanResult.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recommendation Callout Box
            const Text(
              'Recommendation:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: riskColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: riskColor.withAlpha(80)),
              ),
              child: Text(
                scanResult.recommendation,
                style: TextStyle(
                  color: riskColor.withAlpha(230),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Optional action button (e.g. "Scan Another QR Code")
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
