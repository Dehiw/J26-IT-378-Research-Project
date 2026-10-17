import 'package:frontend/acoustic/services/audio_upload.dart';

/// Test double for [AudioFilePicker]. [next] is what the next pick returns
/// (null simulates the user cancelling).
class FakeAudioFilePicker implements AudioFilePicker {
  FakeAudioFilePicker({this.next});

  PickedAudio? next;
  int pickCount = 0;

  @override
  Future<PickedAudio?> pick() async {
    pickCount++;
    return next;
  }
}
