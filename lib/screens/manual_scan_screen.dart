// lib/screens/manual_scan_screen.dart (clean implementation)
import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../services/risk_engine.dart';
import '../services/history_service.dart';
import 'widgets/result_card.dart';

class ManualScanScreen extends StatefulWidget {
  final RiskEngine? riskEngine;
  const ManualScanScreen({Key? key, this.riskEngine}) : super(key: key);

  @override
  State<ManualScanScreen> createState() => _ManualScanScreenState();
}

class _ManualScanScreenState extends State<ManualScanScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  ScanResult? _scanResult;
  String? _inputError;
  late final RiskEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = widget.riskEngine ?? RiskEngine();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
    });
    final result = await _engine.analyzeUrl(rawUrl, ScanSource.manual);
    if (!mounted) return;
    setState(() {
      _scanResult = result;
      _isLoading = false;
    });
    // Save to history
    await HistoryService.instance.saveScan(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual URL Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _analyzeUrl(),
              decoration: InputDecoration(
                labelText: 'Enter URL',
                hintText: 'https://example.com',
                errorText: _inputError,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _urlController.clear();
                          setState(() => _inputError = null);
                        },
                      )
                    : null,
              ),
              onChanged: (_) {
                if (_inputError != null) setState(() => _inputError = null);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeUrl,
              icon: const Icon(Icons.security),
              label: const Text('Analyze'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Scanning URL for security threats...'),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _scanResult != null) ResultCard(scanResult: _scanResult!),
          ],
        ),
      ),
    );
  }
}
