import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a loud, looping siren whenever Auto Protection detects a risky URL.
///
/// The sound keeps repeating until [stop] is called (user acknowledges the
/// warning, leaves the screen, or a safe result replaces the risky one), so it
/// works as a clearly audible security alarm during a demo.
class SirenService {
  SirenService._private();
  static final SirenService instance = SirenService._private();

  static const String _asset = 'sounds/siren_alert.wav';

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// Whether the siren is currently sounding.
  bool get isPlaying => _isPlaying;

  /// Starts the looping siren. Safe to call multiple times; repeated calls
  /// while already playing are ignored. Playback errors are swallowed so a
  /// missing/broken audio asset never breaks the scan flow.
  Future<void> start() async {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      // Release any finished/previous session first.
      await _player.release();
      // If stop() was called while we were initializing, abort so audio can
      // never start after the user (or dispose) silenced the alert.
      if (!_isPlaying) return;
      // Low volume on the audio mix still respects the media stream, so the
      // alarm is audible at normal media volume on a physical device.
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(_asset));
    } catch (e) {
      debugPrint('SirenService: unable to play alert sound: $e');
      _isPlaying = false;
    }
  }

  /// Stops the siren and resets the player so the next alert starts cleanly.
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    try {
      await _player.stop();
      await _player.release();
    } catch (e) {
      debugPrint('SirenService: unable to stop alert sound: $e');
    }
  }
}
