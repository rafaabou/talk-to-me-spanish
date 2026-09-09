// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

html.AudioElement? _currentAudio;

/// Plays [url] once. Completes with true when playback ends,
/// false on error or timeout. Never throws.
Future<bool> _playOnce(String url, double speed) async {
  final audio =
      html.AudioElement()
        ..src = url
        ..preload = 'auto'
        ..playbackRate = speed;
  _currentAudio = audio;

  final completer = Completer<bool>();
  final endedSub = audio.onEnded.listen((_) {
    if (!completer.isCompleted) completer.complete(true);
  });
  final errorSub = audio.onError.listen((_) {
    if (!completer.isCompleted) completer.complete(false);
  });
  try {
    audio.load();
    audio.play();
    return await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
  } catch (_) {
    return false;
  } finally {
    await endedSub.cancel();
    await errorSub.cancel();
  }
}

Future<bool> playAssetBytes(
  Uint8List bytes,
  String mimeType,
  double speed,
  int repeat,
) async {
  String? url;
  try {
    await stopWebAudio();

    final blob = html.Blob([bytes], mimeType);
    url = html.Url.createObjectUrlFromBlob(blob);

    var ok = true;
    for (var i = 0; i < repeat && ok; i++) {
      ok = await _playOnce(url, speed);
    }
    _currentAudio = null;
    return ok;
  } catch (_) {
    return false;
  } finally {
    if (url != null) {
      html.Url.revokeObjectUrl(url);
    }
  }
}

Future<bool> playAssetUrl(
  String assetUrl,
  double speed,
  int repeat,
) async {
  try {
    await stopWebAudio();

    var ok = true;
    for (var i = 0; i < repeat && ok; i++) {
      ok = await _playOnce(assetUrl, speed);
    }
    _currentAudio = null;
    return ok;
  } catch (_) {
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
