import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'models/scan_result.dart';
import 'services/history_service.dart';
import 'services/scan_alert_service.dart';
import 'services/view_intent_handler.dart';
import 'screens/dashboard_screen.dart';
import 'screens/share_receive_screen.dart';

/// Global navigator key used by ShareIntentHandler
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Register generated Hive adapters
  Hive.registerAdapter(RiskLevelAdapter());
  Hive.registerAdapter(ThreatTypeAdapter());
  Hive.registerAdapter(ScanSourceAdapter());
  Hive.registerAdapter(ScanResultAdapter());
  await HistoryService.instance.init();

  // Start the intent handlers after the first frame so the navigator is
  // ready: ACTION_SEND (Share-to-CyberGuard) and ACTION_VIEW (link
  // interception into Auto Protection).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ShareIntentHandler.listen(_navigatorKey);
    ViewIntentHandler.listen(_navigatorKey);
    // Ask for POST_NOTIFICATIONS once (Android 13+). Note: any danger
    // notification from a previous session is deliberately left in the
    // shade — it must stay until the user acknowledges it in-app or a safe
    // result cancels it.
    ScanAlertService.instance.ensureNotificationPermission();
  });

  runApp(const CyberGuardApp());
}

class CyberGuardApp extends StatelessWidget {
  const CyberGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberGuard Mobile',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      navigatorObservers: [dashboardRouteObserver],
      theme: CyberTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}