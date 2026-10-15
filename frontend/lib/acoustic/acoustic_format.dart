import 'package:intl/intl.dart';

import 'acoustic_strings.dart';

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

  /// "Today, 09:20 AM"
  static String dayAndTime(DateTime recordedAt, DateTime now) =>
      '${dayLabel(recordedAt, now)}, ${DateFormat('hh:mm a').format(recordedAt)}';
}
