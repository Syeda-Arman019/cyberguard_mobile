// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../models/scan_result.dart';
import 'widgets/result_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ScanResult> scans = HistoryService.instance.getAllScans();
    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: scans.isEmpty
          ? const Center(child: Text('No scans yet'))
          : ListView.builder(
              itemCount: scans.length,
              itemBuilder: (context, index) {
                final scan = scans[index];
                return ResultCard(scanResult: scan);
              },
            ),
    );
  }
}
