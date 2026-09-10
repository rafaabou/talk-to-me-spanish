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

/// Sniffs the real container: some bundled .opus files are MP3 bytes.
/// Blob MIME must match content or Chrome refuses to play.
String _sniffMimeType(Uint8List bytes, String fallback) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x4F &&
      bytes[1] == 0x67 &&
      bytes[2] == 0x67 &&
      bytes[3] == 0x53) {
    return 'audio/ogg; codecs=opus';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33) {
    return 'audio/mpeg';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
    return 'audio/mpeg';
  }
  return fallback;
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

    final blob = html.Blob([bytes], _sniffMimeType(bytes, mimeType));
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

Future<bool> playAssetUrl(String assetUrl, double speed, int repeat) async {
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
