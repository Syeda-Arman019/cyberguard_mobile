import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/history_service.dart';
import 'widgets/cyber_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineEngine = true;
  bool _deepHeuristics = true;
  bool _warnTyposquatting = true;
  bool _isClearing = false;

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear All Scan History?'),
        content: const Text(
          'This will permanently delete all stored URL scan records from the local database.',
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
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isClearing = true);
      await HistoryService.instance.deleteAllScans();
      if (!mounted) return;
      setState(() => _isClearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan history cleared successfully'),
          backgroundColor: CyberColors.cardBgElevated,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Security Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: CyberColors.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const SectionHeader(title: 'Detection Engine'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.shield_outlined,
                      title: 'Local Heuristic Engine',
                      subtitle: 'Analyze domains and URLs on-device using heuristic algorithms.',
                      value: _offlineEngine,
                      onChanged: (v) => setState(() => _offlineEngine = v),
                    ),
                    const Divider(color: CyberColors.border, height: 24),
                    _buildSwitchTile(
                      icon: Icons.travel_explore,
                      title: 'Deep Threat Analysis',
                      subtitle: 'Inspect URL path, subdomains, and suspicious TLD patterns.',
                      value: _deepHeuristics,
                      onChanged: (v) => setState(() => _deepHeuristics = v),
                    ),
                    const Divider(color: CyberColors.border, height: 24),
                    _buildSwitchTile(
                      icon: Icons.spellcheck,
                      title: 'Brand Impersonation Detection',
                      subtitle: 'Detect typosquatting and fake brand domain imitations.',
                      value: _warnTyposquatting,
                      onChanged: (v) => setState(() => _warnTyposquatting = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Data & Storage'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CyberColors.cyan.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storage_rounded, color: CyberColors.cyan, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local Hive Database',
                                style: TextStyle(
                                  color: CyberColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Encrypted local storage for audit logs and scan analytics.',
                                style: TextStyle(color: CyberColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SecondaryCyberButton(
                      label: _isClearing ? 'Clearing...' : 'Clear All Scan History',
                      icon: Icons.delete_outline_rounded,
                      color: CyberColors.malicious,
                      onPressed: _isClearing ? null : _clearHistory,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'System Information'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Application', 'CyberGuard Mobile'),
                    const Divider(color: CyberColors.borderSubtle, height: 18),
                    _buildInfoRow('Module', 'URL Security & Heuristics'),
                    const Divider(color: CyberColors.borderSubtle, height: 18),
                    _buildInfoRow('Version', '1.0.0+1 (Production Build)'),
                    const Divider(color: CyberColors.borderSubtle, height: 18),
                    _buildInfoRow('Engine Status', 'Active & Operational'),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: CyberColors.cyan.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: CyberColors.cyan, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: CyberColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: CyberColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: CyberColors.cyan.withAlpha(77),
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return CyberColors.cyan;
            }
            return CyberColors.textMuted;
          }),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: CyberColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: CyberColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
