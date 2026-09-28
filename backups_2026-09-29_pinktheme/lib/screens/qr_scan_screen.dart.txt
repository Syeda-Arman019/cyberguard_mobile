import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';
import '../services/risk_engine.dart';
import '../services/scan_alert_service.dart';
import 'widgets/result_card.dart';
import 'widgets/cyber_components.dart';

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
  bool _isTorchOn = false;
  bool _alertSilenced = false;

  /// Real Android camera permission state, checked before the scanner starts.
  PermissionStatus? _cameraStatus;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _riskEngine = widget.riskEngine ?? RiskEngine();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _ensureCameraPermission();
  }

  /// Checks the REAL camera permission before starting the scanner. The
  /// controller is only started once the OS reports the permission granted.
  Future<void> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      // First entry with no decision yet — show the in-app dialog.
      if (mounted) {
        final granted = await _showPermissionDialog();
        if (granted) {
          status = await Permission.camera.status;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _cameraStatus = status;
      _checkingPermission = false;
    });
    if (status.isGranted) {
      // Permission granted — start the scanner normally.
      try {
        await _scannerController.start();
      } catch (_) {
        // errorBuilder covers hardware/camera-stream failures.
      }
    }
  }

  /// Professional in-app permission explanation dialog. Returns true when
  /// the permission ended up granted (user accepted the OS prompt).
  Future<bool> _showPermissionDialog() async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: CyberColors.cardBgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.photo_camera_rounded, color: CyberColors.cyan),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Camera Permission Required',
                style: TextStyle(fontSize: 17, color: CyberColors.textPrimary),
              ),
            ),
          ],
        ),
        content: const Text(
          'CyberGuard needs access to your device camera to scan QR codes '
          'and analyze the links they contain for phishing and malware. '
          'No photos or videos are ever stored.',
          style: TextStyle(color: CyberColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Not Now',
                style: TextStyle(color: CyberColors.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: CyberColors.cyan,
              foregroundColor: CyberColors.bgDark,
            ),
            onPressed: () async {
              final result = await Permission.camera.request();
              if (c.mounted) Navigator.pop(c, result.isGranted);
            },
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Grant Permission'),
          ),
        ],
      ),
    );
    return granted == true;
  }

  /// Re-check after returning from OS settings (permanently denied path).
  Future<void> _recheckFromSettings() async {
    await openAppSettings();
    if (!mounted) return;
    final status = await Permission.camera.status;
    setState(() => _cameraStatus = status);
    if (status.isGranted) {
      try {
        await _scannerController.start();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    // Never leave the siren/vibration running after leaving the screen.
    ScanAlertService.instance.stopSounds();
    _scannerController.dispose();
    super.dispose();
  }

  /// Stops the audible warning + danger notification when the user
  /// acknowledges the result.
  Future<void> _silenceAlert() async {
    await ScanAlertService.instance.acknowledge();
    if (!mounted) return;
    setState(() => _alertSilenced = true);
  }

  /// Handles barcode detection event.
  void _onBarcodeDetected(BarcodeCapture capture) async {
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

    await _scannerController.stop();

    ScanResult? result;
    try {
      result = await _riskEngine.analyzeUrl(url, ScanSource.qr);
      await HistoryService.instance.saveScan(result);
    } catch (e) {
      debugPrint('QR analysis error: $e');
    } finally {
      if (mounted && result != null) {
        // Show the result immediately; alerts run in parallel afterwards.
        setState(() {
          _scanResult = result;
          _isAnalyzing = false;
        });
        // Shared alert flow: siren + vibration + persistent notification
        // for risky results; all stopped/cancelled for safe results.
        await ScanAlertService.instance.handleResult(result);
      } else if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _restartScan() async {
    // A new scan resets the alert state and stops any ringing siren.
    ScanAlertService.instance.stopSounds();
    setState(() {
      _scanResult = null;
      _scannedUrl = null;
      _isAnalyzing = false;
      _alertSilenced = false;
    });
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: CyberColors.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? CyberColors.cyan : CyberColors.textSecondary,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded, color: CyberColors.cyan),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Real camera permission gate: never start the scanner without the OS
    // reporting the permission granted.
    if (_checkingPermission || !(_cameraStatus?.isGranted ?? false)) {
      return _buildPermissionGate();
    }

    if (_scanResult != null) {
      final bool isRisky = _scanResult!.riskLevel == RiskLevel.suspicious ||
          _scanResult!.riskLevel == RiskLevel.malicious;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                  'Analyzing QR Link...',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_scannedUrl != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _scannedUrl!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CyberColors.cyan,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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

        // Cyber Scanner Targeting Overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: CyberColors.cyan.withAlpha(160), width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // 4 glowing corners
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: CyberColors.cyan, width: 3.5),
                        left: BorderSide(color: CyberColors.cyan, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: CyberColors.cyan, width: 3.5),
                        right: BorderSide(color: CyberColors.cyan, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: CyberColors.cyan, width: 3.5),
                        left: BorderSide(color: CyberColors.cyan, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: CyberColors.cyan, width: 3.5),
                        right: BorderSide(color: CyberColors.cyan, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Instruction Pill
        Positioned(
          bottom: 36,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: CyberColors.bgDark.withAlpha(220),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: CyberColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: CyberColors.cyan, size: 18),
                SizedBox(width: 8),
                Text(
                  'Align QR code inside target frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// In-app permission UI shown when the camera permission is not granted:
  /// request button for a normal denial, Open Settings when permanently
  /// denied by the OS.
  Widget _buildPermissionGate() {
    final permanentlyDenied = _cameraStatus?.isPermanentlyDenied ?? false;
    return Container(
      decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CyberCard(
            padding: const EdgeInsets.all(24.0),
            child: _checkingPermission
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(CyberColors.cyan),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        size: 52,
                        color: CyberColors.suspicious,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Permission Required',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: CyberColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'CyberGuard requires camera access to scan physical QR codes for phishing links and malicious URLs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: CyberColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      permanentlyDenied
                          ? PrimaryCyberButton(
                              onPressed: _recheckFromSettings,
                              icon: Icons.settings_outlined,
                              label: 'Open Settings',
                            )
                          : PrimaryCyberButton(
                              onPressed: _ensureCameraPermission,
                              icon: Icons.camera_alt_rounded,
                              label: 'Grant Permission',
                            ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionError(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: CyberCard(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 52,
                color: CyberColors.suspicious,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Access Required',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: CyberColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'CyberGuard requires camera access to scan physical QR codes for phishing links and malicious URLs.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: CyberColors.textSecondary),
              ),
              const SizedBox(height: 20),
              PrimaryCyberButton(
                onPressed: _recheckFromSettings,
                icon: Icons.settings_outlined,
                label: 'Open Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}