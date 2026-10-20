import 'package:intl/intl.dart';

import 'package:frontend/utils/IT23139930_acoustic_strings.dart';

/// Date and time text for the acoustic screens.
class AcousticFormat {
  AcousticFormat._();

  /// "Today", "Yesterday", or a short date such as "12 Oct".
  static String dayLabel(DateTime recordedAt, DateTime now) {
    final day = DateTime(recordedAt.year, recordedAt.month, recordedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysAgo = today.difference(day).inDays;
    if (daysAgo == 0) return AcousticStrings.today;
    if (daysAgo == 1) return AcousticStrings.yesterday;
    return DateFormat('d MMM').format(recordedAt);
  }

  /// The one date and time format for every acoustic screen, so times read
  /// the same everywhere: "Today, 09:20 AM", "12 Oct, 06:15 PM".
  static String dayAndTime(DateTime recordedAt, DateTime now) =>
      '${dayLabel(recordedAt, now)}, ${DateFormat('hh:mm a').format(recordedAt)}';

  /// "00:18", for the recording timer. Minutes and seconds only.
  static String clock(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
