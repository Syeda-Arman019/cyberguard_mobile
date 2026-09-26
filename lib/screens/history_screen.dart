// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../services/history_service.dart';
import '../models/scan_result.dart';
import 'widgets/cyber_components.dart';
import 'scan_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  /// Optional risk-level filter applied when the screen opens (used by the
  /// tappable dashboard stat cards, e.g. tapping MALICIOUS opens the log
  /// pre-filtered to malicious scans only). Null = show everything.
  final RiskLevel? initialFilter;

  /// Optional scan-source filter applied when the screen opens (used by the
  /// dashboard Scan Activity cards, e.g. tapping "Manual Scan" shows only
  /// manually scanned URLs). Null = show everything.
  final ScanSource? initialSource;

  const HistoryScreen({super.key, this.initialFilter, this.initialSource});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<ScanResult> scans;

  /// Active filters: start from the constructor params; the user can clear
  /// them with the filter chip(s) shown below the app bar.
  RiskLevel? _filter;
  ScanSource? _sourceFilter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _sourceFilter = widget.initialSource;
    _loadScans();
  }

  void _loadScans() {
    final all = HistoryService.instance.getAllScans();
    scans = all
        .where((s) => _filter == null || s.riskLevel == _filter)
        .where((s) => _sourceFilter == null || s.source == _sourceFilter)
        .toList();
    setState(() {});
  }

  String get _filterLabel {
    switch (_filter) {
      case RiskLevel.safe:
        return 'SAFE scans';
      case RiskLevel.suspicious:
        return 'SUSPICIOUS scans';
      case RiskLevel.malicious:
        return 'MALICIOUS scans';
      default:
        return '';
    }
  }

  String get _sourceFilterLabel {
    switch (_sourceFilter) {
      case ScanSource.manual:
        return 'Manual scans';
      case ScanSource.qr:
        return 'QR scans';
      case ScanSource.share:
        return 'Shared links';
      case ScanSource.autoProtection:
        return 'Auto Protection';
      default:
        return '';
    }
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
          child: Column(
            children: [
              if (_filter != null || _sourceFilter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      if (_filter != null)
                        FilterChip(
                          selected: true,
                          backgroundColor: CyberColors.cardBg,
                          selectedColor: CyberColors.cyan.withAlpha(40),
                          checkmarkColor: CyberColors.cyan,
                          label: Text(
                            'Filtered: $_filterLabel',
                            style: const TextStyle(
                              color: CyberColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() => _filter = null);
                            _loadScans();
                          },
                        ),
                      if (_sourceFilter != null) ...[
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: true,
                          backgroundColor: CyberColors.cardBg,
                          selectedColor: CyberColors.purple.withAlpha(40),
                          checkmarkColor: CyberColors.purple,
                          label: Text(
                            'Source: $_sourceFilterLabel',
                            style: const TextStyle(
                              color: CyberColors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() => _sourceFilter = null);
                            _loadScans();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(child: _buildHistoryBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryBody() {
    return Container(
      decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
      child: scans.isEmpty
          ? CyberEmptyState(
              icon: Icons.history_rounded,
              title: _filter == null && _sourceFilter == null
                  ? 'No Scan History Recorded'
                  : _filter != null
                      ? 'No $_filterLabel Recorded'
                      : 'No $_sourceFilterLabel Recorded',
              description: _filter == null && _sourceFilter == null
                  ? 'When you scan URLs manually, via QR code, or through app shares, your security audit log will appear here.'
                  : 'No scans match this filter yet. Clear the filter to see your full audit log.',
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
    );
  }
}
