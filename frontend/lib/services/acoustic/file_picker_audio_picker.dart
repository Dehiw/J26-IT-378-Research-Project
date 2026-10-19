import 'package:file_picker/file_picker.dart';

import 'package:frontend/utils/acoustic/acoustic_config.dart';
import 'package:frontend/services/acoustic/audio_upload.dart';

/// Opens the system file picker for WAV and MP3 files and reads the chosen
/// file as bytes. Uses no dart:io, so it works on every platform file_picker
/// supports. Size and type checks happen in [AudioUploadValidator].
class FilePickerAudioPicker implements AudioFilePicker {
  const FilePickerAudioPicker();

  @override
  Future<PickedAudio?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AcousticConfig.allowedUploadExtensions,
    );
    if (files.isEmpty) return null;

    final file = files.first;
    final bytes = await file.readAsBytes();
    return PickedAudio(filename: file.name, bytes: bytes);
  }
}
