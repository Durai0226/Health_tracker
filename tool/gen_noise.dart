// Generates the white / pink / brown noise loops shipped in assets/audio/.
//
//   dart run tool/gen_noise.dart
//
// Why generate rather than source these three:
//
//  * They are pure DSP, so there is nothing to licence, nothing to attribute, and
//    no CDN to depend on. The other twelve ambient sounds are field recordings and
//    genuinely have to be downloaded (see docs/audio-sourcing.md).
//  * The old catalogue pointed `whiteNoise` and `pinkNoise` at the *same URL*,
//    which is the clearest possible sign nobody had listened to it. Generating
//    them makes each one correct by construction.
//  * Noise is the one content type where a lossy codec is actively harmful — MP3
//    and AAC psychoacoustic models discard "inaudible" detail, which is precisely
//    what broadband noise is made of. These ship as 16-bit PCM.
//
// Deterministic: the PRNG is seeded, so re-running this produces byte-identical
// files. An asset that changes every build is an asset nobody can review.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int kSampleRate = 44100;
const int kSeconds = 20;
const int kCrossfadeMs = 400;

/// Peak amplitude, ~-6 dBFS. Deliberately not 1.0: these are background sounds
/// that get mixed under a user's own volume setting, and a hot master leaves them
/// no headroom to sit quietly.
const double kPeak = 0.5;

void main() {
  final dir = Directory('assets/audio');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  _write('${dir.path}/white_noise.wav', _white());
  _write('${dir.path}/pink_noise.wav', _pink());
  _write('${dir.path}/brown_noise.wav', _brown());

  stdout.writeln('\nRun `flutter test test/features/focus/focus_guards_test.dart` '
      'to see which assets are still missing.');
}

/// Flat spectral density — equal energy per hertz.
List<double> _white() {
  final rng = Random(20260318);
  return _loopable((n) => List<double>.generate(n, (_) => rng.nextDouble() * 2 - 1));
}

/// -3 dB per octave. Paul Kellet's economical filter — the standard cheap
/// approximation, and inaudibly close to true pink for ambient use.
List<double> _pink() {
  final rng = Random(20260319);
  return _loopable((n) {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;
    return List<double>.generate(n, (_) {
      final w = rng.nextDouble() * 2 - 1;
      b0 = 0.99886 * b0 + w * 0.0555179;
      b1 = 0.99332 * b1 + w * 0.0750759;
      b2 = 0.96900 * b2 + w * 0.1538520;
      b3 = 0.86650 * b3 + w * 0.3104856;
      b4 = 0.55000 * b4 + w * 0.5329522;
      b5 = -0.7616 * b5 - w * 0.0168980;
      final out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362;
      b6 = w * 0.115926;
      return out;
    });
  });
}

/// -6 dB per octave. A LEAKY integrator, not a plain one: plain integration of
/// white noise random-walks away from zero and the file drifts into DC offset,
/// which sounds like a thump and wastes headroom.
List<double> _brown() {
  final rng = Random(20260320);
  return _loopable((n) {
    var last = 0.0;
    return List<double>.generate(n, (_) {
      final w = rng.nextDouble() * 2 - 1;
      last = (last + 0.02 * w) * 0.998;
      return last;
    });
  });
}

/// Build [kSeconds] of audio whose end joins its start seamlessly.
///
/// Generates a crossfade's worth of extra samples, then mixes the tail back over
/// the head. Without this the loop point is a discontinuity — and while broadband
/// noise hides a hard cut better than melodic material does, the click is still
/// there on headphones, which is where these are actually used.
List<double> _loopable(List<double> Function(int n) generate) {
  final n = kSampleRate * kSeconds;
  final f = (kSampleRate * kCrossfadeMs / 1000).round();
  final raw = generate(n + f);

  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    if (i < f) {
      final t = i / f; // 0 → 1 across the crossfade
      out[i] = raw[i] * t + raw[n + i] * (1 - t);
    } else {
      out[i] = raw[i];
    }
  }
  return _normalise(out);
}

List<double> _normalise(List<double> samples) {
  var peak = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  if (peak == 0) return samples;
  final gain = kPeak / peak;
  return samples.map((s) => s * gain).toList();
}

void _write(String path, List<double> samples) {
  final bytes = _wav(samples);
  File(path).writeAsBytesSync(bytes);
  final kb = (bytes.length / 1024).round();
  stdout.writeln('✓ $path  ${kSeconds}s mono 16-bit  ${kb}KB');
}

/// Minimal 16-bit mono PCM WAV.
Uint8List _wav(List<double> samples) {
  const bitsPerSample = 16;
  const channels = 1;
  final dataBytes = samples.length * 2;
  final out = ByteData(44 + dataBytes);

  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // fmt chunk size
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, kSampleRate, Endian.little);
  out.setUint32(28, kSampleRate * channels * bitsPerSample ~/ 8, Endian.little);
  out.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
  out.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    out.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}
