import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

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
    final key = audioKey(text, lang); // e.g. "es_bac80f75e917.opus"
    final asset = 'assets/audio/$key';
    if (kDebugMode) {
      debugPrint('AudioService: playing $asset for lang=$lang text="$text"');
    }
    return playAsset(asset);
  }

  Future<bool> playAsset(String assetPath) async {
    try {
      // Verify the asset actually exists first
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
        // Subscribe BEFORE play() so we never miss the completed event.
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
      // A broken/stuck player should never require an app restart.
      try {
        await _player?.dispose();
      } catch (_) {}
      _player = null;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
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
