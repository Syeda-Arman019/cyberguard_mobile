import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auto_protection_screen.dart';

/// Receives http/https URLs that Android delivers to CyberGuard through
/// ACTION_VIEW intents (the link chooser / "open with" path — CyberGuard is
/// NOT the default browser and never asks the user to make it one).
///
/// Cold start: MainActivity captures intent.dataString before Dart runs and
/// serves it via [getInitialUrl]. Warm start (singleTask): the URL arrives as
/// a `viewUrl` push while the app is alive.
///
/// All routing is gated on the persisted `protection_mode_enabled` setting:
/// when OFF, the URL is ignored entirely — no analysis, no warning, no siren,
/// and normal link handling is left to the user's own browser.
class ViewIntentHandler {
  ViewIntentHandler._();

  static const MethodChannel _channel =
      MethodChannel('com.example.cyberguard/view');
  static const String _routeName = '/auto-protection-intercept';

  static bool _registered = false;

  /// Recursion guard: when CyberGuard itself launches a verified URL into
  /// the user's browser, Android may echo the opening VIEW intent back to
  /// this app (e.g. "Open with" resolution or an app-link verification
  /// callback). Without suppression the loop would be
  /// CyberGuard → browser → CyberGuard → ... Every successful external
  /// launch records the URL here for a short window; echoes of the SAME URL
  /// are ignored, while a genuinely new tapped link is still intercepted.
  static String? _selfLaunchedUrl;
  static DateTime? _selfLaunchedAt;
  static const Duration _selfLaunchWindow = Duration(seconds: 8);

  /// Marks [url] as launched by CyberGuard itself so the VIEW-intent echo
  /// cannot re-enter interception. Only [openExternal] calls this.
  static void markSelfLaunched(String url) {
    _selfLaunchedUrl = url;
    _selfLaunchedAt = DateTime.now();
  }

  /// True when [url] equals the URL CyberGuard just opened externally and
  /// the echo arrives inside the guard window.
  static bool _isSelfLaunchEcho(String url) {
    final at = _selfLaunchedAt;
    if (_selfLaunchedUrl != url || at == null) return false;
    final isEcho = DateTime.now().difference(at) < _selfLaunchWindow;
    if (!isEcho) {
      // Window expired — clear so old state can never suppress a new tap.
      _selfLaunchedUrl = null;
      _selfLaunchedAt = null;
    }
    return isEcho;
  }

  /// Clears the guard when no external launch actually happened (launchUrl
  /// returned false or threw), so the next genuine tap of the same URL is
  /// still intercepted instead of being wrongly swallowed.
  static void clearSelfLaunched() {
    _selfLaunchedUrl = null;
    _selfLaunchedAt = null;
  }

  /// Registers the view channel and pulls any cold-start URL after the
  /// first frame (so the navigator can accept pushes). Call once from main.
  static void listen(GlobalKey<NavigatorState> navigatorKey) {
    if (_registered) return;
    _registered = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'viewUrl') {
        await _handleUrl(navigatorKey, call.arguments as String?);
      }
      return null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeInitialUrl(navigatorKey);
    });
  }

  static Future<void> _consumeInitialUrl(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    try {
      final url = await _channel.invokeMethod<String>('getInitialUrl');
      await _handleUrl(navigatorKey, url);
    } on PlatformException {
      // Channel not ready — nothing to consume.
    } on MissingPluginException {
      // Not running on Android (e.g. widget tests or other platforms).
    }
  }

  static Future<void> _handleUrl(
    GlobalKey<NavigatorState> navigatorKey,
    String? url,
  ) async {
    debugPrint('VIEW URL RECEIVED: $url');
    if (url == null || url.trim().isEmpty) return;
    final trimmed = url.trim();

    // Only http/https links participate in Auto Protection interception.
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      debugPrint('VIEW URL ignored: not http/https');
      return;
    }

    // CyberGuard → browser echo: never re-intercept our own launches.
    if (_isSelfLaunchEcho(trimmed)) {
      debugPrint('VIEW URL ignored: self-launched echo (recursion guard)');
      return;
    }

    // Respect the persisted Protection Mode setting.
    bool enabled = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool('protection_mode_enabled') ?? true;
    } catch (_) {
      // If prefs fail, keep protection ON (default) like the other screens.
    }
    debugPrint('PROTECTION MODE: ${enabled ? 'ON' : 'OFF'}');
    if (!enabled) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    debugPrint('ROUTING TO AUTO PROTECTION: $trimmed');
    // Consecutive links replace any interception screen already on top
    // (its dispose stops the siren), while never stacking duplicates.
    navigator.popUntil((route) => route.settings.name != _routeName);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AutoProtectionScreen(url: trimmed),
        settings: const RouteSettings(name: _routeName),
      ),
    );
  }
}
