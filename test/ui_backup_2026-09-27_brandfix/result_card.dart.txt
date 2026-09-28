import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/scan_result.dart';
import 'cyber_components.dart';

class ResultCard extends StatelessWidget {
  final ScanResult scanResult;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onDelete;
  final bool isCompact;

  const ResultCard({
    super.key,
    required this.scanResult,
    this.onAction,
    this.actionLabel,
    this.onDelete,
    this.isCompact = false,
  });

  RiskLevel get _effectiveRiskLevel {
    if (scanResult.threatType == ThreatType.suspiciousDomain &&
        scanResult.riskLevel == RiskLevel.safe) {
      return RiskLevel.suspicious;
    }
    return scanResult.riskLevel;
  }

  Color get _riskColor {
    switch (_effectiveRiskLevel) {
      case RiskLevel.safe:
        return CyberColors.safe;
      case RiskLevel.suspicious:
        return CyberColors.suspicious;
      case RiskLevel.malicious:
        return CyberColors.malicious;
    }
  }

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

  IconData _sourceIcon(ScanSource source) {
    switch (source) {
      case ScanSource.manual:
        return Icons.link;
      case ScanSource.qr:
        return Icons.qr_code_scanner;
      case ScanSource.share:
        return Icons.share_rounded;
      case ScanSource.autoProtection:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor;

    return Card(
      color: CyberColors.cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: color.withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Risk Score & Risk Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Score',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                        color: CyberColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scanResult.riskScore}/100',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                RiskBadge(riskLevel: _effectiveRiskLevel),
              ],
            ),

            const SizedBox(height: 14),
            // Compact 0–100 score gauge. Visual only: the score, the level,
            // and the display-override behavior above are untouched. The
            // filled portion and the tick colors reuse the app-wide
            // thresholds (0–40 safe, 41–70 suspicious, 71–100 malicious).
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 8, color: CyberColors.bgDark.withAlpha(160)),
                  FractionallySizedBox(
                    widthFactor: (scanResult.riskScore.clamp(0, 100)) / 100.0,
                    child: Container(height: 8, color: color),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        const Spacer(),
                        Container(width: 1.5, color: CyberColors.bgDark.withAlpha(160)),
                        const Spacer(),
                        Container(width: 1.5, color: CyberColors.bgDark.withAlpha(160)),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0–40 Safe',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: CyberColors.safe.withAlpha(200))),
                Text('41–70 Suspicious',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: CyberColors.suspicious.withAlpha(200))),
                Text('71–100 Malicious',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: CyberColors.malicious.withAlpha(200))),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: CyberColors.border, height: 1),
            const SizedBox(height: 14),

            // URL Container with Copy button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CyberColors.bgDark.withAlpha(180),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CyberColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: CyberColors.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      'URL: ${scanResult.url}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CyberColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: CyberColors.textMuted),
                    tooltip: 'Copy URL',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: scanResult.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copied to clipboard'),
                          duration: Duration(seconds: 2),
                          backgroundColor: CyberColors.cardBgElevated,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Metadata: Threat Type, Source, Timestamp
            Row(
              children: [
                const Text(
                  'Threat Type: ',
                  style: TextStyle(
                    color: CyberColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatThreatType(scanResult.threatType),
                    style: TextStyle(
                      color: scanResult.threatType == ThreatType.none
                          ? CyberColors.safe
                          : color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_sourceIcon(scanResult.source), size: 15, color: CyberColors.textMuted),
                const SizedBox(width: 6),
                const Text(
                  'Source: ',
                  style: TextStyle(
                    color: CyberColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatSource(scanResult.source),
                    style: const TextStyle(
                      color: CyberColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 15, color: CyberColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(scanResult.timestamp),
                  style: const TextStyle(
                    color: CyberColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            if (!isCompact) ...[
              // Reasons Section
              if (scanResult.reasons.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Reasons:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: CyberColors.cyan,
                  ),
                ),
                const SizedBox(height: 8),
                ...scanResult.reasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(
                            _effectiveRiskLevel == RiskLevel.safe
                                ? Icons.check_circle_outline
                                : Icons.error_outline_rounded,
                            size: 14,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CyberColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Recommendation Box
              const SizedBox(height: 16),
              const Text(
                'Recommendation:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: CyberColors.cyan,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withAlpha(80),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _effectiveRiskLevel == RiskLevel.safe
                          ? Icons.verified_user_outlined
                          : Icons.shield_outlined,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        scanResult.recommendation,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 18),
              PrimaryCyberButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],

            if (onDelete != null) ...[
              const SizedBox(height: 10),
              SecondaryCyberButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                color: CyberColors.malicious,
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
