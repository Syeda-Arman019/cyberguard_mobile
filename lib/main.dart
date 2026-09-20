import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/history_service.dart';
import 'screens/home_screen.dart';

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

  // Start ShareIntentHandler after the first frame so the navigator is ready
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ShareIntentHandler.listen(_navigatorKey);
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
