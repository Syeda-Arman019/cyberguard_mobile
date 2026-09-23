// lib/screens/manual_scan_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../services/risk_engine.dart';
import '../services/history_service.dart';
import '../services/siren_service.dart';
import 'widgets/result_card.dart';

class ManualScanScreen extends StatefulWidget {
  final RiskEngine? riskEngine;
  const ManualScanScreen({super.key, this.riskEngine});

  @override
  State<ManualScanScreen> createState() => _ManualScanScreenState();
}

class _ManualScanScreenState extends State<ManualScanScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  ScanResult? _scanResult;
  String? _inputError;
  bool _alertSilenced = false;
  late final RiskEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = widget.riskEngine ?? RiskEngine();
  }

  @override
  void dispose() {
    // Never leave the siren ringing after leaving the screen.
    SirenService.instance.stop();
    _urlController.dispose();
    super.dispose();
  }

  bool get _isRiskyResult =>
      _scanResult != null &&
      (_scanResult!.riskLevel == RiskLevel.suspicious ||
          _scanResult!.riskLevel == RiskLevel.malicious);

  /// Starts the looping siren + vibration for risky results, or stops any
  /// active siren for safe results. Uses the shared SirenService.
  Future<void> _handleResultAlert(ScanResult result) async {
    final bool isRisky = result.riskLevel == RiskLevel.suspicious ||
        result.riskLevel == RiskLevel.malicious;
    if (!isRisky) {
      await SirenService.instance.stop();
      return;
    }
    // start() is guarded, so repeated calls never duplicate playback.
    unawaited(SirenService.instance.start());
    try {
      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
      }
    } catch (_) {
      // Vibration not supported on this device.
    }
  }

  /// Stops the audible warning when the user acknowledges it.
  Future<void> _silenceAlert() async {
    await SirenService.instance.stop();
    if (!mounted) return;
    setState(() => _alertSilenced = true);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      setState(() => _inputError = null);
    }
  }

  Future<void> _analyzeUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _inputError = 'Please enter a URL to scan.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _inputError = null;
      _alertSilenced = false; // New scan resets the alert state.
    });
    // A new analysis must not have a previous siren ringing over it.
    await SirenService.instance.stop();

    try {
      final result = await _engine.analyzeUrl(rawUrl, ScanSource.manual);
      await _handleResultAlert(result);
      if (!mounted) return;
      setState(() {
        _scanResult = result;
        _isLoading = false;
      });
      // Save to history
      await HistoryService.instance.saveScan(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _inputError = 'Failed to analyze URL: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual URL Scanner'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input Container (Container styled, keeping find.byType(Card) matching tests)
                Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: CyberColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CyberColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(77),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CyberColors.cyan.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.link_rounded, color: CyberColors.cyan, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target URL Input',
                                style: TextStyle(
                                  color: CyberColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Enter HTTP or HTTPS address to inspect',
                                style: TextStyle(color: CyberColors.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: CyberColors.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                        ),
                        onSubmitted: (_) => _analyzeUrl(),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/login',
                          hintStyle: const TextStyle(color: CyberColors.textMuted, fontSize: 13),
                          errorText: _inputError,
                          errorStyle: const TextStyle(color: CyberColors.malicious),
                          filled: true,
                          fillColor: CyberColors.bgDark.withAlpha(150),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CyberColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CyberColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: CyberColors.cyan, width: 1.5),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_urlController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, color: CyberColors.textMuted, size: 18),
                                  onPressed: () {
                                    _urlController.clear();
                                    setState(() => _inputError = null);
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.paste_rounded, color: CyberColors.cyan, size: 18),
                                tooltip: 'Paste from clipboard',
                                onPressed: _pasteFromClipboard,
                              ),
                            ],
                          ),
                        ),
                        onChanged: (_) {
                          if (_inputError != null) setState(() => _inputError = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyberColors.cyan,
                          foregroundColor: CyberColors.bgDark,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: CyberColors.cyan.withAlpha(102),
                        ),
                        onPressed: _isLoading ? null : _analyzeUrl,
                        icon: const Icon(Icons.security),
                        label: const Text(
                          'Analyze',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Loading State
                if (_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: CyberColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CyberColors.border),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(CyberColors.cyan),
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Scanning URL for security threats...',
                          style: TextStyle(
                            color: CyberColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Running heuristic engine, domain analysis, and risk scoring...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: CyberColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Scan Result
                if (!_isLoading && _scanResult != null) ...[
                  // Silence control for the looping siren on risky results.
                  if (_isRiskyResult && !_alertSilenced) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(220, 48),
                      ),
                      onPressed: _silenceAlert,
                      icon: const Icon(Icons.volume_off_rounded),
                      label: const Text(
                        'SILENCE ALERT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ResultCard(
                    scanResult: _scanResult!,
                    actionLabel: 'Scan Another URL',
                    onAction: () {
                      SirenService.instance.stop();
                      setState(() {
                        _scanResult = null;
                        _urlController.clear();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
