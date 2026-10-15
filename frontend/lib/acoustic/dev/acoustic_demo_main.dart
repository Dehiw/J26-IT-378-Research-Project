import 'package:flutter/material.dart';

import '../../utils/theme.dart';
import '../screens/hive_sound_monitor_screen.dart';

/// Stand-alone preview of the acoustic module on mock data. Used only for
/// development; the app itself is not changed.
///
/// Run with: flutter run -t lib/acoustic/dev/acoustic_demo_main.dart
void main() {
  runApp(
    MaterialApp(
      title: 'Hive Sense: Acoustic demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HiveSoundMonitorScreen(),
    ),
  );
}
