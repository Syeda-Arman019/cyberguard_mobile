// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../models/scan_result.dart';
import 'widgets/result_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<ScanResult> scans;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  void _loadScans() {
    scans = HistoryService.instance.getAllScans();
    setState(() {});
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all scan history?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete All')),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.instance.deleteAllScans();
      _loadScans();
    }
  }

  Future<void> _deleteScan(ScanResult scan) async {
    await HistoryService.instance.deleteScan(scan.timestamp);
    _loadScans();
  }

  Future<void> _confirmDelete(ScanResult scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this scan from history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteScan(scan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete All',
            onPressed: _confirmDeleteAll,
          ),
        ],
      ),
      body: scans.isEmpty
          ? const Center(child: Text('No scans yet'))
          : ListView.builder(
              itemCount: scans.length,
              itemBuilder: (context, index) {
                final scan = scans[index];
                return Dismissible(
                  key: ValueKey(scan.timestamp.toIso8601String()),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _confirmDelete(scan);
                    return false; // we handle deletion manually
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ResultCard(
                    scanResult: scan,
                    onDelete: () => _confirmDelete(scan),
                  ),
                );
              },
            ),
    );
  }
}
