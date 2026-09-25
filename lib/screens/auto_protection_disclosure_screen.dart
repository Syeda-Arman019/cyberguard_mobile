import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Play-Store-required prominent disclosure before the user opens the
/// Notification access settings screen. Plain language: what is read, what
/// is done with it, what is NOT done. Only "I Agree" continues.
class AutoProtectionDisclosureScreen extends StatelessWidget {
  final VoidCallback onAgreed;

  const AutoProtectionDisclosureScreen({super.key, required this.onAgreed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto Protection — Disclosure')),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined,
                    color: CyberColors.cyan, size: 44),
                const SizedBox(height: 16),
                const Text(
                  'Before you enable Notification Scan',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _bullet('📱', 'What is read',
                    'CyberGuard reads the text of notifications from the messaging and email apps you select (for example WhatsApp, SMS, Gmail).'),
                _bullet('🔍', 'What is done with it',
                    'Only web links (URLs) found in that text are extracted and automatically checked for threats using the existing CyberGuard analysis.'),
                _bullet('🔒', 'What is NOT done',
                    'Message content is never stored, never uploaded, and never shared. Only the extracted link is analyzed. Nothing leaves your device except the link check itself.'),
                _bullet('🚫', 'What is NOT used',
                    'No SMS reading permission. No accessibility services. No VPN. CyberGuard never becomes your default browser.'),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {}, // TODO: link to privacy policy when published
                  child: const Text(
                    'Read our Privacy Policy →',
                    style: TextStyle(
                      color: CyberColors.cyan,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          onAgreed();
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('I Agree'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bullet(String emoji, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: CyberColors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        color: CyberColors.textSecondary,
                        fontSize: 13,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
