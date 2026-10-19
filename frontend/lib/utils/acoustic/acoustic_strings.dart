import 'package:frontend/models/acoustic/acoustic_result.dart';

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

  // Recording screen
  static const String recordingTitle = 'Recording';
  static const String tapToStart = 'Tap the microphone to start recording.';
  static const String recordingHelper =
      'Hold the phone near the hive entrance, away from wind and voices.';
  static const String startRecording = 'Start Recording';
  static const String stopRecording = 'Stop Recording';
  static const String cancelRecording = 'Cancel';
  static const String analyzingHiveSound = 'Analyzing hive sound...';
  static const String qualityLabel = 'Audio quality';
  static const String qualityGood = 'Good';
  static const String qualityFair = 'Fair';
  static const String qualityPoor = 'Poor';

  static String recordingLengthHint(int seconds) =>
      'Recording stops automatically after $seconds seconds.';

  // Microphone permission
  static const String micPermissionTitle = 'Microphone access needed';
  static const String micPermissionDeniedAndroid =
      'Hive Sense needs the microphone to record hive sound. Allow access '
      'when asked, then try again. If no prompt appears, open '
      'Settings > Apps > Hive Sense > Permissions > Microphone and allow it, '
      'then come back here.';
  static const String micPermissionBlockedWindows =
      'Microphone access is turned off for desktop apps. Open Settings, '
      'go to Privacy & security > Microphone, turn on "Microphone access" '
      'and "Let desktop apps access your microphone", then try again.';
  static const String tryAgain = 'Try Again';

  // No sound / silent audio
  static const String soundMissingWindows =
      'No sound detected. Your microphone may be blocked. Check Windows '
      'Settings > Privacy & security > Microphone.';
  static const String soundMissingAndroid =
      'No sound detected. Your microphone may be blocked. Check Settings > '
      'Apps > Hive Sense > Permissions > Microphone.';
  static const String noAudioCaptured = 'No audio was captured.';

  /// Platform-specific hint for a microphone that delivers no sound.
  static String soundMissingText({required bool android}) =>
      android ? soundMissingAndroid : soundMissingWindows;

  // Recording failures
  static const String noMicrophone =
      'No microphone was found. Connect a microphone and try again.';
  static const String recordingFailed =
      "The recording couldn't be completed. Please try again.";
  static const String recordingTooShort =
      'That recording was under 3 seconds. Record for at least 3 seconds, '
      'close to the hive entrance.';
  static const String analysisFailed =
      "We couldn't analyze this recording. Please try again.";

  // Upload
  static const String uploadPickFailed =
      "Couldn't open the file. Please try again.";
  static const String uploadUnsupportedType =
      'Only WAV or MP3 files can be uploaded.';
  static const String uploadEmpty = 'This file is empty. Choose another file.';
  static String uploadTooLarge(int megabytes) =>
      'This file is larger than $megabytes MB. Choose a shorter recording.';

  // Result
  static const String analysisResultTitle = 'Analysis Result';
  static const String saveFailed =
      "The result couldn't be saved. Please try again.";
  static const String savingResult = 'Saving...';
  static const String unclearTipsTitle = 'Tips for a clearer recording';
  static const List<String> unclearTips = [
    'Hold the phone close to the hive entrance.',
    'Avoid wind, traffic and voices nearby.',
    'Try again in a quieter moment.',
  ];

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

  // Sound history
  static const String soundHistoryTitle = 'Sound History';
  static const String recentRecordings = 'Recent recordings';
  static const String historyLoading = 'Loading sound history…';
  static const String historyLoadFailed = "Couldn't load sound history.";
  static const String filterTooltip = 'Filter by status';
  static const String filterTitle = 'Filter by status';
  static const String filterAll = 'All';
  static const String showAll = 'Show all';
  static const String noSavedAnalysesForHive =
      'No saved analyses for this hive yet';
  static const String noMatchingAnalyses =
      'No saved analyses match this filter.';

  static const String noAbnormalThisWeek = 'No abnormal results this week';

  // Demo notice, shown while the mock service is in use
  static const String demoNotice = 'Demo analysis, not a real AI result';

  static String showingFilter(String label) => 'Showing: $label';

  static String abnormalTrendTitle(int days) =>
      'Abnormal results, last $days days';

  static String hiveName(String hiveId) => 'Hive $hiveId';

  static String percent(double confidence) =>
      '${(confidence.clamp(0.0, 1.0) * 100).round()}%';
}
