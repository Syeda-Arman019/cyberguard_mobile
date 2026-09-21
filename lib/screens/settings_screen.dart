import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../services/history_service.dart';
import 'widgets/cyber_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  // 1. Protection & Notification Toggles (UI placeholders for now)
  bool _protectionMode = true;
  bool _securityNotifications = true;

  // 2. Permission Statuses
  PermissionStatus? _cameraStatus;
  PermissionStatus? _smsStatus;
  bool _isLoadingPermissions = true;

  // 3. Scan Statistics
  int _totalScans = 0;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permission states when user returns to the app from OS settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _loadStats();
    }
  }

  void _loadStats() {
    final scans = HistoryService.instance.getAllScans();
    if (mounted) {
      setState(() => _totalScans = scans.length);
    }
  }

  /// Checks current permission statuses without prompting the user.
  Future<void> _checkPermissions() async {
    try {
      final camera = await Permission.camera.status;
      PermissionStatus sms;
      try {
        sms = await Permission.sms.status;
      } catch (_) {
        sms = PermissionStatus.denied;
      }

      if (mounted) {
        setState(() {
          _cameraStatus = camera;
          _smsStatus = sms;
          _isLoadingPermissions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPermissions = false);
      }
    }
  }

  /// Explicitly requests camera permission when tapped by the user.
  Future<void> _requestCameraPermission() async {
    if (_cameraStatus == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
    } else {
      final result = await Permission.camera.request();
      if (mounted) {
        setState(() => _cameraStatus = result);
      }
    }
  }

  /// Explicitly requests SMS permission if supported.
  Future<void> _requestSmsPermission() async {
    if (_smsStatus == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
    } else {
      try {
        final result = await Permission.sms.request();
        if (mounted) {
          setState(() => _smsStatus = result);
        }
      } catch (_) {
        // Handled gracefully if not supported on current device
      }
    }
  }

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
      setState(() {
        _isClearing = false;
        _totalScans = 0;
      });
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
        leading: Navigator.of(context).canPop()
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
              // 1. Settings Header
              _buildHeader(),
              const SizedBox(height: 22),

              // 2. Security Section (Protection Mode & Notifications)
              const SectionHeader(title: 'Security Preferences'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.shield_outlined,
                      title: '🛡 Protection Mode',
                      subtitle: 'Enable URL protection features.',
                      value: _protectionMode,
                      onChanged: (v) {
                        setState(() => _protectionMode = v);
                      },
                    ),
                    const Divider(color: CyberColors.border, height: 24),
                    _buildSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: '🔔 Security Notifications',
                      subtitle: 'Receive alerts when a risky URL is detected.',
                      value: _securityNotifications,
                      onChanged: (v) {
                        setState(() => _securityNotifications = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 3. Device Permissions Section
              const SectionHeader(title: 'Device Permissions'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPermissionTile(
                      icon: Icons.camera_alt_outlined,
                      title: '📷 Camera Permission',
                      subtitle: 'Required for QR code scanning and physical URL extraction.',
                      status: _cameraStatus,
                      onRequest: _requestCameraPermission,
                    ),
                    const Divider(color: CyberColors.border, height: 24),
                    _buildPermissionTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '💬 SMS Permission',
                      subtitle: 'Optional permission for inspecting suspicious links in messages.',
                      status: _smsStatus,
                      onRequest: _requestSmsPermission,
                      isOptional: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 4. Security Activity Section
              const SectionHeader(title: 'Security Activity'),
              const SizedBox(height: 10),
              _buildActivityCard(),
              const SizedBox(height: 22),

              // 5. Data & Storage
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
                                'Local Encrypted Storage',
                                style: TextStyle(
                                  color: CyberColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'On-device database storing previous scan audit logs.',
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
              const SizedBox(height: 22),

              // 6. System Information
              const SectionHeader(title: 'System Information'),
              const SizedBox(height: 10),
              CyberCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Application', 'CyberGuard Mobile'),
                    const Divider(color: CyberColors.borderSubtle, height: 18),
                    _buildInfoRow('Module', 'URL Security & Analytics'),
                    const Divider(color: CyberColors.borderSubtle, height: 18),
                    _buildInfoRow('Version', '1.0.0+1 (Production Build)'),
                    const Divider(color: CyberColors.borderSubtle, height: 18),
                    _buildInfoRow('Engine Status', 'Operational (Local Heuristics)'),
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

  // Header Widget
  Widget _buildHeader() {
    return CyberCard(
      padding: const EdgeInsets.all(18),
      borderColor: CyberColors.cyan.withAlpha(80),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CyberColors.cyan.withAlpha(25),
              border: Border.all(color: CyberColors.cyan.withAlpha(120), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: CyberColors.cyan.withAlpha(35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.tune_rounded, color: CyberColors.cyan, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'URL Security Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CyberColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage your URL security preferences and permissions.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CyberColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Switch Tile
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
                  fontWeight: FontWeight.bold,
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

  // Permission Tile
  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required PermissionStatus? status,
    required VoidCallback onRequest,
    bool isOptional = false,
  }) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (_isLoadingPermissions || status == null) {
      badgeColor = CyberColors.textMuted;
      badgeText = 'Checking...';
      badgeIcon = Icons.hourglass_empty_rounded;
    } else if (status.isGranted) {
      badgeColor = CyberColors.safe;
      badgeText = 'Granted';
      badgeIcon = Icons.check_circle_rounded;
    } else if (status.isPermanentlyDenied) {
      badgeColor = CyberColors.malicious;
      badgeText = 'Permanently Denied';
      badgeIcon = Icons.cancel_rounded;
    } else if (isOptional && (status.isDenied || status.isRestricted)) {
      badgeColor = CyberColors.textSecondary;
      badgeText = 'Not Required';
      badgeIcon = Icons.info_outline_rounded;
    } else {
      badgeColor = CyberColors.suspicious;
      badgeText = 'Denied';
      badgeIcon = Icons.warning_amber_rounded;
    }

    final isGranted = status?.isGranted ?? false;

    return Column(
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
                      fontWeight: FontWeight.bold,
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
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeColor.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 14, color: badgeColor),
                  const SizedBox(width: 6),
                  Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Action button if not granted
            if (!isGranted)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: CyberColors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: onRequest,
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: Text(
                  status == PermissionStatus.permanentlyDenied
                      ? 'Open Settings'
                      : 'Grant Permission',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Security Activity Card (Total URLs Scanned)
  Widget _buildActivityCard() {
    return CyberCard(
      padding: const EdgeInsets.all(18),
      borderColor: CyberColors.cyan.withAlpha(60),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: CyberColors.cyan.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CyberColors.cyan.withAlpha(80), width: 1.2),
            ),
            child: const Icon(Icons.link_rounded, color: CyberColors.cyan, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total URLs Scanned',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Real-time count of URLs inspected across all scan modes.',
                  style: TextStyle(color: CyberColors.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: CyberColors.bgDark.withAlpha(180),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CyberColors.cyan.withAlpha(70)),
            ),
            child: Text(
              '$_totalScans',
              style: const TextStyle(
                color: CyberColors.cyan,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Info Row
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
