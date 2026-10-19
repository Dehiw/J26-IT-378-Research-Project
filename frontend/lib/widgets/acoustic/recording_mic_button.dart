import 'package:flutter/material.dart';

import 'package:frontend/utils/theme.dart';
import 'package:frontend/utils/acoustic/acoustic_strings.dart';

/// Large round microphone button with a glow ring. The ring is brighter
/// while recording. A null [onPressed] shows the button as unavailable.
class RecordingMicButton extends StatelessWidget {
  const RecordingMicButton({
    super.key,
    required this.recording,
    this.onPressed,
    this.size = 140,
  });

  final bool recording;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glowAlpha = recording ? 0.35 : 0.14;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: recording
          ? AcousticStrings.stopRecording
          : AcousticStrings.startRecording,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size * 1.6,
            height: size * 1.6,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: glowAlpha * 0.5),
            ),
            child: Container(
              width: size * 1.3,
              height: size * 1.3,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: glowAlpha),
              ),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
                child: Icon(
                  Icons.mic,
                  size: size * 0.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
