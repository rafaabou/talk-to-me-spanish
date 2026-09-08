// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

html.AudioElement? _currentAudio;

Future<bool> playAssetBytes(
  Uint8List bytes,
  String mimeType,
  double speed,
  int repeat,
) async {
  try {
    await stopWebAudio();

    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    for (var i = 0; i < repeat; i++) {
      final audio =
          html.AudioElement()
            ..src = url
            ..playbackRate = speed;
      _currentAudio = audio;
      audio.play();
      await audio.onEnded.first;
    }
    html.Url.revokeObjectUrl(url);
    _currentAudio = null;
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> playAssetUrl(String assetUrl, double speed, int repeat) async {
  try {
    await stopWebAudio();

    for (var i = 0; i < repeat; i++) {
      final audio =
          html.AudioElement()
            ..src = assetUrl
            ..playbackRate = speed;
      _currentAudio = audio;
      audio.play();
      await audio.onEnded.first;
    }
    _currentAudio = null;
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> stopWebAudio() async {
  try {
    final audio = _currentAudio;
    if (audio != null) {
      audio.pause();
      audio.src = '';
    }
    _currentAudio = null;
  } catch (_) {}
}
