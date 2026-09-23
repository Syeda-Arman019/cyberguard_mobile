// Generates assets/sounds/siren_alert.wav — a loud, looping two-tone
// emergency siren used by Auto Protection when a risky URL is detected.
//
// Run from the project root:
//   dart run scripts/generate_siren.dart
//
// Pure Dart (no Flutter), so it works with `dart run` alone.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const int sampleRate = 22050;
  const int durationSec = 6;
  const int totalSamples = sampleRate * durationSec;

  // Two-tone "hi-lo" wail: 800 Hz for 0.55 s, then 550 Hz for 0.55 s.
  const double hiFreq = 800.0;
  const double loFreq = 550.0;
  const double toneSec = 0.55;
  final int toneSamples = (sampleRate * toneSec).round();
  // 5 ms fade in/out per tone removes clicks when the file loops.
  const int fadeSamples = 110;

  final samples = Float32List(totalSamples);
  for (int i = 0; i < totalSamples; i++) {
    final bool isHiTone = (i ~/ toneSamples).isEven;
    final double freq = isHiTone ? hiFreq : loFreq;
    final int posInTone = i % toneSamples;

    double envelope = 1.0;
    if (posInTone < fadeSamples) {
      envelope = posInTone / fadeSamples;
    } else if (posInTone > toneSamples - fadeSamples) {
      envelope = (toneSamples - posInTone) / fadeSamples;
    }

    final double t = i / sampleRate;
    samples[i] =
        (0.55 * math.sin(2 * math.pi * freq * t) +
            0.45 * math.sin(2 * math.pi * freq * 2 * t)) *
        envelope;
  }

  final bytes = BytesBuilder();
  final int dataLen = totalSamples * 2; // 16-bit mono
  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add([(v & 0xFF), (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void u16(int v) => bytes.add([v & 0xFF, (v >> 8) & 0xFF]);

  ascii('RIFF');
  u32(36 + dataLen);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(sampleRate);
  u32(sampleRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits per sample
  ascii('data');
  u32(dataLen);

  final pcm = ByteData(totalSamples * 2);
  for (int i = 0; i < totalSamples; i++) {
    final int v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    pcm.setInt16(i * 2, v, Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());

  final out = File('assets/sounds/siren_alert.wav');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes.takeBytes(), flush: true);

  stdout.writeln('Wrote ${out.path} (${out.lengthSync()} bytes)');
}
