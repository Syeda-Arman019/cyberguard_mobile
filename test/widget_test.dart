import 'package:flutter_test/flutter_test.dart';
import 'package:cyberguard_mobile/main.dart';
import 'package:cyberguard_mobile/models/scan_result.dart';
import 'package:cyberguard_mobile/screens/dashboard_screen.dart';
import 'package:cyberguard_mobile/services/history_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'dart:io';

/// Minimal path-provider stub so Hive.initFlutter() works in the test env
/// (the plugin is not registered on the test binding by default).
class _TestPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.createTempSync('widget_test_hive_').path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    PathProviderPlatform.instance = _TestPathProvider();
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScanResultAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RiskLevelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ThreatTypeAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ScanSourceAdapter());
    await HistoryService.instance.init();
  });

  testWidgets('CyberGuardApp smoke test renders the app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CyberGuardApp());

    // Bounded pumps: the shell hosts live-refreshing dashboard widgets whose
    // frames keep being scheduled, so pumpAndSettle does not converge.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    // The app shell (bottom-nav MainShellScreen) renders with the Dashboard
    // as its initial tab.
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
