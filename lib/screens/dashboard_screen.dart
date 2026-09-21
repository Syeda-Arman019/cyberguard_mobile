// lib/screens/dashboard_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';
import 'home_screen.dart';
import 'scan_detail_screen.dart';
import 'widgets/cyber_components.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<ScanResult> _scans;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final all = HistoryService.instance.getAllScans();
    setState(() => _scans = all);
  }

  int get _total => _scans.length;

  int get _safeCount =>
      _scans.where((s) => s.riskLevel == RiskLevel.safe).length;

  int get _suspiciousCount =>
      _scans.where((s) => s.riskLevel == RiskLevel.suspicious).length;

  int get _maliciousCount =>
      _scans.where((s) => s.riskLevel == RiskLevel.malicious).length;

  ScanResult? get _highestRisk {
    if (_scans.isEmpty) return null;
    return _scans.reduce((a, b) => a.riskScore >= b.riskScore ? a : b);
  }

  List<ScanResult> get _chronologicalScans {
    final list = List<ScanResult>.from(_scans);
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  String get _insightMessage {
    if (_total == 0) {
      return 'Start scanning URLs to build your security insights.';
    }
    final riskyCount = _suspiciousCount + _maliciousCount;
    return 'You have scanned $_total URL${_total == 1 ? '' : 's'}. '
        '$riskyCount ${riskyCount == 1 ? 'was' : 'were'} flagged as potentially risky.';
  }

  Future<void> _navigateToFullSecurity() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    // Refresh dashboard data when coming back from other screens
    _refresh();
  }

  Future<void> _viewHighestRiskDetail(ScanResult scan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanDetailScreen(scanResult: scan)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: CyberColors.cyan,
            backgroundColor: CyberColors.cardBg,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: [
                // 1. Dashboard Header
                _buildHeader(),
                const SizedBox(height: 20),

                // 2. Scan Statistics
                const SectionHeader(title: 'Scan Statistics'),
                const SizedBox(height: 10),
                _buildStatGrid(),
                const SizedBox(height: 22),

                // 3. Risk Distribution Chart
                const SectionHeader(title: 'Risk Distribution'),
                const SizedBox(height: 10),
                _buildDistributionCard(),
                const SizedBox(height: 22),

                // 4. Risk Score Trend
                const SectionHeader(title: 'Risk Score Trend'),
                const SizedBox(height: 10),
                _buildTrendCard(),
                const SizedBox(height: 22),

                // 5. Highest Risk Detected
                const SectionHeader(title: 'Highest Risk Detected'),
                const SizedBox(height: 10),
                _buildHighestRiskCard(),
                const SizedBox(height: 22),

                // 6. Security Insight
                const SectionHeader(title: 'Security Insight'),
                const SizedBox(height: 10),
                _buildInsightCard(),
                const SizedBox(height: 26),

                // 7. View Full URL Security Button
                PrimaryCyberButton(
                  label: 'View Full URL Security',
                  icon: Icons.shield_rounded,
                  onPressed: _navigateToFullSecurity,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Dashboard Header
  Widget _buildHeader() {
    return CyberCard(
      padding: const EdgeInsets.all(18),
      borderColor: CyberColors.cyan.withAlpha(90),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CyberColors.cyan.withAlpha(25),
              border: Border.all(color: CyberColors.cyan.withAlpha(120), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: CyberColors.cyan.withAlpha(40),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.security, color: CyberColors.cyan, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'URL Security',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CyberColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6),
                SecurityStatusBadge(
                  label: 'Protection ON',
                  isProtected: true,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CyberColors.cyan),
            tooltip: 'Refresh Stats',
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  // 2. Statistics Grid
  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        ScanStatCard(
          label: 'TOTAL SCANS',
          value: _total,
          icon: Icons.bar_chart_rounded,
          color: CyberColors.cyan,
        ),
        ScanStatCard(
          label: 'SAFE',
          value: _safeCount,
          icon: Icons.check_circle_rounded,
          color: CyberColors.safe,
        ),
        ScanStatCard(
          label: 'SUSPICIOUS',
          value: _suspiciousCount,
          icon: Icons.warning_rounded,
          color: CyberColors.suspicious,
        ),
        ScanStatCard(
          label: 'MALICIOUS',
          value: _maliciousCount,
          icon: Icons.dangerous_rounded,
          color: CyberColors.malicious,
        ),
      ],
    );
  }

  // 3. Risk Distribution Donut Chart
  Widget _buildDistributionCard() {
    if (_total == 0) {
      return CyberCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              color: CyberColors.textMuted.withAlpha(120),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No Scan History Available',
              style: TextStyle(
                color: CyberColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Scan URLs to visualize safe, suspicious, and malicious distribution.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CyberColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return CyberCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Donut visualization
          SizedBox(
            width: 125,
            height: 125,
            child: CustomPaint(
              painter: _DonutChartPainter(
                safe: _safeCount,
                suspicious: _suspiciousCount,
                malicious: _maliciousCount,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_total',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: CyberColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'SCANS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: CyberColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Safe', _safeCount, _total, CyberColors.safe),
                const SizedBox(height: 10),
                _buildLegendItem('Suspicious', _suspiciousCount, _total, CyberColors.suspicious),
                const SizedBox(height: 10),
                _buildLegendItem('Malicious', _maliciousCount, _total, CyberColors.malicious),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withAlpha(120), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: CyberColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$count ($pct%)',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 4. Risk Score Trend
  Widget _buildTrendCard() {
    final scans = _chronologicalScans;

    if (scans.length < 2) {
      return CyberCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CyberColors.cyan.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.show_chart_rounded, color: CyberColors.cyan, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Score Trend',
                    style: TextStyle(
                      color: CyberColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Scan more URLs to build your risk trend.',
                    style: TextStyle(color: CyberColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return CyberCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historical Progression',
                style: TextStyle(
                  color: CyberColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${scans.length} data points',
                style: const TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _TrendChartPainter(scans: scans),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d').format(scans.first.timestamp),
                style: const TextStyle(color: CyberColors.textMuted, fontSize: 10),
              ),
              Text(
                DateFormat('MMM d').format(scans.last.timestamp),
                style: const TextStyle(color: CyberColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Highest Risk Detected Card
  Widget _buildHighestRiskCard() {
    final highest = _highestRisk;

    if (highest == null) {
      return CyberCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CyberColors.safe.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_outlined, color: CyberColors.safe, size: 24),
            ),
            const SizedBox(width: 14),
            const Text(
              'No scans available yet',
              style: TextStyle(
                color: CyberColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    Color color;
    String riskTitle;
    switch (highest.riskLevel) {
      case RiskLevel.safe:
        color = CyberColors.safe;
        riskTitle = 'LOW RISK / SAFE';
        break;
      case RiskLevel.suspicious:
        color = CyberColors.suspicious;
        riskTitle = 'SUSPICIOUS RISK';
        break;
      case RiskLevel.malicious:
        color = CyberColors.malicious;
        riskTitle = 'HIGH RISK';
        break;
    }

    String threatLabel;
    switch (highest.threatType) {
      case ThreatType.none:
        threatLabel = 'Clean / No threat detected';
        break;
      case ThreatType.phishing:
        threatLabel = 'Phishing-related threat';
        break;
      case ThreatType.malware:
        threatLabel = 'Malware-related threat';
        break;
      case ThreatType.suspiciousDomain:
        threatLabel = 'Suspicious domain threat';
        break;
      case ThreatType.brandImpersonation:
        threatLabel = 'Brand impersonation threat';
        break;
    }

    return CyberCard(
      borderColor: color.withAlpha(120),
      onTap: () => _viewHighestRiskDetail(highest),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withAlpha(180), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    riskTitle,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(
                  '${highest.riskScore} / 100',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: CyberColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.link, size: 16, color: CyberColors.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  highest.url,
                  style: const TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 15, color: color),
              const SizedBox(width: 8),
              Text(
                threatLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: CyberColors.textMuted),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d, yyyy  hh:mm a').format(highest.timestamp),
                style: const TextStyle(color: CyberColors.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Security Insight
  Widget _buildInsightCard() {
    return CyberCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CyberColors.cyan.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_rounded, color: CyberColors.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CYBER ADVISORY',
                  style: TextStyle(
                    color: CyberColors.cyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _insightMessage,
                  style: const TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Donut Chart Painter
// ─────────────────────────────────────────────────────────────────────────────
class _DonutChartPainter extends CustomPainter {
  final int safe;
  final int suspicious;
  final int malicious;

  const _DonutChartPainter({
    required this.safe,
    required this.suspicious,
    required this.malicious,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = (safe + suspicious + malicious).toDouble();
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 4;
    final strokeWidth = outerRadius * 0.32;
    final drawRadius = outerRadius - strokeWidth / 2;

    final segments = [
      (count: safe, color: CyberColors.safe),
      (count: suspicious, color: CyberColors.suspicious),
      (count: malicious, color: CyberColors.malicious),
    ];

    double startAngle = -math.pi / 2;
    const gapAngle = 0.04;

    for (final seg in segments) {
      if (seg.count == 0) continue;
      final sweepAngle = (seg.count / total) * 2 * math.pi;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final adjustedSweep = (sweepAngle - gapAngle).clamp(0.01, 2 * math.pi);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: drawRadius),
        startAngle + gapAngle / 2,
        adjustedSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter old) =>
      old.safe != safe ||
      old.suspicious != suspicious ||
      old.malicious != malicious;
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Trend Line Chart Painter
// ─────────────────────────────────────────────────────────────────────────────
class _TrendChartPainter extends CustomPainter {
  final List<ScanResult> scans;

  const _TrendChartPainter({required this.scans});

  @override
  void paint(Canvas canvas, Size size) {
    if (scans.length < 2) return;

    const leftPad = 26.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - topPad - bottomPad;

    // Grid lines for 0, 50, 100
    final gridPaint = Paint()
      ..color = CyberColors.borderSubtle
      ..strokeWidth = 1.0;

    const textStyle = TextStyle(
      color: CyberColors.textMuted,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    for (final level in [0, 50, 100]) {
      final y = topPad + chartH * (1.0 - level / 100.0);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width, y),
        gridPaint,
      );

      final span = TextSpan(text: '$level', style: textStyle);
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Points
    final count = scans.length;
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = leftPad + (i / (count - 1)) * chartW;
      final y = topPad + chartH * (1.0 - (scans[i].riskScore / 100.0));
      points.add(Offset(x, y));
    }

    // Area fill under line
    final areaPath = Path()..moveTo(points.first.dx, topPad + chartH);
    for (final pt in points) {
      areaPath.lineTo(pt.dx, pt.dy);
    }
    areaPath.lineTo(points.last.dx, topPad + chartH);
    areaPath.close();

    final fillShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        CyberColors.cyan.withAlpha(60),
        CyberColors.cyan.withAlpha(0),
      ],
    ).createShader(Rect.fromLTWH(0, topPad, size.width, chartH));

    final areaPaint = Paint()..shader = fillShader;
    canvas.drawPath(areaPath, areaPaint);

    // Stroke line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = CyberColors.cyan
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotOuterPaint = Paint()
      ..color = CyberColors.bgDark
      ..style = PaintingStyle.fill;

    final dotInnerPaint = Paint()
      ..color = CyberColors.cyan
      ..style = PaintingStyle.fill;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.5, dotOuterPaint);
      canvas.drawCircle(pt, 3.0, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter old) => old.scans != scans;
}
