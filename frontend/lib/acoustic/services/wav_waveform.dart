import 'dart:math' as math;
import 'dart:typed_data';

import 'signal_stats.dart';

/// Builds the Result screen's waveform preview from an uploaded WAV file.
/// Pure Dart, no packages. Only 16-bit PCM WAV is decoded; MP3 and other
/// formats return null and show no preview.
class WavWaveform {
  WavWaveform._();

  /// Bars in the preview. Fixed, so a long upload still fits the card.
  static const int defaultBars = 80;

  /// Returns normalised 0-1 bars, one per bucket of audio, or null when
  /// [bytes] is not 16-bit PCM WAV. Bar height uses the same mapping as the
  /// live recording (-60 dBFS to 0, 0 dBFS to 1).
  static List<double>? decode(Uint8List bytes, {int bars = defaultBars}) {
    if (bytes.length < 12 ||
        _ascii(bytes, 0) != 'RIFF' ||
        _ascii(bytes, 8) != 'WAVE') {
      return null;
    }
    final view = ByteData.sublistView(bytes);

    int? channels;
    int? bitsPerSample;
    int? formatTag;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _ascii(bytes, offset);
      final size = view.getUint32(offset + 4, Endian.little);
      final body = offset + 8;

      if (id == 'fmt ' && body + 16 <= bytes.length) {
        formatTag = view.getUint16(body, Endian.little);
        channels = view.getUint16(body + 2, Endian.little);
        bitsPerSample = view.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        // PCM, or WAVE_FORMAT_EXTENSIBLE which may still hold 16-bit PCM.
        final isPcm = formatTag == 1 || formatTag == 0xFFFE;
        if (!isPcm || bitsPerSample != 16 || channels == null) return null;
        if (channels < 1) return null;
        final end = math.min(body + size, bytes.length);
        return _bars(bytes.sublist(body, end), channels, bars);
      }

      // Chunks are word-aligned: an odd size has one padding byte.
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  static List<double> _bars(Uint8List data, int channels, int bars) {
    final blockAlign = channels * 2;
    final frames = data.length ~/ blockAlign;
    if (frames == 0 || bars <= 0) return const [];

    final result = <double>[];
    for (var i = 0; i < bars; i++) {
      final from = (i * frames ~/ bars) * blockAlign;
      final to = ((i + 1) * frames ~/ bars) * blockAlign;
      if (to <= from) {
        result.add(0);
        continue;
      }
      final stats = SignalStats.fromPcm16(data.sublist(from, to));
      result.add(_barHeight(stats.rmsDb));
    }
    return result;
  }

  static double _barHeight(double db) => ((db + 60) / 60).clamp(0.0, 1.0);

  static String _ascii(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
}
