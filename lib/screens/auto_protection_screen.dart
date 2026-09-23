import 'dart:async';

import 'package:flutter/material.dart';
import '../services/risk_engine.dart';
import '../services/history_service.dart';
import '../services/siren_service.dart';
import '../models/scan_result.dart';
import 'widgets/result_card.dart';
import '../core/theme.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _securityNotifications = true;
  bool _alertSilenced = false;

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
        _securityNotifications = prefs.getBool('security_notifications') ?? true;
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

      final bool isRisky = result.riskLevel == RiskLevel.suspicious ||
          result.riskLevel == RiskLevel.malicious;

      // Alert only when Protection Mode is on and the user allows
      // security notifications for risky URLs.
      if (_protectionEnabled && _securityNotifications && isRisky) {
        // Loud, looping siren until the user acknowledges the warning.
        unawaited(SirenService.instance.start());
        final canVibrate = await Vibration.hasVibrator();
        if (canVibrate) {
          await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
        }
      } else {
        // Make sure no previous siren keeps sounding on safe results.
        await SirenService.instance.stop();
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Stops the audible warning when the user acknowledges it.
  Future<void> _silenceAlert() async {
    await SirenService.instance.stop();
    if (!mounted) return;
    setState(() => _alertSilenced = true);
  }

  @override
  void dispose() {
    // Never leave the siren ringing after leaving the screen.
    SirenService.instance.stop();
    super.dispose();
  }

  Future<void> _openUrl() async {
    if (_result == null) return;
    final uri = Uri.tryParse(_result!.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
        onPressed: _openUrl,
        child: const Text('Continue to Browser'),
      ));
    } else if (_result!.riskLevel == RiskLevel.malicious && _childSafeMode) {
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
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Go Back'),
      ));
    } else {
      actions.add(ElevatedButton(
        onPressed: _openUrl,
        child: const Text('Open Anyway'),
      ));
      actions.add(const SizedBox(height: 8));
      actions.add(ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Go Back'),
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
