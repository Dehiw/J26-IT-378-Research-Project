import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/acoustic/acoustic_config.dart';
import 'package:frontend/acoustic/models/abnormal_trend.dart';
import 'package:frontend/acoustic/models/acoustic_result.dart';

/// Fixed "now" so the tests do not depend on the clock or the time of day.
final DateTime now = DateTime(2026, 10, 18, 15, 30);

AcousticResult result(
  AcousticLabel label, {
  int daysAgo = 0,
  int hour = 12,
  String hiveId = 'H-001',
  double confidence = 0.9,
  AudioQuality quality = AudioQuality.good,
}) {
  return AcousticResult(
    id: '$label-$daysAgo-$hiveId-$hour',
    hiveId: hiveId,
    label: label,
    confidence: confidence,
    recordedAt: DateTime(now.year, now.month, now.day - daysAgo, hour),
    audioQuality: quality,
    modelVersion: 'test',
  );
}

AbnormalTrend trend(List<AcousticResult> results, {String hiveId = 'H-001'}) {
  return AbnormalTrend.from(results: results, hiveId: hiveId, now: now);
}

void main() {
  test('the window is 7 days by config, oldest first, ending today', () {
    expect(AcousticConfig.trendWindowDays, 7);

    final t = trend([]);
    expect(t.counts.length, 7);
    expect(t.days.length, 7);
    expect(t.days.first, DateTime(2026, 10, 12));
    expect(t.days.last, DateTime(2026, 10, 18));
  });

  test('counts Queenless, Swarming and Abnormal results per day', () {
    final t = trend([
      result(AcousticLabel.swarming),
      result(AcousticLabel.swarming, hour: 20),
      result(AcousticLabel.queenless, daysAgo: 2),
      result(AcousticLabel.stressAbnormal, daysAgo: 6),
    ]);

    expect(t.counts, [1, 0, 0, 0, 1, 0, 2]);
  });

  test('Normal and Unclear results do not count', () {
    final t = trend([
      result(AcousticLabel.normal),
      // Poor audio is shown as Unclear, even with an abnormal label.
      result(AcousticLabel.swarming, quality: AudioQuality.poor),
      // Low confidence is shown as Unclear too.
      result(AcousticLabel.queenless, confidence: 0.4),
    ]);

    expect(t.counts.every((c) => c == 0), isTrue);
    expect(t.isEmpty, isTrue);
  });

  test('results older than the window are not counted', () {
    final t = trend([
      result(AcousticLabel.swarming, daysAgo: 6),
      result(AcousticLabel.swarming, daysAgo: 7),
      result(AcousticLabel.swarming, daysAgo: 30),
    ]);

    // The list is oldest first, so 6 days ago is index 0.
    expect(t.counts, [1, 0, 0, 0, 0, 0, 0], reason: 'only 6 days ago counts');
  });

  test('a result late on the oldest day and early on today count on those '
      'days, using calendar days', () {
    final t = trend([
      result(AcousticLabel.swarming, daysAgo: 6, hour: 23),
      result(AcousticLabel.queenless, hour: 0),
    ]);

    expect(t.counts.first, 1);
    expect(t.counts.last, 1);
  });

  test('results from other hives are not counted', () {
    final t = trend([
      result(AcousticLabel.swarming, hiveId: 'H-002'),
      result(AcousticLabel.queenless, hiveId: 'H-002', daysAgo: 1),
      result(AcousticLabel.swarming),
    ]);

    expect(t.counts, [0, 0, 0, 0, 0, 0, 1]);
  });

  test('results dated after today are not counted', () {
    final t = trend([result(AcousticLabel.swarming, daysAgo: -1)]);

    expect(t.counts.every((c) => c == 0), isTrue);
  });

  test('the window length can be changed for other callers', () {
    final t = AbnormalTrend.from(
      results: [result(AcousticLabel.swarming, daysAgo: 2)],
      hiveId: 'H-001',
      now: now,
      windowDays: 3,
    );

    expect(t.counts, [1, 0, 0]);
  });
}
