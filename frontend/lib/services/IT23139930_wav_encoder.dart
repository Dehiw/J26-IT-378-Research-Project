import 'dart:typed_data';

/// Wraps raw 16-bit little-endian PCM in a WAV (RIFF) container.
/// Pure Dart: no file access, so it works the same on every platform.
class WavEncoder {
  WavEncoder._();

  /// Size of the header written by [encodePcm16].
  static const int headerSize = 44;

  /// Returns a complete WAV file for [pcm16], which must hold 16-bit samples
  /// (an even number of bytes) for [channels] interleaved channels.
  static Uint8List encodePcm16({
    required Uint8List pcm16,
    required int sampleRate,
    required int channels,
  }) {
    if (pcm16.length.isOdd) {
      throw ArgumentError.value(
        pcm16.length,
        'pcm16',
        'PCM 16-bit data must have an even number of bytes',
      );
    }
    if (sampleRate <= 0 || channels <= 0) {
      throw ArgumentError('sampleRate and channels must be positive');
    }

    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    final blockAlign = channels * bytesPerSample;
    final byteRate = sampleRate * blockAlign;
    final dataSize = pcm16.length;

    final bytes = Uint8List(headerSize + dataSize);
    final view = ByteData.sublistView(bytes);

    // RIFF chunk descriptor
    _writeAscii(bytes, 0, 'RIFF');
    view.setUint32(4, 36 + dataSize, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');

    // "fmt " sub-chunk (PCM)
    _writeAscii(bytes, 12, 'fmt ');
    view.setUint32(16, 16, Endian.little); // sub-chunk size
    view.setUint16(20, 1, Endian.little); // audio format: PCM
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);

    // "data" sub-chunk
    _writeAscii(bytes, 36, 'data');
    view.setUint32(40, dataSize, Endian.little);

    bytes.setRange(headerSize, headerSize + dataSize, pcm16);
    return bytes;
  }

  /// Length of audio in [pcm16], in seconds.
  static double durationSeconds({
    required int pcm16Length,
    required int sampleRate,
    required int channels,
  }) {
    const bytesPerSample = 2;
    return pcm16Length / (sampleRate * channels * bytesPerSample);
  }

  static void _writeAscii(Uint8List bytes, int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes[offset + i] = text.codeUnitAt(i);
    }
  }
}
