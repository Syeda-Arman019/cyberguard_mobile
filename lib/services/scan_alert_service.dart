import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../models/scan_result.dart';
import 'siren_service.dart';

/// Single shared alert flow for ALL scan sources (Manual, QR, Share,
/// Auto Protection). Coordinates, per completed scan result:
///
///  - the existing looping [SirenService] (never duplicated),
///  - the existing vibration pattern,
///  - ONE persistent system notification for dangerous results, gated on the
///    persisted `security_notifications` setting and deduplicated per URL via
///    a stable notification id (only one danger notification exists at a
///    time; a new dangerous result updates it in place).
///
/// Safe results stop the siren and cancel the danger notification. The
/// in-app warning UI (SILENCE ALERT etc.) stays independent and remains
/// responsible for calling [acknowledge] when the user acts on a result.
///
/// The posted notification is deliberately NOT cleared at startup: it must
/// stay in the shade until the user acknowledges the alert in-app, dismisses
/// it themselves, or a later safe result cancels it. Surviving an app restart
/// is exactly the desired persistence.
class ScanAlertService {
  ScanAlertService._();
  static final ScanAlertService instance = ScanAlertService._();

  static const MethodChannel _notifyChannel =
      MethodChannel('com.example.cyberguard/notifications');

  /// Stable notification id: one danger notification app-wide, updated in
  /// place — this is the deduplication mechanism (identical results for the
  /// same URL can never create a second notification).
  static const int _dangerNotificationId = 4242;

  /// URL currently covered by the active danger notification, if any.
  String? _notifiedUrl;

  bool _permissionRequested = false;

  bool isRisky(ScanResult result) =>
      result.riskLevel == RiskLevel.suspicious ||
      result.riskLevel == RiskLevel.malicious;

  /// Handles the alerting for a completed scan result. Call exactly once per
  /// analysis, when the result is known.
  Future<void> handleResult(ScanResult result) async {
    if (!isRisky(result)) {
      // Safe: no siren, no vibration, no danger notification.
      await SirenService.instance.stop();
      await cancelDangerNotification();
      return;
    }
    await _startAlerts(result);
    // Mark the pending notification BEFORE dispatch so acknowledge() always
    // reaches the native cancel even if the user silences the alert while
    // the post is still in flight. Notifications must never delay the
    // on-screen warning, so dispatch is not awaited.
    _notifiedUrl = result.url;
    unawaited(_showDangerNotificationIfAllowed(result));
  }

  /// Starts the looping siren and vibration for a risky result. The siren's
  /// re-entrancy guard guarantees repeated calls never duplicate playback.
  Future<void> _startAlerts(ScanResult result) async {
    unawaited(SirenService.instance.start());
    try {
      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
      }
    } catch (_) {
      // Vibration not supported on this device.
    }
  }

  /// Builds the notification body from data already present on the model:
  /// risk level, URL/domain and the first available reason.
  @visibleForTesting
  String buildNotificationBody(ScanResult result) {
    final level = result.riskLevel == RiskLevel.malicious
        ? 'MALICIOUS'
        : 'SUSPICIOUS';
    String domain = result.url;
    try {
      final uri = Uri.tryParse(result.url);
      final host = uri?.host;
      if (host != null && host.isNotEmpty) domain = host;
    } catch (_) {
      // Keep the full URL if parsing fails.
    }
    final buffer = StringBuffer('$level — $domain (score ${result.riskScore}/100)');
    if (result.reasons.isNotEmpty) {
      buffer.write(' — ${result.reasons.first}');
    }
    return buffer.toString();
  }

  Future<void> _showDangerNotificationIfAllowed(ScanResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool('security_notifications') ?? true;
      if (!notificationsEnabled) return;

      // Dedup: the same URL already owns the active danger notification, so
      // a re-analysis of it needs no further native call (update-in-place
      // for a DIFFERENT URL still replaces the single stable-id slot).
      if (_notifiedUrl == result.url) return;
      await _notifyChannel.invokeMethod<bool>('showDangerNotification', {
        'id': _dangerNotificationId,
        'title': 'CyberGuard — Dangerous URL Detected',
        'body': buildNotificationBody(result),
      });
      _notifiedUrl = result.url;
    } on MissingPluginException {
      // Not running on Android (tests/desktop) — in-app alert remains.
    } on PlatformException {
      // Notification rejected (permission revoked mid-session, etc.).
    } catch (_) {
      // Never let notification failures break the scan flow.
    }
  }

  /// Cancels any ongoing vibration without blocking the caller: the cancel
  /// call is fire-and-forget so awaited alert paths never stall on a plugin
  /// channel round trip.
  void _cancelVibration() {
    unawaited(() async {
      try {
        await Vibration.cancel();
      } catch (_) {
        // Vibration not supported on this device.
      }
    }());
  }

  /// Requests POST_NOTIFICATIONS once (Android 13+). Call after the first
  /// frame from main.dart; user consent is required for the system alert.
  Future<void> ensureNotificationPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Older Android versions or unsupported platform — nothing to do.
    }
  }

  /// The user interacted with the danger result (SILENCE ALERT, GO BACK,
  /// OPEN ANYWAY): stop siren + vibration and cancel the notification.
  Future<void> acknowledge() async {
    await SirenService.instance.stop();
    _cancelVibration();
    await cancelDangerNotification();
  }

  /// Stops the siren and vibration (leaving screens, new scans) without
  /// touching notification acknowledgment.
  Future<void> stopSounds() async {
    await SirenService.instance.stop();
    _cancelVibration();
  }

  /// Cancels the danger notification. Sent unconditionally: a cancel that
  /// arrives while the post is still in flight must still win (the native
  /// side processes calls in order), so there is no "nothing to cancel"
  /// short-circuit here.
  Future<void> cancelDangerNotification() async {
    _notifiedUrl = null;
    try {
      await _notifyChannel.invokeMethod<bool>('cancelDangerNotification', {
        'id': _dangerNotificationId,
      });
    } catch (_) {
      // Native side unavailable — nothing to cancel.
    }
  }
}
