// lib/screens/manual_scan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../services/risk_engine.dart';
import '../services/history_service.dart';
import '../services/scan_alert_service.dart';
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
    // Never leave the siren/vibration running after leaving the screen.
    ScanAlertService.instance.stopSounds();
    _urlController.dispose();
    super.dispose();
  }

  bool get _isRiskyResult =>
      _scanResult != null &&
      (_scanResult!.riskLevel == RiskLevel.suspicious ||
          _scanResult!.riskLevel == RiskLevel.malicious);

  /// Stops the audible warning + danger notification when the user
  /// acknowledges the result.
  Future<void> _silenceAlert() async {
    await ScanAlertService.instance.acknowledge();
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
    await ScanAlertService.instance.stopSounds();

    try {
      final result = await _engine.analyzeUrl(rawUrl, ScanSource.manual);
      if (!mounted) return;
      // Show the result immediately; alerts run in parallel afterwards.
      setState(() {
        _scanResult = result;
        _isLoading = false;
      });
      // Shared alert flow: siren + vibration + persistent notification for
      // risky results; all stopped/cancelled for safe results.
      await ScanAlertService.instance.handleResult(result);
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
                      ScanAlertService.instance.acknowledge();
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
