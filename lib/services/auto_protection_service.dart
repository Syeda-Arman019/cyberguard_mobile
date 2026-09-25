import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hive_init.dart';

import '../models/scan_result.dart';
import 'history_service.dart';
import 'risk_engine.dart';
import 'scan_alert_service.dart';

/// Auto Protection — Phase 1 (Notification Scanner).
///
/// The native [LinkNotificationListener] (Kotlin) watches notifications from
/// user-enabled apps and pushes every newly discovered URL here through the
/// `com.example.cyberguard/autoprotection` channel. This class then runs the
/// EXISTING pipeline:
///
///   RiskEngine.analyzeUrl(url, ScanSource.autoProtection)
///     → HistoryService.saveScan(result)          (existing)
///     → ScanAlertService.handleResult(result)    (existing siren/vibration/
///                                                 notification for risky)
///
/// No duplicate alert system: alerts for risky results are emitted by the
/// existing ScanAlertService exactly as in Manual/QR/Share scanning. When a
/// risky URL is detected while the app is closed, the native AlertManager
/// posts a heads-up notification + bounded siren so the user is still warned.
/// Headless Dart entrypoint for the background FlutterEngine created by
/// AutoProtectionForegroundService when the UI is closed. Must keep the exact
/// pragma so release AOT builds retain it.
@pragma('vm:entry-point')
/// Real background entrypoint body. Wrapped by the entrypoint function in
/// main.dart (entrypoints must live in the default library).
@pragma('vm:entry-point')
Future<void> runAutoProtectionBackgroundMain() async {
  // Background engine needs Hive (HistoryService) initialized.
  await initHiveForBackgroundEngine();
  AutoProtectionService.instance.listen(isBackground: true);
}

class AutoProtectionService {
  AutoProtectionService._();
  static final AutoProtectionService instance = AutoProtectionService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.cyberguard/autoprotection');

  static const String _masterKey = 'auto_protection_enabled';
  static const String _notifScanKey = 'auto_protection_notification_scan';
  static const String _safeNotifyKey = 'auto_protection_notify_safe';
  static const String _sirenKey = 'auto_protection_siren';
  static const String _vibrationKey = 'auto_protection_vibration';
  static const String _packagesKey = 'auto_protection_packages';

  /// Default packages scanned (mirrors LinkNotificationListener.DEFAULT_PACKAGES).
  static const List<String> defaultPackages = [
    'com.whatsapp',
    'com.whatsapp.w4b',
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.android.mms',
    'com.android.messaging',
    'com.google.android.gm',
    'com.microsoft.office.outlook',
    'com.microsoft.android.outlook',
    'org.telegram.messenger',
    'com.facebook.orca',
    'com.facebook.mlite',
    'com.instagram.android',
  ];

  bool _registered = false;
  bool _busy = false;

  /// Per-URL in-flight/processed guard: one incoming URL = one analysis,
  /// even if the listener redelivers (service restart, dedup window end).
  final Set<String> _processing = {};
  final Map<String, DateTime> _processedAt = {};
  static const Duration _processedTtl = Duration(minutes: 10);

  bool get isSupported => !Platform.isAndroid;

