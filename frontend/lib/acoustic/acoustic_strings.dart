import 'models/acoustic_result.dart';

/// All user-facing copy for the acoustic module. English only for now; keep
/// new strings here so they can be localized later.
class AcousticStrings {
  AcousticStrings._();

  // Shared
  static const String appBarMonitorTitle = 'Hive Sound Monitor';
  static const String guidanceNote =
      'This result is guidance only and does not replace a hive inspection.';
  static const String confidenceLabel = 'AI confidence';
  static const String whatThisMeans = 'What this means';

  // Monitor / history
  static const String recordHiveSound = 'Record Hive Sound';
  static const String uploadAudio = 'Upload Audio';
  static const String recentAnalyses = 'Recent analyses';
  static const String latestSoundStatus = 'Latest sound status';

  // Recording / result
  static const String saveResult = 'Save Result';
  static const String recordAgain = 'Record Again';

  // Errors (generic; screen-specific messages are added with each stage)
  static const String genericError = 'Something went wrong. Please try again.';
  static const String emptyRecording = 'The recording is empty.';

  /// Short state name shown on chips and titles.
  static String labelTitle(AcousticLabel label) => switch (label) {
        AcousticLabel.normal => 'Normal Activity',
        AcousticLabel.queenless => 'Queenless Pattern',
        AcousticLabel.swarming => 'Swarming Pattern',
        AcousticLabel.stressAbnormal => 'Abnormal Activity',
        AcousticLabel.unclearRecording => 'Unclear Recording',
      };

  /// Guidance text for the "What this means" card.
  static String labelMeaning(AcousticLabel label) => switch (label) {
        AcousticLabel.normal =>
          'This sounds like a steady, active colony. '
              'Keep up your regular hive inspections.',
        AcousticLabel.queenless =>
          'This sound resembles patterns often heard in queenless colonies. '
              'Consider inspecting the hive to check for the queen.',
        AcousticLabel.swarming =>
          'This sound resembles patterns often heard before swarming. '
              'Consider inspecting the hive for signs such as queen cells.',
        AcousticLabel.stressAbnormal =>
          'An unusual hive sound was detected. Consider inspecting the hive.',
        AcousticLabel.unclearRecording =>
          "We couldn't get a clear reading. Try again closer to the hive "
              'entrance, away from wind, traffic and voices.',
      };

  // Monitor details
  static const String hiveSelectorTitle = 'Choose hive';
  static const String selectHive = 'Select Hive';
  static const String noHivesFound = 'No hives found.';
  static const String noAnalysesYet = 'No analyses yet';
  static const String noAnalysesForHive =
      'No recordings for this hive yet. Record or upload audio to get started.';
  static const String loadingHiveSounds = 'Loading hive sounds…';
  static const String loadFailed = "Couldn't load hive sounds.";
  static const String retry = 'Retry';
  static const String soundHistoryTooltip = 'Sound history';
  static const String latestWaveform = 'Latest recording';
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';

  static String hiveName(String hiveId) => 'Hive $hiveId';

  static String percent(double confidence) =>
      '${(confidence.clamp(0.0, 1.0) * 100).round()}%';
}
