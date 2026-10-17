import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/acoustic/services/audio_upload.dart';

PickedAudio file(String name, {int bytes = 100}) =>
    PickedAudio(filename: name, bytes: Uint8List(bytes));

void main() {
  group('AudioUploadValidator.check', () {
    test('accepts WAV and MP3, in any letter case', () {
      expect(AudioUploadValidator.check(file('hive.wav')), isNull);
      expect(AudioUploadValidator.check(file('hive.mp3')), isNull);
      expect(AudioUploadValidator.check(file('HIVE.WAV')), isNull);
      expect(AudioUploadValidator.check(file('Hive.Mp3')), isNull);
    });

    test('rejects other types, including names that only look like audio', () {
      expect(
        AudioUploadValidator.check(file('notes.txt')),
        AudioUploadProblem.unsupportedType,
      );
      expect(
        AudioUploadValidator.check(file('clip.m4a')),
        AudioUploadProblem.unsupportedType,
      );
      expect(
        AudioUploadValidator.check(file('wav')),
        AudioUploadProblem.unsupportedType,
      );
      expect(
        AudioUploadValidator.check(file('hive.wav.exe')),
        AudioUploadProblem.unsupportedType,
      );
      expect(
        AudioUploadValidator.check(file('hive.')),
        AudioUploadProblem.unsupportedType,
      );
    });

    test('rejects an empty file', () {
      expect(
        AudioUploadValidator.check(file('hive.wav', bytes: 0)),
        AudioUploadProblem.empty,
      );
    });

    test(
      'accepts a file exactly at the size limit and rejects one over it',
      () {
        const limit = 1000;
        expect(
          AudioUploadValidator.check(
            file('a.wav', bytes: limit),
            maxBytes: limit,
          ),
          isNull,
        );
        expect(
          AudioUploadValidator.check(
            file('a.wav', bytes: limit + 1),
            maxBytes: limit,
          ),
          AudioUploadProblem.tooLarge,
        );
      },
    );

    test('checks the type before the size', () {
      expect(
        AudioUploadValidator.check(
          file('a.txt', bytes: 99999999),
          maxBytes: 10,
        ),
        AudioUploadProblem.unsupportedType,
      );
    });
  });

  test('messages name the limit in megabytes', () {
    expect(
      AudioUploadValidator.message(
        AudioUploadProblem.tooLarge,
        maxBytes: 10 * 1024 * 1024,
      ),
      contains('10 MB'),
    );
  });
}
