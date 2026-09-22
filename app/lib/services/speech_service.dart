import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechListenOutcome {
  final String? text;
  final String? error;
  const SpeechListenOutcome({this.text, this.error});

  bool get ok => text != null && text!.trim().isNotEmpty;
}

class SpeechService {
  static final SpeechService instance = SpeechService._();
  SpeechService._();

  /// Errors that mean the offline language pack (or a network fallback) was
  /// unavailable — safe to retry once with `onDevice: false`.
  static const Set<String> _packRetryErrors = {
    'error_language_unavailable',
    'error_language_not_supported',
    'error_network',
    'error_network_timeout',
    'error_server',
  };

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  Future<bool>? _initFuture;
  Completer<SpeechListenOutcome>? _session;
  Future<SpeechListenOutcome>? _active;

  bool get available => _initialized;

  static String? localeForLang(String lang) {
    switch (lang) {
      case 'pt':
        return 'pt-BR';
      case 'es':
        return 'es-ES';
      default:
        return null;
    }
  }

  Future<bool> ensureInitialized() {
    if (_initialized) return Future.value(true);
    _initFuture ??= _doInitialize().then((ok) {
      // Allow a fresh attempt on the next call if this one failed —
      // otherwise a single blip would brick the mic until app restart.
      if (!ok) _initFuture = null;
      return ok;
    });
    return _initFuture!;
  }

  Future<bool> _doInitialize() async {
    try {
      _initialized = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );
    } catch (e) {
      debugPrint('SpeechService init error: $e');
      _initialized = false;
    }
    return _initialized;
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint(
      'SpeechService error: ${error.errorMsg} '
      '(permanent=${error.permanent})',
    );
    final session = _session;
    if (session != null && !session.isCompleted) {
      final code =
          error.errorMsg.contains('permission')
              ? 'permission_denied'
              : error.errorMsg;
      session.complete(SpeechListenOutcome(error: code));
    }
  }

  void _onStatus(String status) {
    if (kDebugMode) debugPrint('SpeechService status: $status');
  }

  Future<SpeechListenOutcome> listenOnce({
    String? localeId,
    Duration listenFor = const Duration(seconds: 15),
    void Function(String partial)? onPartial,
  }) {
    final prev = _active;
    final run = _run(
      prev,
      localeId: localeId,
      listenFor: listenFor,
      onPartial: onPartial,
    );
    _active = run;
    return run;
  }

  Future<SpeechListenOutcome> _run(
    Future<SpeechListenOutcome>? prev, {
    required String? localeId,
    required Duration listenFor,
    required void Function(String partial)? onPartial,
  }) async {
    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }
    return _doListen(
      localeId: localeId,
      listenFor: listenFor,
      onPartial: onPartial,
    );
  }

  /// Offline-first: try `onDevice: true`; if the pack/network is missing,
  /// automatically retry once with the default (online-capable) recognizer.
  Future<SpeechListenOutcome> _doListen({
    required String? localeId,
    required Duration listenFor,
    required void Function(String partial)? onPartial,
  }) async {
    final first = await _attemptListen(
      localeId: localeId,
      listenFor: listenFor,
      onPartial: onPartial,
      preferOffline: true,
    );
    if (first.error != null && _packRetryErrors.contains(first.error)) {
      debugPrint('SpeechService: retrying listen without onDevice');
      return _attemptListen(
        localeId: localeId,
        listenFor: listenFor,
        onPartial: onPartial,
        preferOffline: false,
      );
    }
    return first;
  }

  Future<SpeechListenOutcome> _attemptListen({
    required String? localeId,
    required Duration listenFor,
    required void Function(String partial)? onPartial,
    required bool preferOffline,
  }) async {
    if (!_initialized) {
      return const SpeechListenOutcome(error: 'not_initialized');
    }
    final completer = Completer<SpeechListenOutcome>();
    _session = completer;

    Timer? safety;
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          listenMode: ListenMode.dictation,
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 8),
          cancelOnError: false,
          onDevice: preferOffline,
        ),
        onResult: (SpeechRecognitionResult result) {
          if (result.finalResult) {
            if (!completer.isCompleted) {
              completer.complete(
                SpeechListenOutcome(text: result.recognizedWords),
              );
            }
            return;
          }
          final words = result.recognizedWords;
          if (words.isNotEmpty) onPartial?.call(words);
        },
      );
      safety = Timer(listenFor + const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(const SpeechListenOutcome(error: 'timeout'));
        }
      });
      return await completer.future;
    } on SpeechToTextNotInitializedException {
      return const SpeechListenOutcome(error: 'not_initialized');
    } on ListenFailedException catch (e) {
      debugPrint('SpeechService listen failed: ${e.message}');
      return const SpeechListenOutcome(error: 'listen_failed');
    } catch (e) {
      debugPrint('SpeechService listen error: $e');
      return const SpeechListenOutcome(error: 'listen_failed');
    } finally {
      safety?.cancel();
      if (identical(_session, completer)) _session = null;
      try {
        await _stt.cancel();
      } catch (_) {}
    }
  }

  Future<void> cancelCurrent() async {
    final session = _session;
    if (session != null && !session.isCompleted) {
      session.complete(const SpeechListenOutcome(error: 'interrupted'));
    }
  }
}
