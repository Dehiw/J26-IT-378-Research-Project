import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/acoustic/services/wav_encoder.dart';

void main() {
  group('WavEncoder.encodePcm16', () {
    test('writes a 44-byte header followed by the PCM data', () {
      final pcm = Uint8List.fromList(List<int>.generate(320, (i) => i % 256));

      final wav = WavEncoder.encodePcm16(
        pcm16: pcm,
        sampleRate: 16000,
        channels: 1,
      );

      expect(WavEncoder.headerSize, 44);
      expect(wav.length, 44 + pcm.length);
      expect(wav.sublist(44), pcm);
    });

    test('writes the RIFF/WAVE/fmt/data chunk tags', () {
      final wav = WavEncoder.encodePcm16(
        pcm16: Uint8List(8),
        sampleRate: 16000,
        channels: 1,
      );

      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    });

    test('writes the format fields for 16 kHz mono 16-bit PCM', () {
      final wav = WavEncoder.encodePcm16(
        pcm16: Uint8List(1000),
        sampleRate: 16000,
        channels: 1,
      );
      final view = ByteData.sublistView(wav);

      expect(view.getUint32(16, Endian.little), 16, reason: 'fmt size');
      expect(view.getUint16(20, Endian.little), 1, reason: 'PCM format');
      expect(view.getUint16(22, Endian.little), 1, reason: 'channels');
      expect(view.getUint32(24, Endian.little), 16000, reason: 'sample rate');
      expect(view.getUint32(28, Endian.little), 32000, reason: 'byte rate');
      expect(view.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(view.getUint16(34, Endian.little), 16, reason: 'bits/sample');
    });

    test('writes stereo byte rate and block align when channels is 2', () {
      final wav = WavEncoder.encodePcm16(
        pcm16: Uint8List(400),
        sampleRate: 44100,
        channels: 2,
      );
      final view = ByteData.sublistView(wav);

      expect(view.getUint16(22, Endian.little), 2);
      expect(view.getUint32(28, Endian.little), 44100 * 4);
      expect(view.getUint16(32, Endian.little), 4);
    });

    test('writes the RIFF size and data size from the payload length', () {
      const dataLength = 3200;
      final wav = WavEncoder.encodePcm16(
        pcm16: Uint8List(dataLength),
        sampleRate: 16000,
        channels: 1,
      );
      final view = ByteData.sublistView(wav);

      // RIFF size counts everything after the first 8 bytes.
      expect(view.getUint32(4, Endian.little), 36 + dataLength);
      expect(view.getUint32(40, Endian.little), dataLength);
      expect(wav.length, 8 + view.getUint32(4, Endian.little));
    });

    test('rejects an odd number of PCM bytes', () {
      expect(
        () => WavEncoder.encodePcm16(
          pcm16: Uint8List(3),
          sampleRate: 16000,
          channels: 1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive sample rate or channel count', () {
      expect(
        () => WavEncoder.encodePcm16(
          pcm16: Uint8List(4),
          sampleRate: 0,
          channels: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => WavEncoder.encodePcm16(
          pcm16: Uint8List(4),
          sampleRate: 16000,
          channels: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('WavEncoder.durationSeconds', () {
    test('computes length from byte count, rate and channels', () {
      // 3 seconds of 16 kHz mono 16-bit PCM = 96000 bytes.
      expect(
        WavEncoder.durationSeconds(
          pcm16Length: 96000,
          sampleRate: 16000,
          channels: 1,
        ),
        closeTo(3.0, 1e-9),
      );
    });
  });
}
