import '../acoustic_config.dart';
import 'acoustic_result.dart';

/// Abnormal results per day for one hive over the last
/// [AcousticConfig.trendWindowDays] days, counting today.
///
/// A result counts when its shown status (displayLabel) is abnormal. Normal
/// and unclear results do not count. Days are local calendar days.
class AbnormalTrend {
  const AbnormalTrend({required this.days, required this.counts});

  /// Statuses that count as abnormal.
  static const Set<AcousticLabel> abnormalLabels = {
    AcousticLabel.queenless,
    AcousticLabel.swarming,
    AcousticLabel.stressAbnormal,
  };

  /// Local midnight of each day in the window, oldest first.
  final List<DateTime> days;

  /// Abnormal results on each day, in the same order as [days].
  final List<int> counts;

  /// True when no day in the window has an abnormal result.
  bool get isEmpty => counts.every((count) => count == 0);

  /// Counts [results] for [hiveId] over the window ending at [now].
  /// Results from other hives, from before the window, or dated after
  /// [now] are ignored.
  factory AbnormalTrend.from({
    required Iterable<AcousticResult> results,
    required String hiveId,
    required DateTime now,
    int windowDays = AcousticConfig.trendWindowDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var ago = windowDays - 1; ago >= 0; ago--)
        DateTime(today.year, today.month, today.day - ago),
    ];
    final counts = List<int>.filled(windowDays, 0);

    for (final result in results) {
      if (result.hiveId != hiveId) continue;
      if (!abnormalLabels.contains(result.displayLabel)) continue;

      final recorded = result.recordedAt;
      // Whole calendar days, computed in UTC so daylight saving changes do
      // not shift a result into the wrong day.
      final ago = DateTime.utc(today.year, today.month, today.day)
          .difference(DateTime.utc(recorded.year, recorded.month, recorded.day))
          .inDays;
      if (ago < 0 || ago >= windowDays) continue;

      counts[windowDays - 1 - ago]++;
    }

    return AbnormalTrend(days: days, counts: counts);
  }
}
