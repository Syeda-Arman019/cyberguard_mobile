// lib/screens/auto_protection_info_screen.dart
//
// Dedicated Auto Protection information screen (opened from the Features
// tab's "Auto Protection" card). Purely informational + two navigation
// actions:
//   • "Auto Protection Settings" → pushes the EXISTING SettingsScreen,
//     scrolled to the existing Auto Protection section (no duplicate
//     settings are created anywhere).
//   • "Test Auto Protection" → opens the EXISTING AutoProtectionScreen
//     with the same test URL previously used by the Features tab card.
// No security logic, scanning, notification, siren or permission behavior
// is changed or duplicated here.
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'auto_protection_screen.dart';
import 'settings_screen.dart';
import 'widgets/cyber_components.dart';

class AutoProtectionInfoScreen extends StatelessWidget {
  const AutoProtectionInfoScreen({super.key});

  static const String _testUrl =
      'http://testsafebrowsing.appspot.com/s/phishing.html';

  Widget _buildStepRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CyberColors.cyan, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: CyberColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Protection'),
        automaticallyImplyLeading: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── What it does ────────────────────────────────────────────
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
                        border: Border.all(
                            color: CyberColors.cyan.withAlpha(120), width: 1.5),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: CyberColors.cyan, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Always-on link defense',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: CyberColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'CyberGuard watches for links that arrive in your notifications and analyzes every detected URL before you open it.',
                            style: TextStyle(
                                fontSize: 12, color: CyberColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── How it works ─────────────────────────────────────────────
              const SectionHeader(title: 'How it works'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepRow(Icons.notifications_rounded,
                        'Monitors incoming notifications from your selected apps.'),
                    _buildStepRow(Icons.link_rounded,
                        'Detects links inside those notifications and in links shared to CyberGuard.'),
                    _buildStepRow(Icons.search_rounded,
                        'Analyzes each URL for phishing, malware and impersonation threats.'),
                    _buildStepRow(Icons.warning_amber_rounded,
                        'Alerts you with a warning screen — risky links are never opened automatically.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Requirements ─────────────────────────────────────────────
              const SectionHeader(title: 'Requirements'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepRow(Icons.shield_outlined,
                        'Protection Mode must be enabled (Settings → Security Preferences).'),
                    _buildStepRow(Icons.settings_rounded,
                        'Auto Protection master switch must be ON.'),
                    _buildStepRow(Icons.notifications_active_rounded,
                        'Notification Access must be granted so CyberGuard can scan notifications.'),
                    _buildStepRow(Icons.battery_saver_rounded,
                        'Battery optimization should be set to "Unrestricted" so protection keeps running in the background.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Child Safe Mode ──────────────────────────────────────────
              const SectionHeader(title: 'Child Safe Mode'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepRow(Icons.child_care_outlined,
                        'When Child Safe Mode is enabled, suspicious and malicious links are blocked completely — they cannot be opened at all, even deliberately.'),
                    _buildStepRow(Icons.tune_rounded,
                        'Enable it in Settings → Security Preferences → Child Safe Mode.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Test Auto Protection ─────────────────────────────────────
              const SectionHeader(title: 'Test Auto Protection'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AutoProtectionScreen(url: _testUrl),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: CyberColors.cyan.withAlpha(25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: CyberColors.cyan.withAlpha(80),
                                width: 1.2),
                          ),
                          child: const Icon(Icons.science_rounded,
                              color: CyberColors.cyan, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Try it yourself',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: CyberColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Send a test notification/link to see how CyberGuard detects and analyzes it.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: CyberColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: CyberColors.cyan, size: 16),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AutoProtectionScreen(url: _testUrl),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text(
                          'Test Auto Protection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Auto Protection Settings ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CyberColors.cyan,
                    foregroundColor: CyberColors.bgDark,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(
                          scrollToAutoProtection: true),
                    ),
                  ),
                  icon: const Icon(Icons.settings_rounded, size: 20),
                  label: const Text(
                    'Auto Protection Settings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
