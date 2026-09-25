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
///  - the existing [SirenService] (never duplicated, never an endless loop):
///    MALICIOUS → bounded 3-repeat alarm; SUSPICIOUS → single short pass,
///  - vibration matched to severity (short pulse for suspicious, stronger
///    pattern for malicious), triggered exactly once per scan event,
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

  /// Native Auto Protection channel — used only to stop the native fallback
  /// siren/vibration and cancel the native 4243 heads-up on acknowledgement.
  static const MethodChannel _apChannel =
      MethodChannel('com.example.cyberguard/autoprotection');

  /// Stable notification id: one danger notification app-wide, updated in
  /// place — this is the deduplication mechanism (identical results for the
  /// same URL can never create a second notification).
  static const int _dangerNotificationId = 4242;

  /// Last alerted URL event, used to suppress duplicate sound/vibration when
  /// the same result is delivered again within [_duplicateWindow] (rebuilds,
  /// re-entry) — a genuine re-scan after that window alerts normally.
  String? _lastAlertedUrl;
  DateTime? _lastAlertedAt;
  static const Duration _duplicateWindow = Duration(seconds: 5);

  bool _permissionRequested = false;

  bool isRisky(ScanResult result) =>
      result.riskLevel == RiskLevel.suspicious ||
      result.riskLevel == RiskLevel.malicious;

  /// Handles the alerting for a completed scan result. Call exactly once per
  /// analysis, when the result is known.
  Future<void> handleResult(ScanResult result) async {
    if (!isRisky(result)) {
      // Safe: no siren, no vibration, no danger notification.
      _lastAlertedUrl = null;
      _lastAlertedAt = null;
      await SirenService.instance.stop();
      await cancelDangerNotification();
      return;
    }
    // Duplicate guard: the same result delivered again within the window
    // (rebuild, re-entry) never re-triggers sound/vibration/notification.
    if (_isDuplicateAlert(result.url)) return;
    await _startAlerts(result);
    _lastAlertedUrl = result.url;
    _lastAlertedAt = DateTime.now();
    // Fire-and-forget: notifications must never delay the on-screen warning,
    // and an acknowledge() that races this post still cancels reliably —
    // channel calls are processed in order, so cancel-after-post wins.
    unawaited(_showDangerNotificationIfAllowed(result));
  }

  /// Starts the severity-matched sound + vibration for a risky result. The
  /// siren's re-entrancy guard guarantees repeated calls never duplicate
  /// playback; vibration patterns are stronger for MALICIOUS results and a
  /// short single pulse for SUSPICIOUS ones (never continuous).
  Future<void> _startAlerts(ScanResult result) async {
    unawaited(SirenService.instance.start(level: result.riskLevel));
    try {
      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        final pattern = result.riskLevel == RiskLevel.malicious
            ? const [0, 400, 200, 400, 200, 400] // strong, bounded pattern
            : const [0, 300]; // short single warning pulse
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (_) {
      // Vibration not supported on this device.
    }
  }

  /// True when the same URL was already alerted within [_duplicateWindow].
  bool _isDuplicateAlert(String url) {
    final last = _lastAlertedAt;
    if (_lastAlertedUrl != url || last == null) return false;
    return DateTime.now().difference(last) < _duplicateWindow;
  }

  /// Builds the expanded notification detail from data already present on
  /// the model: risk level, URL/domain, score and the first reason.
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

      // POST unconditionally: _notifiedUrl was already claimed by
      // handleResult before this dispatch, so comparing against it here
      // would always match and skip the post entirely (the shade would
      // never show the alert). Repeated scans of the same URL are already
      // prevented upstream by the duplicate window; a DIFFERENT risky URL
      // legitimately replaces the single stable-id notification in place.
      final shortBody = result.riskLevel == RiskLevel.malicious
          ? 'Malicious URL detected. Tap to review the security warning.'
          : 'Suspicious URL detected. Tap to review the security warning.';
      await _notifyChannel.invokeMethod<bool>('showDangerNotification', {
        'id': _dangerNotificationId,
        'title': '⚠️ CyberGuard Security Alert',
        'body': shortBody,
        // Rich detail (level, domain, score, first reason) shown when the
        // notification is expanded.
        'detail': buildNotificationBody(result),
        // Carried on the tap intent so opening the notification routes to
        // the existing warning screen for THIS result (SILENCE ALERT etc.),
        // never the bare dashboard.
        'url': result.url,
      });
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
  /// OPEN ANYWAY): stop siren + vibration and cancel the notification. The
  /// duplicate guard is also reset so a genuinely new scan event can alert
  /// again.
  Future<void> acknowledge() async {
    await SirenService.instance.stop();
    _cancelVibration();
    // Auto Protection alerts also start the NATIVE fallback siren +
    // vibration (AlertManager, alarm-stream MediaPlayer). SILENCE ALERT must
    // kill BOTH — the user hears one alert, not two systems.
    stopNativeAlerts();
    _lastAlertedUrl = null;
    _lastAlertedAt = null;
    await cancelDangerNotification();
  }

  /// Fire-and-forget stop of the native AlertManager siren + vibration.
  void stopNativeAlerts() {
    try {
      unawaited(_apChannel.invokeMethod<bool>('stopAlertSounds')
          .catchError((_) => null));
    } catch (_) {
      // Not on Android / native side not ready.
    }
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
    try {
      await _notifyChannel.invokeMethod<bool>('cancelDangerNotification', {
        'id': _dangerNotificationId,
      });
    } catch (_) {
      // Native side unavailable — nothing to cancel.
    }
  }
}
