import 'package:flutter/material.dart';
import 'manual_scan_screen.dart';
import 'qr_scan_screen.dart';
import 'share_receive_screen.dart';
import 'history_screen.dart';

/// Simple entry-point menu for CyberGuard Mobile.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CyberGuard Mobile — URL Security'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Manual URL Scan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManualScanScreen()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR Code Scan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScanScreen()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share to CyberGuard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ShareReceiveScreen(sharedText: '')),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Scan History'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HistoryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}