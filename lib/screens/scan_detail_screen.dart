import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';
import 'widgets/result_card.dart';

class ScanDetailScreen extends StatelessWidget {
  final ScanResult scanResult;

  const ScanDetailScreen({super.key, required this.scanResult});

  Future<void> _deleteScan(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('This record will be permanently removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: CyberColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CyberColors.malicious,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryService.instance.deleteScan(scanResult.timestamp);
      if (context.mounted) {
        Navigator.pop(context, true); // true indicates item was deleted
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Analysis Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: CyberColors.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: CyberColors.malicious),
            tooltip: 'Delete Record',
            onPressed: () => _deleteScan(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: CyberColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ResultCard(
              scanResult: scanResult,
              onDelete: () => _deleteScan(context),
            ),
          ),
        ),
      ),
    );
  }
}
