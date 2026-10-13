import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum VoiceState { idle, recording, uploading, confirming, failed }
class VoiceRecorderController extends ChangeNotifier {
  final AudioRecorder _recorder;
  VoiceState state = VoiceState.idle;
  String? path;
  Timer? _limit;
  VoiceRecorderController({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) { state = VoiceState.failed; notifyListeners(); return false; }
    final dir = await getTemporaryDirectory();
    path = '${dir.path}/xiaojia_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path!,
    );
    state = VoiceState.recording; notifyListeners();
    _limit = Timer(const Duration(seconds: 45), stop);
    return true;
  }
  Future<String?> stop() async { _limit?.cancel(); if (state != VoiceState.recording) return path; path = await _recorder.stop(); state = VoiceState.uploading; notifyListeners(); return path; }
  void confirm() { state = VoiceState.confirming; notifyListeners(); }
  Future<void> cancel() async { _limit?.cancel(); await _recorder.stop(); state = VoiceState.idle; notifyListeners(); }
  @override void dispose() { _limit?.cancel(); _recorder.dispose(); super.dispose(); }
}
