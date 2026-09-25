import 'package:flutter/material.dart';
import '../services/risk_engine.dart';
import '../services/history_service.dart';
import '../services/scan_alert_service.dart';
import '../models/scan_result.dart';
import 'widgets/result_card.dart';
import '../core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/view_intent_handler.dart';

class AutoProtectionScreen extends StatefulWidget {
  final String? url;
  const AutoProtectionScreen({Key? key, this.url}) : super(key: key);

  @override
  State<AutoProtectionScreen> createState() => _AutoProtectionScreenState();
}

class _AutoProtectionScreenState extends State<AutoProtectionScreen> {
  ScanResult? _result;
  bool _isLoading = false;
  bool _childSafeMode = false;
  bool _protectionEnabled = true;
  bool _alertSilenced = false;
  // The 🟢 Link Verified Safe confirmation is shown exactly once per safe
  // result (rebuilds must never re-open the dialog).
  bool _safeDialogShown = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Loads the saved settings first, then analyzes the shared URL (if any)
  /// so alert gating always uses the persisted values.
  Future<void> _init() async {
    await _loadSettings();
    if (widget.url != null) {
      _analyze(widget.url!);
    }
  }

  /// Reads the three persisted settings from SharedPreferences.
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _childSafeMode = prefs.getBool('child_safe_mode') ?? false;
        _protectionEnabled = prefs.getBool('protection_mode_enabled') ?? true;
      });
    } catch (_) {
      // Keep defaults if preferences are unavailable.
    }
  }

  Future<void> _analyze(String url) async {
    setState(() {
      _isLoading = true;
      _alertSilenced = false;
    });
    try {
      final engine = RiskEngine();
      final result = await engine.analyzeUrl(url, ScanSource.autoProtection);
      await HistoryService.instance.saveScan(result);

      if (mounted) {
        // Show the result immediately; alerts run in parallel afterwards.
        setState(() {
          _result = result;
          _isLoading = false;
        });
        // Safe result: a lightweight 🟢 confirmation popup (no siren, no
        // vibration, no danger notification — handleResult already stopped
        // and cancelled all of them for safe results).
        if (result.riskLevel == RiskLevel.safe) {
          _showSafeConfirmation();
        }
      }

      // Protection Mode decides whether anything alerts at all. The shared
      // service then starts the siren + vibration for risky results — the
      // siren NEVER depends on security_notifications — and shows the
      // persistent system notification only when that setting allows it.
      // Safe results and Protection Mode off stop all sounds and clear any
      // previously posted danger notification.
      if (!_protectionEnabled) {
        await ScanAlertService.instance.stopSounds();
        await ScanAlertService.instance.cancelDangerNotification();
      } else {
        await ScanAlertService.instance.handleResult(result);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Stops the audible warning + danger notification when the user
  /// acknowledges the result.
  Future<void> _silenceAlert() async {
    await ScanAlertService.instance.acknowledge();
    if (!mounted) return;
    setState(() => _alertSilenced = true);
  }

  @override
  void dispose() {
    // Never leave the siren/vibration running after leaving the screen.
    ScanAlertService.instance.stopSounds();
    super.dispose();
  }

  /// Stops siren, vibration and the danger notification, then hands the URL
  /// to the user's normal external browser via an explicit launch.
  /// CyberGuard never positions itself as the browser and never auto-opens
  /// risky links.
  Future<void> _openInExternalBrowser() async {
    await ScanAlertService.instance.acknowledge();
    if (_result == null) return;
    final uri = Uri.tryParse(_result!.url);
    if (uri == null) return;
    // Recursion guard BEFORE launching: record that this exact URL is being
    // opened by CyberGuard itself so the VIEW-intent echo of our own launch
    // can never re-enter interception (CyberGuard → browser → CyberGuard…).
    ViewIntentHandler.markSelfLaunched(_result!.url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) ViewIntentHandler.clearSelfLaunched();
    } catch (_) {
      ViewIntentHandler.clearSelfLaunched();
      // No external browser available to handle the link.
    }
  }

  /// Lightweight, professional 🟢 confirmation for SAFE results. Deliberately
  /// NOT the danger alert: no siren, no vibration, no persistent danger
  /// notification — the existing ScanAlertService already ensured all three
  /// are silent/cancelled for safe results. Continue opens the ORIGINAL URL
  /// (exact string Android delivered) in the user's normal browser; Go Back
  /// simply dismisses the popup and leaves the user in CyberGuard, never
  /// trapped.
  void _showSafeConfirmation() {
    if (_safeDialogShown || _result == null) return;
    _safeDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _result == null) return;
      String host = _result!.url;
      try {
        final parsed = Uri.tryParse(_result!.url)?.host;
        if (parsed != null && parsed.isNotEmpty) host = parsed;
      } catch (_) {
        // Fall back to the full original URL.
      }
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.verified_rounded, color: CyberColors.safe),
              SizedBox(width: 8),
              Expanded(child: Text('🟢 Link Verified Safe')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CyberGuard checked this link and found no known security threats.',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CyberColors.bgDark.withAlpha(180),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CyberColors.borderSubtle),
                ),
                child: Text(
                  host,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: CyberColors.safe,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openInExternalBrowser();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    });
  }

  /// Stops siren, vibration and the danger notification, then leaves the
  /// warning screen.
  Future<void> _goBack() async {
    await ScanAlertService.instance.acknowledge();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Protection Scan'),
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
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : _result != null
                    ? _buildResultContent()
                    : const Text('No URL provided.'),
          ),
        ),
      ),
    );
  }

  Widget _buildResultContent() {
    final bool isRisky = _result!.riskLevel == RiskLevel.suspicious ||
        _result!.riskLevel == RiskLevel.malicious;

    List<Widget> actions = [];

    // Prominent silence control for the looping siren.
    if (isRisky && !_alertSilenced) {
      actions.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size(220, 48),
        ),
        onPressed: _silenceAlert,
        icon: const Icon(Icons.volume_off_rounded),
        label: const Text(
          'SILENCE ALERT',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ));
      actions.add(const SizedBox(height: 8));
    }

    if (_result!.riskLevel == RiskLevel.safe) {
      actions.add(ElevatedButton(
        onPressed: _openInExternalBrowser,
        child: const Text('Continue to Browser'),
      ));
    } else if (isRisky && _childSafeMode) {
      // Child Safe Mode: suspicious AND malicious links are blocked outright.
      // The URL is never handed to a browser from this screen.
      actions.add(Container(
        width: double.infinity,
        color: Colors.redAccent,
        padding: const EdgeInsets.all(8),
        child: const Text(
          'Blocked by Child Safe Mode — this link cannot be opened',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ));
      actions.add(const SizedBox(height: 8));
      actions.add(ElevatedButton(
        onPressed: _goBack,
        child: const Text('GO BACK'),
      ));
    } else {
      // Normal mode: explicit user decision required — the dangerous URL is
      // only opened after the user presses OPEN ANYWAY.
      actions.add(ElevatedButton(
        onPressed: _goBack,
        child: const Text('GO BACK'),
      ));
      actions.add(const SizedBox(height: 8));
      actions.add(ElevatedButton(
        onPressed: _openInExternalBrowser,
        child: const Text('OPEN ANYWAY'),
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRisky && !_alertSilenced) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DANGEROUS URL DETECTED — do not open this link.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ResultCard(scanResult: _result!),
        const SizedBox(height: 16),
        ...actions,
      ],
    );
  }
}
