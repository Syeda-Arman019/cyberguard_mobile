// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../services/history_service.dart';
import '../models/scan_result.dart';
import 'widgets/cyber_components.dart';
import 'scan_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<ScanResult> scans;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  void _loadScans() {
    scans = HistoryService.instance.getAllScans();
    setState(() {});
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear All Scan History?'),
        content: const Text(
          'This action cannot be undone. All security audit logs will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: CyberColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CyberColors.malicious,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.instance.deleteAllScans();
      _loadScans();
    }
  }

  Future<void> _deleteScan(ScanResult scan) async {
    await HistoryService.instance.deleteScan(scan.timestamp);
    _loadScans();
  }

  Future<void> _confirmDelete(ScanResult scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('Remove this security scan from history logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: CyberColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CyberColors.malicious,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteScan(scan);
    }
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return CyberColors.safe;
      case RiskLevel.suspicious:
        return CyberColors.suspicious;
      case RiskLevel.malicious:
        return CyberColors.malicious;
    }
  }

  IconData _getSourceIcon(ScanSource source) {
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

  String _formatThreatType(ThreatType type) {
    switch (type) {
      case ThreatType.none:
        return 'Clean';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Activity Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: CyberColors.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (scans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: CyberColors.malicious),
              tooltip: 'Delete All History',
              onPressed: _confirmDeleteAll,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: scans.isEmpty
              ? CyberEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No Scan History Recorded',
                  description:
                      'When you scan URLs manually, via QR code, or through app shares, your security audit log will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    final riskColor = _getRiskColor(scan.riskLevel);

                    return Dismissible(
                      key: ValueKey(scan.timestamp.toIso8601String()),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _confirmDelete(scan);
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: CyberColors.malicious.withAlpha(200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.delete_outline, color: Colors.white),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: CyberCard(
                          padding: const EdgeInsets.all(14),
                          borderColor: riskColor.withAlpha(80),
                          onTap: () async {
                            final deleted = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => ScanDetailScreen(scanResult: scan),
                              ),
                            );
                            if (deleted == true) {
                              _loadScans();
                            }
                          },
                          child: Row(
                            children: [
                              // Risk indicator bar & score
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: riskColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: riskColor.withAlpha(90)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${scan.riskScore}',
                                      style: TextStyle(
                                        color: riskColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      'SCORE',
                                      style: TextStyle(
                                        color: riskColor.withAlpha(200),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // URL & Threat Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        RiskBadge(
                                          riskLevel: scan.riskLevel,
                                          isSmall: true,
                                        ),
                                        const SizedBox(width: 8),
                                        if (scan.threatType != ThreatType.none)
                                          Expanded(
                                            child: Text(
                                              _formatThreatType(scan.threatType),
                                              style: TextStyle(
                                                color: riskColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      scan.url,
                                      style: const TextStyle(
                                        color: CyberColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          _getSourceIcon(scan.source),
                                          size: 13,
                                          color: CyberColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM d, hh:mm a').format(scan.timestamp),
                                          style: const TextStyle(
                                            color: CyberColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(
                                Icons.chevron_right_rounded,
                                color: CyberColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
