import 'package:flutter/material.dart';
import '../services/risk_engine.dart';
import '../services/history_service.dart';
import '../models/scan_result.dart';
import 'widgets/result_card.dart';
import '../core/theme.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.url != null) {
      _analyze(widget.url!);
    }
  }

  Future<void> _analyze(String url) async {
    setState(() => _isLoading = true);
    try {
      final engine = RiskEngine();
      final result = await engine.analyzeUrl(url, ScanSource.autoProtection);
      await HistoryService.instance.saveScan(result);
      final prefs = await SharedPreferences.getInstance();
      final childSafe = prefs.getBool('child_safe_mode') ?? false;
      final protectionEnabled = prefs.getBool('protection_mode_enabled') ?? true;

      if (protectionEnabled &&
          (result.riskLevel == RiskLevel.suspicious ||
              result.riskLevel == RiskLevel.malicious)) {
        await SystemSound.play(SystemSoundType.alert);
        if (await Vibration.hasVibrator() ?? false) {
          await Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
        }
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
          _childSafeMode = childSafe;
          _protectionEnabled = protectionEnabled;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    List<Widget> actions = [];
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
        ResultCard(scanResult: _result!),
        const SizedBox(height: 16),
        ...actions,
      ],
    );
  }
}
