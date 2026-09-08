import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'web_audio.dart' if (dart.library.js_util) 'web_audio_helper.dart';

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  AudioPlayer? _player;

  double speed = 1.0;
  int repeat = 1;

  AudioPlayer get _audioPlayer {
    final p = _player;
    if (p != null) return p;
    final created = AudioPlayer();
    _player = created;
    return created;
  }

  Future<bool> playText(String text, String lang) async {
    final key = audioKey(text, lang);
    final asset = 'assets/audio/$key';
    if (kDebugMode) {
      debugPrint('AudioService: playing $asset for lang=$lang text="$text"');
    }
    return playAsset(asset);
  }

  Future<bool> playAsset(String assetPath) async {
    if (kIsWeb) {
      return _playAssetWeb(assetPath);
    }
    return _playAssetNative(assetPath);
  }

  Future<bool> _playAssetWeb(String assetPath) async {
    try {
      final exists = await _assetExists(assetPath);
      if (!exists) {
        if (kDebugMode) {
          debugPrint('AudioService: asset NOT FOUND: $assetPath');
        }
        return false;
      }
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      return await playAssetBytes(
        bytes,
        'audio/ogg; codecs=opus',
        speed.clamp(0.5, 2.0),
        repeat.clamp(1, 10),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioService: web audio ERROR: $e');
      }
      return false;
    }
  }

  Future<bool> _playAssetNative(String assetPath) async {
    try {
      final exists = await _assetExists(assetPath);
      if (!exists) {
        if (kDebugMode) {
          debugPrint('AudioService: asset NOT FOUND: $assetPath');
        }
        return false;
      }
      if (kDebugMode) {
        debugPrint('AudioService: asset found, setting up player');
      }
      final player = _audioPlayer;
      await player.stop();
      await player.setAsset(assetPath);
      await player.setSpeed(speed.clamp(0.5, 2.0));
      final times = repeat.clamp(1, 10);
      for (var i = 0; i < times; i++) {
        final completer = Completer<ProcessingState>();
        final sub = player.processingStateStream.listen((s) {
          if (!completer.isCompleted &&
              (s == ProcessingState.completed || s == ProcessingState.idle)) {
            completer.complete(s);
          }
        });
        try {
          await player.seek(Duration.zero);
          await player.play();
          await completer.future.timeout(
            const Duration(seconds: 60),
            onTimeout: () => ProcessingState.idle,
          );
        } finally {
          await sub.cancel();
        }
      }
      if (kDebugMode) {
        debugPrint('AudioService: playback done, duration=${player.duration}');
      }
      return true;
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('AudioService: ERROR playing $assetPath: $e\n$s');
      }
      try {
        await _player?.dispose();
      } catch (e) {
        debugPrint('AudioService: dispose failed: $e');
      }
      _player = null;
      return false;
    }
  }

  Future<void> stop() async {
    if (kIsWeb) {
      await stopWebAudio();
      return;
    }
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('AudioService: stop failed: $e');
    }
  }

  Future<bool> audioExists(String text, String lang) async {
    final asset = 'assets/audio/${audioKey(text, lang)}';
    return _assetExists(asset);
  }

  Future<bool> _assetExists(String asset) async {
    try {
      await rootBundle.load(asset);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String audioKey(String text, String lang) {
    final h = md5.convert(utf8.encode('$lang:$text')).toString();
    return '${lang}_${h.substring(0, 12)}.opus';
  }
}
