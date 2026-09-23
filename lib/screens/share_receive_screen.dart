import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:vibration/vibration.dart';
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../services/risk_engine.dart';
import '../services/siren_service.dart';
import 'widgets/result_card.dart';
import 'widgets/cyber_components.dart';
import '../services/history_service.dart';

/// Screen displayed when the app is opened via Android/iOS Share menu.
///
/// Receives shared plain text (e.g. from WhatsApp, browser, or any app),
/// extracts the first URL found, and runs it through [RiskEngine] to
/// produce a security analysis displayed via [ResultCard].
class ShareReceiveScreen extends StatefulWidget {
  /// The raw shared text payload delivered by the OS intent / share extension.
  final String sharedText;

  /// Optional injectable [RiskEngine] for testing.
  final RiskEngine? riskEngine;

  const ShareReceiveScreen({
    super.key,
    required this.sharedText,
    this.riskEngine,
  });

  @override
  State<ShareReceiveScreen> createState() => _ShareReceiveScreenState();
}

class _ShareReceiveScreenState extends State<ShareReceiveScreen> {
  late final RiskEngine _engine;

  bool _isAnalyzing = true;
  ScanResult? _result;
  String? _extractedUrl;
  String? _errorMessage;
  bool _alertSilenced = false;

  static final _urlRegex = RegExp(
    r'https?://[^\s\]"<>]+',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _engine = widget.riskEngine ?? RiskEngine();
    _processSharedText(widget.sharedText);
  }

  Future<void> _processSharedText(String text) async {
    final match = _urlRegex.firstMatch(text.trim());

    if (match == null) {
      // No URL found — make sure no siren keeps ringing.
      await SirenService.instance.stop();
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage =
              'No web URL was identified in the shared payload.\n\nMake sure to share a web link from your browser, social app, or paste a valid link.';
        });
      }
      return;
    }

    final url = match.group(0)!;

    if (mounted) {
      setState(() {
        _extractedUrl = url;
      });
    }

    final result = await _engine.analyzeUrl(url, ScanSource.share);
    await HistoryService.instance.saveScan(result);
    await _handleResultAlert(result);

    if (mounted) {
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    }
  }

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

  @override
  void dispose() {
    // Never leave the siren ringing after leaving the screen.
    SirenService.instance.stop();
    super.dispose();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to CyberGuard'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: CyberColors.cyan),
          tooltip: 'Dismiss',
          onPressed: _dismiss,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 1. Analyzing state
    if (_isAnalyzing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36.0),
          child: CyberCard(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(CyberColors.cyan),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Analyzing Shared Link...',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_extractedUrl != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: CyberColors.bgDark.withAlpha(150),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CyberColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Shared URL',
                          style: TextStyle(color: CyberColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _extractedUrl!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: CyberColors.cyan,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // 2. Error state (no URL detected)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: CyberCard(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded, size: 52, color: CyberColors.suspicious),
                const SizedBox(height: 16),
                const Text(
                  'No URL Detected',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: CyberColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: CyberColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SecondaryCyberButton(
                  onPressed: _dismiss,
                  icon: Icons.close_rounded,
                  label: 'Dismiss',
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Result card
    if (_result != null) {
      final bool isRisky = _result!.riskLevel == RiskLevel.suspicious ||
          _result!.riskLevel == RiskLevel.malicious;
      return Column(
        children: [
          // Silence control for the looping siren on risky results.
          if (isRisky && !_alertSilenced) ...[
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
            const SizedBox(height: 12),
          ],
          ResultCard(
            scanResult: _result!,
            onAction: _dismiss,
            actionLabel: 'Done',
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// ShareIntentHandler
// ---------------------------------------------------------------------------
class ShareIntentHandler {
  ShareIntentHandler._();

  static void listen(GlobalKey<NavigatorState> navigatorKey) {
    ReceiveSharingIntent.instance.getInitialMedia().then((sharedFiles) {
      final text = _extractText(sharedFiles);
      if (text != null && text.isNotEmpty) {
        _navigate(navigatorKey, text);
      }
    });

    ReceiveSharingIntent.instance.getMediaStream().listen((sharedFiles) {
      final text = _extractText(sharedFiles);
      if (text != null && text.isNotEmpty) {
        _navigate(navigatorKey, text);
      }
    });
  }

  static String? _extractText(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text && f.path.isNotEmpty) {
        return f.path;
      }
    }
    return null;
  }

  static void _navigate(GlobalKey<NavigatorState> key, String text) {
    key.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ShareReceiveScreen(sharedText: text),
        fullscreenDialog: true,
      ),
    );
  }
}
