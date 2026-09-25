import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/scan_result.dart';

/// Plays the bundled local siren (`sounds/siren_alert.wav`) as a bounded
/// security alarm — never an endless loop.
///
/// Per completed risky scan, [start] is called with the risk level:
///  - MALICIOUS: the siren repeats 3 times (a clear, attention-grabbing alarm).
///  - SUSPICIOUS: a single pass (a short warning tone).
///  - SAFE: [stop] is called and nothing is played.
///
/// Playback runs on the **alarm** audio usage on Android so the warning is
/// audible at the user's alarm volume even when media volume is low. It still
/// respects the device's alarm/ringer settings — it does not force sound on a
/// fully muted device.
///
/// The siren is a singleton with a single internal player and an
/// initialization guard, so repeated calls for the same URL event (widget
/// rebuilds, navigation) can never create duplicate or overlapping playback.
class SirenService {
  SirenService._private();
  static final SirenService instance = SirenService._private();

  static const String _asset = 'sounds/siren_alert.wav';

  /// How many times the siren repeats for a MALICIOUS result.
  static const int _maliciousRepeats = 3;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  int _remainingRepeats = 0;
  StreamSubscription<void>? _completeSub;

  /// Whether the siren is currently sounding.
  bool get isPlaying => _isPlaying;

  /// Plays the local siren for the given risk level and returns when the
  /// bounded playback finishes. Safe to call multiple times; a call while
  /// already playing is ignored, so duplicate alerts for the same URL event
  /// are structurally impossible.
  Future<void> start({RiskLevel level = RiskLevel.malicious}) async {
    if (_isPlaying) return;
    _isPlaying = true;
    _remainingRepeats =
        level == RiskLevel.malicious ? _maliciousRepeats : 1;
    try {
      // Alarm audio usage: audible on the alarm stream (independent of media
      // volume) and naturally respected by the device's sound settings.
      await _player.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
          ),
        ),
      );
      // If stop() was called while we were initializing, abort so audio can
      // never start after the user (or dispose) silenced the alert.
      if (!_isPlaying) return;
      await _player.setReleaseMode(ReleaseMode.release);
      _completeSub ??=
          _player.onPlayerComplete.listen((_) => _playNextRepeat());
      await _playOnce();
    } catch (e) {
      debugPrint('SirenService: unable to play alert sound: $e');
      _isPlaying = false;
    }
  }

  /// Plays the asset exactly once; when it completes, [onPlayerComplete]
  /// schedules the next repeat until the bounded count is exhausted.
  Future<void> _playOnce() async {
    await _player.play(AssetSource(_asset));
  }

  Future<void> _playNextRepeat() async {
    if (!_isPlaying) return;
    if (_remainingRepeats > 1) {
      _remainingRepeats--;
      try {
        await _playOnce();
      } catch (e) {
        debugPrint('SirenService: repeat playback failed: $e');
        _isPlaying = false;
      }
    } else {
      // Bounded alarm finished on its own — no endless loop.
      _isPlaying = false;
    }
  }

  /// Stops the siren immediately and resets state so the next alert starts
  /// cleanly. No-ops (without touching the player) when nothing is playing —
  /// keeps "stop before every scan" free of plugin round trips. Errors are
  /// swallowed so a missing/broken audio asset never breaks the scan flow.
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _remainingRepeats = 0;
    try {
      await _completeSub?.cancel();
    } catch (_) {}
    _completeSub = null;
    try {
      await _player.stop();
      await _player.release();
    } catch (e) {
      debugPrint('SirenService: unable to stop alert sound: $e');
    }
  }
}
