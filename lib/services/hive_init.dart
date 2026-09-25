import 'package:hive_flutter/hive_flutter.dart';

import '../models/scan_result.dart';
import 'history_service.dart';

/// Hive initialization shared by the UI engine (main.dart) and the headless
/// background engine (autoProtectionBackgroundMain). Each FlutterEngine is a
/// separate Dart isolate, so the background engine must register adapters and
/// open boxes itself before HistoryService can save scans.
Future<void> initHiveForBackgroundEngine() async {
  await Hive.initFlutter();
  Hive.registerAdapter(RiskLevelAdapter());
  Hive.registerAdapter(ThreatTypeAdapter());
  Hive.registerAdapter(ScanSourceAdapter());
  Hive.registerAdapter(ScanResultAdapter());
  await HistoryService.instance.init();
}
