// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'manual_scan_screen.dart';
import 'qr_scan_screen.dart';
import 'share_receive_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'widgets/cyber_components.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: CyberCard(
        padding: const EdgeInsets.all(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => destination),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CyberColors.cyan.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CyberColors.cyan.withAlpha(80), width: 1.2),
              ),
              child: Icon(icon, color: CyberColors.cyan, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CyberColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: CyberColors.cyan,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Security Suite'),
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: CyberColors.cyan),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Header Card
              CyberCard(
                padding: const EdgeInsets.all(18),
                borderColor: CyberColors.cyan.withAlpha(80),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CyberColors.cyan.withAlpha(30),
                        border: Border.all(color: CyberColors.cyan.withAlpha(120), width: 1.5),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: CyberColors.cyan, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CyberGuard Security',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: CyberColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Select an analysis tool to detect phishing, malware, and rogue links.',
                            style: TextStyle(fontSize: 12, color: CyberColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Security Features'),
              const SizedBox(height: 12),

              _buildFeatureCard(
                context: context,
                icon: Icons.link_rounded,
                title: 'Manual URL Scan',
                subtitle: 'Analyze any web link or domain for security threats',
                destination: const ManualScanScreen(),
              ),

              _buildFeatureCard(
                context: context,
                icon: Icons.qr_code_scanner_rounded,
                title: 'QR Code Scanner',
                subtitle: 'Scan physical QR codes and extract URLs safely',
                destination: const QrScanScreen(),
              ),

              _buildFeatureCard(
                context: context,
                icon: Icons.share_rounded,
                title: 'Share to CyberGuard',
                subtitle: 'Inspect URLs shared directly from external apps',
                destination: const ShareReceiveScreen(sharedText: ''),
              ),

              _buildFeatureCard(
                context: context,
                icon: Icons.history_rounded,
                title: 'Scan History',
                subtitle: 'Review historical scan audit logs and risk trends',
                destination: const HistoryScreen(),
              ),

              _buildFeatureCard(
                context: context,
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'Configure detection rules and security preferences',
                destination: const SettingsScreen(),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
