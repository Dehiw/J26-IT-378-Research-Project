import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/acoustic/wav_encoder.dart';
import 'package:frontend/services/acoustic/wav_waveform.dart';

import '../../support/acoustic/pcm_signal.dart';

Uint8List wavOf(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  return WavEncoder.encodePcm16(
    pcm16: pcm,
    sampleRate: sampleRate,
    channels: channels,
  );
}

void main() {
  test('a 16-bit WAV gives one bar per bucket, all within 0-1', () {
    final wav = wavOf(sine(seconds: 2, sampleRate: 16000, amplitude: 0.3));
    final bars = WavWaveform.decode(wav);

    expect(bars, isNotNull);
    expect(bars!.length, WavWaveform.defaultBars);
    expect(bars.every((b) => b >= 0 && b <= 1), isTrue);
    expect(bars.any((b) => b > 0.5), isTrue, reason: 'a 0.3 tone is audible');
  });

  test('silence gives flat bars at zero', () {
    final wav = wavOf(silence(seconds: 1, sampleRate: 16000));
    final bars = WavWaveform.decode(wav, bars: 10);

    expect(bars, everyElement(0));
  });

  test('a loud half and a quiet half show the difference', () {
    final loud = sine(seconds: 1, sampleRate: 16000, amplitude: 0.5);
    final quiet = sine(seconds: 1, sampleRate: 16000, amplitude: 0.005);
    final wav = wavOf(Uint8List.fromList([...loud, ...quiet]));
    final bars = WavWaveform.decode(wav, bars: 4)!;

    expect(bars[0], greaterThan(bars[3]));
  });

  test('MP3 and other non-WAV bytes give no waveform', () {
    final mp3Like = Uint8List.fromList([
      0x49,
      0x44,
      0x33,
      0x03,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
    expect(WavWaveform.decode(mp3Like), isNull);
    expect(WavWaveform.decode(Uint8List(0)), isNull);
  });

  test('8-bit WAV gives no waveform', () {
    final wav = wavOf(sine(seconds: 1, sampleRate: 16000));
    ByteData.sublistView(wav).setUint16(34, 8, Endian.little);

    expect(WavWaveform.decode(wav), isNull);
  });

  test('a WAV with no audio gives an empty waveform', () {
    final wav = wavOf(Uint8List(0));
    expect(WavWaveform.decode(wav), isEmpty);
  });
}