  /// Registers the channel handlers. Called from main.dart (UI engine) and
  /// from [autoProtectionBackgroundMain] (headless engine). The background
  /// engine additionally signals `backgroundReady` so native queues flush.
  void listen({bool isBackground = false}) {
    if (_registered || isSupported) return;
    _registered = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNotificationUrl':
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          final url = args['url'] as String?;
          final pkg = args['sourcePackage'] as String? ?? 'unknown';
          if (url != null) {
            unawaited(_handleNotificationUrl(url, pkg).then((_) {
              // Acknowledge so the native fallback timer is cancelled.
              _channel.invokeMethod('analysisComplete', {'url': url})
                  .catchError((_) => null);
            }));
          }
          return null;
        case 'getSettings':
          final prefs = await SharedPreferences.getInstance();
          return {
            'master': prefs.getBool(_masterKey) ?? false,
            'notifScan': prefs.getBool(_notifScanKey) ?? false,
            'notifySafe': prefs.getBool(_safeNotifyKey) ?? false,
            'siren': prefs.getBool(_sirenKey) ?? true,
            'vibration': prefs.getBool(_vibrationKey) ?? true,
            'packages': prefs.getStringList(_packagesKey) ?? defaultPackages,
          };
      }
      return null;
    });

    _pushSettings();
    if (isBackground) {
      // Tell native this engine is live so queued URLs are flushed here.
      _channel.invokeMethod('backgroundReady').catchError((_) => null);
    } else {
      _applyServiceState();
    }
  }

  /// Pushes the persisted package allowlist down to the native listener.
  Future<void> _pushSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pkgs = prefs.getStringList(_packagesKey) ?? defaultPackages;
      await _channel.invokeMethod('setAllowedPackages', {'packages': pkgs});
    } catch (_) {
      // Native side not ready (tests / other platforms) — nothing to do.
    }
  }

  /// Starts or stops the native foreground service to match the persisted
  /// master + notification-scan toggles.
  Future<void> _applyServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          (prefs.getBool(_masterKey) ?? false) &&
          (prefs.getBool(_notifScanKey) ?? false);
      if (enabled) {
        await _channel.invokeMethod('startService');
      } else {
        await _channel.invokeMethod('stopService');
      }
    } catch (_) {
      // Native side not ready — nothing to do.
    }
  }

  /// Called by the Settings screen when any Auto Protection toggle changes.
  Future<void> onSettingsChanged() async {
    await _pushSettings();
    await _applyServiceState();
  }

  /// Core handler: analyzes one URL discovered in a notification using the
  /// EXISTING engine/history/alert pipeline. Never runs concurrently with
  /// itself (one scan at a time keeps alerts coherent).
  Future<void> _handleNotificationUrl(String rawUrl, String sourcePackage) async {
    // Master switch off → ignore entirely (no analysis, no alerts).
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_masterKey) ?? false;
    final notifScan = prefs.getBool(_notifScanKey) ?? false;
    if (!enabled || !notifScan) return;

    // Same-URL dedup (native dedup already applies, this is the Dart-side
    // belt-and-braces so redelivery after a listener restart can't double-
    // alert). One URL = one analysis.
    final url = rawUrl.trim();
    final now = DateTime.now();
    _processedAt.removeWhere((_, t) => now.difference(t) > _processedTtl);
    if (_processing.contains(url) ||
        (_processedAt.containsKey(url) &&
            now.difference(_processedAt[url]!) < _processedTtl)) {
      return;
    }
    if (_busy) return; // drop while a scan is in flight (rare: scans are fast)
    _busy = true;
    _processing.add(url);
    try {
      // 1. EXISTING RiskEngine (bounded: its own GSB timeout is 4s; we allow
      //    8s total so a slow network can still fall back to local checks).
      final engine = RiskEngine();
      final result = await engine
          .analyzeUrl(url, ScanSource.autoProtection)
          .timeout(const Duration(seconds: 8));
      _processedAt[url] = DateTime.now();

      // 2. EXISTING HistoryService.
      await HistoryService.instance.saveScan(result);

      // 3. EXISTING ScanAlertService for risky results (siren + vibration +
      //    persistent notification, all severity-bounded as before). Safe
      //    results stay silent by default ("notify for safe links" OFF).
      final risky = result.riskLevel != RiskLevel.safe;
      if (risky) {
        final sirenOn = prefs.getBool(_sirenKey) ?? true;
        final vibrationOn = prefs.getBool(_vibrationKey) ?? true;
        if (sirenOn || vibrationOn) {
          await ScanAlertService.instance.handleResult(result);
        } else {
          // Alerts disabled: only the persistent notification path remains
          // (it is gated by the existing security_notifications setting).
          await ScanAlertService.instance.cancelDangerNotification();
          // Still record a native heads-up so background users are warned.
          _nativeAlert(sourcePackage, result, sound: false, vibrate: false);
          return;
        }
        // If the app is backgrounded, the Dart siren may not be audible —
        // ask the native side for the heads-up + alarm-sound fallback.
        _nativeAlert(sourcePackage, result, sound: sirenOn, vibrate: vibrationOn);
      } else {
        await ScanAlertService.instance.cancelDangerNotification();
        final notifySafe = prefs.getBool(_safeNotifyKey) ?? false;
        if (notifySafe) {
          _nativeSafeNotice(url, sourcePackage);
        }
      }
    } on TimeoutException {
      // Mark as not fully verified: record a cautious suspicious entry.
      _processedAt[url] = DateTime.now();
      final result = ScanResult(
        url: url,
        riskScore: 45,
        riskLevel: RiskLevel.suspicious,
        threatType: ThreatType.suspiciousDomain,
        reasons: const [
          'Analysis timed out before the link could be fully verified.',
        ],
        recommendation:
            'Treat this link as not fully verified. Open only if you trust the sender.',
        source: ScanSource.autoProtection,
        timestamp: DateTime.now(),
      );
      await HistoryService.instance.saveScan(result);
      _nativeAlert(sourcePackage, result, sound: true, vibrate: true);
    } catch (_) {
      // Never let a single malformed notification break the listener.
    } finally {
      _busy = false;
      _processing.remove(url);
    }
  }

  /// Native heads-up fallback for background detections. The native side
  /// decides whether to actually sound/vibrate (it re-checks the same flags).
  void _nativeAlert(String sourcePackage, ScanResult result,
      {required bool sound, required bool vibrate}) {
    final appName = _prettyPackage(sourcePackage);
    _channel.invokeMethod('alertDanger', {
      'level': result.riskLevel == RiskLevel.malicious ? 'MALICIOUS' : 'SUSPICIOUS',
      'url': result.url,
      'sourceApp': appName,
      'reason': result.reasons.isNotEmpty ? result.reasons.first : '',
      'sound': sound,
      'vibrate': vibrate,
    }).catchError((_) => null);
  }

  void _nativeSafeNotice(String url, String sourcePackage) {
    _channel.invokeMethod('notifySafe', {
      'url': url,
      'sourceApp': _prettyPackage(sourcePackage),
    }).catchError((_) => null);
  }

  static String _prettyPackage(String pkg) {
    const map = {
      'com.whatsapp': 'WhatsApp',
      'com.whatsapp.w4b': 'WhatsApp Business',
      'com.google.android.apps.messaging': 'Messages',
      'com.samsung.android.messaging': 'Messages',
      'com.android.mms': 'SMS',
      'com.android.messaging': 'SMS',
      'com.google.android.gm': 'Gmail',
      'com.microsoft.office.outlook': 'Outlook',
      'com.microsoft.android.outlook': 'Outlook',
      'org.telegram.messenger': 'Telegram',
      'com.facebook.orca': 'Messenger',
      'com.facebook.mlite': 'Messenger Lite',
      'com.instagram.android': 'Instagram',
    };
    return map[pkg] ?? pkg;
  }
}
