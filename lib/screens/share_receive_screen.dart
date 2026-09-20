import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../models/scan_result.dart';
import '../services/risk_engine.dart';
import 'widgets/result_card.dart';
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

  // Regex that matches http:// or https:// URLs, including those embedded in
  // surrounding text (e.g. WhatsApp message bodies).
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

  /// Extracts the first URL from [text] and triggers risk analysis.
  Future<void> _processSharedText(String text) async {
    final match = _urlRegex.firstMatch(text.trim());

    if (match == null) {
      // No URL found -- show friendly error, let user dismiss.
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage =
              'No URL was found in the shared content.\n\nMake sure you share a web link or paste a URL directly.';
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

    if (mounted) {
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    }
  }

  /// Closes the share screen and returns to whatever was open before.
  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CyberGuard -- Link Check'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Dismiss',
          onPressed: _dismiss,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // -- 1. Analysing spinner --
    if (_isAnalyzing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Analyzing Shared Link...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_extractedUrl != null) ...[
                const SizedBox(height: 10),
                Text(
                  _extractedUrl!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // -- 2. No URL found --
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off, size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'No URL Detected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // -- 3. Result card --
    if (_result != null) {
      return Column(
        children: [
          ResultCard(
            scanResult: _result!,
            onAction: _dismiss,
            actionLabel: 'Close',
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

/// Wires up [ReceiveSharingIntent] streams and navigates to [ShareReceiveScreen]
/// whenever the app receives a plain-text / URL share from another app.
///
/// Call [ShareIntentHandler.listen] once in [main] after [runApp].
class ShareIntentHandler {
  ShareIntentHandler._();

  static void listen(GlobalKey<NavigatorState> navigatorKey) {
    // Cold-start: app launched via the Share menu
    ReceiveSharingIntent.instance.getInitialMedia().then((sharedFiles) {
      final text = _extractText(sharedFiles);
      if (text != null && text.isNotEmpty) {
        _navigate(navigatorKey, text);
      }
    });

    // Warm-start: app already running, a new share arrives
    ReceiveSharingIntent.instance.getMediaStream().listen((sharedFiles) {
      final text = _extractText(sharedFiles);
      if (text != null && text.isNotEmpty) {
        _navigate(navigatorKey, text);
      }
    });
  }

  // For text shares, receive_sharing_intent stores the text in `path`.
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
