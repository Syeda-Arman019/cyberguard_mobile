import 'package:hive/hive.dart';
import '../models/scan_result.dart';

/// Service for persisting scan history using Hive.
///
/// It is a singleton; call `HistoryService.instance.init()` before use (done in main).
class HistoryService {
  HistoryService._private();
  static final HistoryService instance = HistoryService._private();

  static const String _boxName = 'scan_history';
  late final Box<ScanResult> _box;

  /// Initialize Hive and open the box. Must be awaited before any other method.
  Future<void> init() async {
    _box = await Hive.openBox<ScanResult>(_boxName);
  }

  /// Save a scan result using Hive's auto-generated integer key.
  /// This avoids overflow errors from using raw timestamps as keys.
  Future<void> saveScan(ScanResult result) async {
    await _box.add(result);
  }

  /// Retrieve all scans, sorted newest first.
  List<ScanResult> getAllScans() {
    final results = _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  /// Delete a scan identified by its timestamp.
  /// Finds the Hive key for the matching ScanResult and removes it.
  Future<void> deleteScan(DateTime timestamp) async {
    dynamic keyToDelete;
    for (final key in _box.keys) {
      final scan = _box.get(key);
      if (scan != null && scan.timestamp == timestamp) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      await _box.delete(keyToDelete);
    }
  }

  /// Expose the underlying box for UI (e.g., ValueListenableBuilder).
  Box<ScanResult> get box => _box;
}