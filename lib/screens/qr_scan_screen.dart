import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';
import '../services/risk_engine.dart';
import 'widgets/result_card.dart';

/// Screen that opens camera to scan a QR code, extracts its URL,
/// and executes automated risk analysis.
class QrScanScreen extends StatefulWidget {
  final RiskEngine? riskEngine;

  const QrScanScreen({super.key, this.riskEngine});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _scannerController;
  late final RiskEngine _riskEngine;

  bool _isAnalyzing = false;
  ScanResult? _scanResult;
  String? _scannedUrl;

  @override
  void initState() {
    super.initState();
    _riskEngine = widget.riskEngine ?? RiskEngine();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Handles barcode detection event.
  void _onBarcodeDetected(BarcodeCapture capture) async {
    // Prevent duplicate scans while analysis is active or result is shown
    if (_isAnalyzing || _scanResult != null) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue ?? barcodes.first.displayValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    final url = rawValue.trim();

    setState(() {
      _isAnalyzing = true;
      _scannedUrl = url;
    });

    // Pause camera stream while analyzing
    await _scannerController.stop();

    ScanResult? result;
    try {
      result = await _riskEngine.analyzeUrl(url, ScanSource.qr);
      await HistoryService.instance.saveScan(result);
    } catch (e) {
      debugPrint('QR analysis error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _scanResult = result;
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Resets scan state to allow scanning another QR code.
  void _restartScan() async {
    setState(() {
      _scanResult = null;
      _scannedUrl = null;
      _isAnalyzing = false;
    });
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_scanResult != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ResultCard(
              scanResult: _scanResult!,
              onAction: _restartScan,
              actionLabel: 'Scan Another QR Code',
            ),
          ],
        ),
      );
    }

    if (_isAnalyzing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Analyzing Scanned QR Code...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_scannedUrl != null) ...[
                const SizedBox(height: 8),
                Text(
                  _scannedUrl!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error) {
            return _buildPermissionError(error);
          },
        ),
        Positioned(
          bottom: 36,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Align QR code within camera frame to scan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a friendly user interface if camera permission is denied or camera fails.
  Widget _buildPermissionError(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 56,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'CyberGuard requires camera access to scan QR codes for malicious links and phishing attacks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _scannerController.start(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Grant Camera Access'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}