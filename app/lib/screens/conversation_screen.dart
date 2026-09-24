import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:app_settings/app_settings.dart';
import 'package:record/record.dart';
import '../services/audio_service.dart';
import '../services/conversation_turn_engine.dart';
import '../services/progress_service.dart';
import '../services/speech_service.dart';
import '../services/temp_recording_helper.dart';
import '../services/ui_text.dart';
import '../services/voice_compare_service.dart';
import '../services/web_speech_support.dart';

enum _Phase { idle, listening, result }

class _ChatEntry {
  final ConversationTurn turn;
  final VoiceScore? score;
  const _ChatEntry(this.turn, {this.score});
}

class ConversationScreen extends StatefulWidget {
  final String lang;
  final String title;
  final List<ConversationTurn> turns;
  const ConversationScreen({
    super.key,
    required this.lang,
    required this.title,
    required this.turns,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  static const String targetLang = 'es';

  int _index = 0;
  _Phase _phase = _Phase.idle;
  String _partial = '';
  VoiceScore? _score;
  final Set<int> _passed = {};
  bool _fallback = false;
  bool _sttChecked = false;
  bool _speechUnsupported = false;
  bool _rationaleShown = false;
  bool _busy = false;
  final List<_ChatEntry> _history = [];

  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  String? _recPath;
  Timer? _recSafety;
  AudioPlayer? _abPlayer;
  final ScrollController _scrollCtrl = ScrollController();

  ConversationTurn? get _current =>
      _index < widget.turns.length ? widget.turns[_index] : null;

  int get _learnerTotal =>
      widget.turns.where((t) => t.role == TurnRole.learner).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTurn());
    _initSpeechQuietly();
  }

  Future<void> _initSpeechQuietly() async {
    if (kIsWeb && !browserSupportsSpeechRecognition) {
      if (mounted) {
        setState(() {
          _fallback = true;
          _speechUnsupported = true;
          _sttChecked = true;
        });
      }
      return;
    }
    final ok = await SpeechService.instance.ensureInitialized();
    if (!ok && mounted) {
      setState(() {
        _fallback = true;
        _sttChecked = true;
      });
    } else if (mounted) {
      setState(() => _sttChecked = true);
    }
  }

  @override
  void dispose() {
    _recSafety?.cancel();
    _scrollCtrl.dispose();
    SpeechService.instance.cancelCurrent();
    if (_recording) {
      _recorder.cancel().catchError((_) {});
    }
    _recorder.dispose().catchError((_) {});
    _abPlayer?.dispose();
    AudioService.instance.stop();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  void _haptic() {
    HapticFeedback.mediumImpact();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _primary(ConversationTurn t) => t.text.tr(targetLang);

  void _startTurn() {
    final turn = _current;
    if (turn == null) return;
    setState(() {
      _phase = _Phase.idle;
      _partial = '';
      _score = null;
    });
    if (turn.role == TurnRole.partner) {
      AudioService.instance.playText(_primary(turn), targetLang);
    }
  }

  void _advance() {
    _recSafety?.cancel();
    if (_recording) {
      _recording = false;
      _recorder.cancel().catchError((_) {});
    }
    final oldRec = _recPath;
    final turn = _current;
    if (turn != null && turn.role == TurnRole.learner) {
      setState(() {
        _history.add(_ChatEntry(turn, score: _score));
      });
    } else if (turn != null) {
      setState(() {
        _history.add(_ChatEntry(turn));
      });
    }
    setState(() {
      _index++;
      _phase = _Phase.idle;
      _partial = '';
      _score = null;
      _recPath = null;
    });
    if (oldRec != null && oldRec.isNotEmpty) deleteRecording(oldRec);
    cleanupOldRecordings();
    _scrollToBottom();
    if (_index < widget.turns.length) {
      _startTurn();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _replayPartner() {
    final turn = _current;
    if (turn == null) return;
    if (turn.role == TurnRole.learner) {
      // Replay the previous partner line if present.
      for (var i = _history.length - 1; i >= 0; i--) {
        if (_history[i].turn.role == TurnRole.partner) {
          AudioService.instance.playText(
            _primary(_history[i].turn),
            targetLang,
          );
          return;
        }
      }
      return;
    }
    AudioService.instance.playText(_primary(turn), targetLang);
  }

  Future<bool> _showRationale() async {
    if (_rationaleShown) return true;
    _rationaleShown = true;
    final go = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              uiText(
                widget.lang,
                ar: 'الميكروفون',
                es: 'Micrófono',
                other: 'Microphone',
              ),
            ),
            content: Text(
              uiText(
                widget.lang,
                ar:
                    'نستخدم الميكروفون لسماع نطقك وتقييم الإجابة. لن يُسجَّل شيء خارج الجهاز.',
                es:
                    'Usamos el micrófono para escuchar tu habla y evaluar tu respuesta. Nada se guarda fuera del dispositivo.',
                other:
                    'We use the microphone to hear your answer and score your pronunciation. Nothing is saved off-device.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  uiText(
                    widget.lang,
                    ar: 'إلغاء',
                    es: 'Cancelar',
                    other: 'Cancel',
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  uiText(
                    widget.lang,
                    ar: 'السماح',
                    es: 'Permitir',
                    other: 'Allow',
                  ),
                ),
              ),
            ],
          ),
    );
    return go ?? false;
  }

  Future<void> _onMicPressed() async {
    if (_phase == _Phase.listening) {
      await SpeechService.instance.cancelCurrent();
      return;
    }
    if (_busy) return;
    final turn = _current;
    if (turn == null || turn.role != TurnRole.learner) return;

    if (!_sttChecked || !SpeechService.instance.available) {
      if (kIsWeb && !browserSupportsSpeechRecognition) {
        setState(() {
          _fallback = true;
          _speechUnsupported = true;
          _sttChecked = true;
        });
        _msg(_unsupportedSpeechText());
        return;
      }
      final ok = await SpeechService.instance.ensureInitialized();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _fallback = true;
          _sttChecked = true;
        });
        _msg(
          uiText(
            widget.lang,
            ar: 'التعرف على الصوت غير متاح — استخدم الوضع اليدوي',
            es: 'Reconocimiento de voz no disponible — usa el modo manual',
            other: 'Speech recognition unavailable — use manual mode',
          ),
        );
        return;
      }
    }

    final allowed = await _showRationale();
    if (!allowed || !mounted) return;
    final hasMic = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasMic) {
      setState(() => _fallback = true);
      _msg(
        uiText(
          widget.lang,
          ar: 'إذن الميكروفون مرفوض',
          es: 'Permiso de micrófono denegado',
          other: 'Microphone permission denied',
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _phase = _Phase.listening;
      _partial = '';
      _score = null;
    });
    try {
      await AudioService.instance.stop();
    } catch (_) {}

    final outcome = await SpeechService.instance.listenOnce(
      localeId: SpeechService.localeForLang(targetLang),
      onPartial: (p) {
        if (mounted) setState(() => _partial = p);
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome.error == 'interrupted') {
      setState(() => _phase = _Phase.idle);
      return;
    }
    if (!outcome.ok) {
      setState(() => _phase = _Phase.idle);
      if (outcome.error == 'permission_denied' ||
          outcome.error == 'not_initialized' ||
          outcome.error == 'listen_failed') {
        setState(() => _fallback = true);
        _msg(
          uiText(
            widget.lang,
            ar: 'تعذر تشغيل الميكروفون — استخدم الوضع اليدوي',
            es: 'No se pudo usar el micrófono — usa el modo manual',
            other: 'Could not use the microphone — use manual mode',
          ),
        );
        _scrollToBottom();
      } else {
        _msg(_errorText(outcome.error));
      }
      return;
    }
    final score = ConversationTurnEngine.scoreLearner(turn, outcome.text ?? '');
    setState(() {
      _phase = _Phase.result;
      _score = score;
      _partial = '';
    });
    _haptic();
    _scrollToBottom();
    if (score.passed && _passed.add(_index)) {
      ProgressService.instance.incrementSpeakingDone();
    }
  }

  Future<void> _retryMic() async {
    setState(() {
      _fallback = false;
      _sttChecked = false;
      _speechUnsupported = false;
    });
    if (kIsWeb && !browserSupportsSpeechRecognition) {
      setState(() {
        _fallback = true;
        _speechUnsupported = true;
        _sttChecked = true;
      });
      _msg(_unsupportedSpeechText());
      return;
    }
    final ok = await SpeechService.instance.ensureInitialized();
    if (!mounted) return;
    setState(() => _sttChecked = true);
    if (!ok) {
      setState(() => _fallback = true);
      _msg(
        uiText(
          widget.lang,
          ar: 'ما زال الميكروفون غير متاح',
          es: 'El micrófono sigue no disponible',
          other: 'Microphone still unavailable',
        ),
      );
      return;
    }
    _msg(
      uiText(
        widget.lang,
        ar: 'الميكروفون جاهز',
        es: 'Micrófono listo',
        other: 'Microphone ready',
      ),
    );
    await _onMicPressed();
  }

  Future<void> _openSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (e) {
      debugPrint('openAppSettings failed: $e');
      _msg(
        uiText(
          widget.lang,
          ar: 'افتح الإعدادات يدوياً لإذن الميكروفون',
          es: 'Abre Ajustes para conceder el micrófono',
          other: 'Open Settings to grant the microphone',
        ),
      );
    }
  }

  String _unsupportedSpeechText() => uiText(
    widget.lang,
    ar:
        'هذا المتصفح لا يدعم التعرف على الصوت (Firefox). سجّل صوتك واستمع ثم تحقّق بنفسك',
    es:
        'Este navegador no tiene reconocimiento de voz (Firefox). Graba, escucha y comprueba tú mismo',
    other:
        'This browser has no speech recognition (Firefox). Record, replay and self-check instead.',
  );

  String _errorText(String? code) {
    switch (code) {
      case 'no_match':
      case 'timeout':
      case 'error_speech_timeout':
      case 'error_no_match':
        return uiText(
          widget.lang,
          ar: 'لم أسمع شيئاً — حاول مرة أخرى',
          es: 'No escuché nada — inténtalo de nuevo',
          other: "Didn't catch that — try again",
        );
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server':
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        if (kIsWeb) {
          return uiText(
            widget.lang,
            ar:
                'التعرف على الصوت في المتصفح يحتاج اتصالاً بالإنترنت. يمكنك التسجيل والتحقق بنفسك',
            es:
                'El reconocimiento de voz del navegador necesita internet. Puedes grabar y comprobarte tú mismo',
            other:
                'Browser speech recognition needs internet. You can record and self-check instead.',
          );
        }
        return uiText(
          widget.lang,
          ar:
              'حمّل حزمة اللغة دون اتصال: الإعدادات ← Google ← التعرف على الصوت دون اتصال',
          es:
              'Descarga el paquete sin conexión: Ajustes → Google → Reconocimiento de voz sin conexión',
          other:
              'Install the offline pack: Settings → Google → Offline speech recognition',
        );
      default:
        return uiText(
          widget.lang,
          ar: 'تعذر التعرف على الكلام — حاول مرة أخرى',
          es: 'No se reconoció — inténtalo de nuevo',
          other: 'Not recognized — try again',
        );
    }
  }

  Future<void> _toggleRecord() async {
    if (kIsWeb && !browserIsSecureContext) {
      _msg(
        uiText(
          widget.lang,
          ar: 'الميكروفون يحتاج https أو localhost',
          es: 'El micrófono necesita https o localhost',
          other: 'Microphone needs https or localhost',
        ),
      );
      return;
    }
    try {
      if (_recording) {
        _recSafety?.cancel();
        final path = await _recorder.stop();
        _recording = false;
        if (path != null && path.isNotEmpty) _recPath = path;
        if (mounted) setState(() {});
        await _playRec();
        return;
      }
      final hasMic = await _recorder.hasPermission();
      if (!hasMic) {
        _msg(
          uiText(
            widget.lang,
            ar: 'إذن الميكروفون مرفوض',
            es: 'Permiso de micrófono denegado',
            other: 'Microphone permission denied',
          ),
        );
        return;
      }
      await cleanupOldRecordings(keepPath: _recPath);
      // Browsers record through MediaRecorder and ignore the path entirely;
      // aacLc is not a supported MediaRecorder mime type there.
      final path = await newRecordingPath() ?? 'talktome_user.webm';
      await _recorder.start(
        RecordConfig(
          numChannels: 1,
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        ),
        path: path,
      );
      _recording = true;
      _recPath = null;
      _recSafety?.cancel();
      _recSafety = Timer(const Duration(seconds: 10), () async {
        if (_recording) {
          final p = await _recorder.stop();
          _recording = false;
          if (p != null && p.isNotEmpty) _recPath = p;
          if (mounted) setState(() {});
          await _playRec();
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      _recording = false;
      if (mounted) setState(() {});
      _msg(
        uiText(
          widget.lang,
          ar: 'تعذر بدء التسجيل',
          es: 'No se pudo grabar',
          other: 'Could not record',
        ),
      );
    }
  }

  Future<void> _playRec() async {
    final path = _recPath;
    if (path == null) return;
    try {
      _abPlayer ??= AudioPlayer();
      // Web recordings come back from the recorder as a blob: URL.
      if (kIsWeb) {
        await _abPlayer!.setUrl(path);
      } else {
        await _abPlayer!.setFilePath(path);
      }
      await _abPlayer!.play();
    } catch (e) {
      _msg(
        uiText(
          widget.lang,
          ar: 'تعذر تشغيل التسجيل',
          es: 'No se pudo reproducir la grabación',
          other: 'Could not play the recording',
        ),
      );
    }
  }

  void _selfGradeDone() {
    final turn = _current;
    if (turn == null) return;
    if (_passed.add(_index)) {
      ProgressService.instance.incrementSpeakingDone();
    }
    setState(() {
      _phase = _Phase.result;
      _score = VoiceScore(
        score: 100,
        heard: uiText(
          widget.lang,
          ar: 'تم تقييم يدوي',
          es: 'Evaluación manual',
          other: 'Manually graded',
        ),
        expected: turn.accepted.isNotEmpty ? turn.accepted.first : '',
      );
    });
    _haptic();
    _scrollToBottom();
  }

  void _retry() {
    setState(() {
      _phase = _Phase.idle;
      _score = null;
      _partial = '';
    });
    _replayPartner();
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= widget.turns.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(12),
        children: [
          if (!done) ...[
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value:
                        widget.turns.isEmpty
                            ? 0
                            : (_index +
                                    (_phase == _Phase.result &&
                                            (_score?.passed ?? false)
                                        ? 1
                                        : 0)) /
                                widget.turns.length,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_index + 1}/${widget.turns.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              uiText(
                widget.lang,
                ar: '${_passed.length} ناجحة',
                es: '${_passed.length} correctas',
                other: '${_passed.length} correct',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ..._history.map((e) => _buildBubble(context, e.turn, e.score)),
            _buildCurrent(context),
          ] else
            _buildDoneCard(context),
        ],
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    ConversationTurn turn,
    VoiceScore? score,
  ) {
    final lang = widget.lang;
    final primary = _primary(turn);
    final isLearner = turn.role == TurnRole.learner;
    final smallTailOnRight =
        Directionality.of(context) == TextDirection.rtl
            ? !isLearner
            : isLearner;
    final translated = lang == targetLang ? '' : turn.text.tr(lang);
    final showTrans =
        translated.isNotEmpty &&
        VoiceCompareService.normalize(translated) !=
            VoiceCompareService.normalize(primary);
    final ar = turn.text.ar;
    final showAr =
        ar.isNotEmpty &&
        VoiceCompareService.normalize(ar) !=
            VoiceCompareService.normalize(primary) &&
        (!showTrans ||
            VoiceCompareService.normalize(ar) !=
                VoiceCompareService.normalize(translated));

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 8),
      alignment:
          isLearner
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isLearner
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(smallTailOnRight ? 14 : 4),
            bottomRight: Radius.circular(smallTailOnRight ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isLearner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              turn.speaker,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              primary,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (showTrans) ...[
              const SizedBox(height: 2),
              Text(
                translated,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (showAr) ...[
              const SizedBox(height: 2),
              Align(
                alignment: AlignmentDirectional.centerEnd.resolve(
                  Directionality.of(context),
                ),
                child: Text(
                  ar,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
            if (score != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    score.passed
                        ? Icons.check_circle
                        : score.retry
                        ? Icons.trending_up
                        : Icons.cancel,
                    size: 16,
                    color:
                        score.passed
                            ? Colors.green
                            : score.retry
                            ? Colors.orange
                            : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${score.score}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color:
                          score.passed
                              ? Colors.green
                              : score.retry
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return bubble;
  }

  Widget _buildCurrent(BuildContext context) {
    final turn = _current;
    if (turn == null) return const SizedBox.shrink();
    final lang = widget.lang;
    final style = Theme.of(context).textTheme;

    if (turn.role == TurnRole.partner) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiText(
                  lang,
                  ar: '${turn.speaker} يتحدث…',
                  es: '${turn.speaker} habla…',
                  other: '${turn.speaker} is speaking…',
                ),
                style: style.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _replayPartner,
                      icon: const Icon(Icons.volume_up, size: 20),
                      label: Text(
                        uiText(
                          lang,
                          ar: 'استمع',
                          es: 'Escuchar',
                          other: 'Listen',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _advance,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        uiText(
                          lang,
                          ar: 'دورك',
                          es: 'Tu turno',
                          other: 'Your turn',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final primary = _primary(turn);
    final hint =
        turn.freeAnswer
            ? uiText(
              lang,
              ar: 'أجب بحرية عن السؤال',
              es: 'Responde libremente a la pregunta',
              other: 'Answer the question freely',
            )
            : uiText(
              lang,
              ar: 'قل هذه الجملة',
              es: 'Di esta frase',
              other: 'Say this sentence',
            );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(turn.speaker.isNotEmpty ? turn.speaker[0] : '?'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uiText(
                      lang,
                      ar: 'دورك — ${turn.speaker}',
                      es: 'Tu turno — ${turn.speaker}',
                      other: 'Your turn — ${turn.speaker}',
                    ),
                    style: style.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              turn.freeAnswer ? hint : primary,
              style:
                  turn.freeAnswer
                      ? style.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                      : style.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (turn.freeAnswer) ...[
              const SizedBox(height: 6),
              Text(
                uiText(
                  lang,
                  ar: 'تلميح: الجملة المتوقعة تظهر بعد التقييم',
                  es: 'Pista: la frase esperada aparece tras la evaluación',
                  other: 'Hint: the expected phrase shows after scoring',
                ),
                style: style.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _replayPartner,
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: Text(
                    uiText(
                      lang,
                      ar: 'استمع للسؤال',
                      es: 'Escuchar pregunta',
                      other: 'Hear prompt',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_fallback)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selfGradeDone,
                      icon: const Icon(Icons.check),
                      label: Text(
                        uiText(
                          lang,
                          ar: 'تكلمت',
                          es: 'Hablé',
                          other: 'I spoke',
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _phase == _Phase.result ? _retry : _onMicPressed,
                      icon:
                          _phase == _Phase.listening
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                _phase == _Phase.result
                                    ? Icons.mic_off
                                    : Icons.mic,
                              ),
                      label: Text(
                        _phase == _Phase.listening
                            ? uiText(
                              lang,
                              ar: 'جارٍ الاستماع…',
                              es: 'Escuchando…',
                              other: 'Listening…',
                            )
                            : _phase == _Phase.result
                            ? uiText(
                              lang,
                              ar: 'إعادة المحاولة',
                              es: 'Intentar de nuevo',
                              other: 'Try again',
                            )
                            : uiText(
                              lang,
                              ar: 'تحدَّث',
                              es: 'Hablar',
                              other: 'Speak',
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_phase == _Phase.listening) ...[
              const SizedBox(height: 8),
              Text(
                uiText(
                  lang,
                  ar: 'انقر للإيقاف',
                  es: 'Toca para detener',
                  other: 'Tap to stop',
                ),
                style: style.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
              if (_partial.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_partial, style: style.bodyMedium),
              ],
            ],
            if (_fallback && _phase != _Phase.listening) ...[
              const SizedBox(height: 8),
              Text(
                _speechUnsupported
                    ? uiText(
                      lang,
                      ar: 'سجّل صوتك ثم استمع إليه — يعمل بالكامل دون إنترنت',
                      es:
                          'Graba tu voz y luego escúchala: funciona totalmente sin conexión',
                      other:
                          'Record your voice, then replay it — works fully offline',
                    )
                    : uiText(
                      lang,
                      ar: 'وضع يدوي: استمع ثم قل الجملة ثم تحقق بنفسك',
                      es:
                          'Modo manual: escucha, di la frase y comprueba tú mismo',
                      other:
                          'Manual mode: listen, say the phrase, and self-check',
                    ),
                style: style.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
              if (_speechUnsupported) ...[
                const SizedBox(height: 8),
                _buildRecordRow(context),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _retryMic,
                    icon: const Icon(Icons.mic, size: 18),
                    label: Text(
                      uiText(
                        lang,
                        ar: 'إعادة المحاولة بالميكروفون',
                        es: 'Probar el micrófono de nuevo',
                        other: 'Retry microphone',
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(
                        uiText(
                          lang,
                          ar: 'الإعدادات',
                          es: 'Ajustes',
                          other: 'Settings',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (_phase == _Phase.result && _score != null) ...[
              const SizedBox(height: 12),
              _buildScoreCard(context, _score!, turn),
              const SizedBox(height: 8),
              _buildResultActions(context, turn),
            ],
            if (_phase == _Phase.result || kIsWeb) ...[
              const SizedBox(height: 8),
              _buildRecordRow(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context,
    VoiceScore score,
    ConversationTurn turn,
  ) {
    final lang = widget.lang;
    final color =
        score.passed
            ? Colors.green
            : score.retry
            ? Colors.orange
            : Colors.red;
    final icon =
        score.passed
            ? Icons.check_circle
            : score.retry
            ? Icons.trending_up
            : Icons.cancel;
    final label =
        score.passed
            ? uiText(lang, ar: 'أحسنت!', es: '¡Muy bien!', other: 'Great!')
            : score.retry
            ? uiText(
              lang,
              ar: 'اقتربت! أعد المحاولة',
              es: '¡Casi! Inténtalo de nuevo',
              other: 'Almost! Try again',
            )
            : uiText(
              lang,
              ar: 'لم أفهم — أعد المحاولة',
              es: 'No te entendí — inténtalo de nuevo',
              other: "Didn't catch that — try again",
            );
    final manual =
        score.heard ==
        uiText(
          lang,
          ar: 'تم تقييم يدوي',
          es: 'Evaluación manual',
          other: 'Manually graded',
        );
    final alternatives =
        turn.freeAnswer && turn.accepted.length > 1
            ? turn.accepted.take(3).toList()
            : <String>[];

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label (${score.score}%)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (score.expected.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${uiText(lang, ar: 'المتوقع:', es: 'Esperado:', other: 'Expected:')} "${score.expected}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!manual && score.heard.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${uiText(lang, ar: 'سمعت:', es: 'Escuché:', other: 'Heard:')} "${score.heard}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${uiText(lang, ar: 'أجابات مقبولة:', es: 'Respuestas aceptadas:', other: 'Accepted answers:')} ${alternatives.join(' · ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultActions(BuildContext context, ConversationTurn turn) {
    final lang = widget.lang;
    final passed = _score?.passed ?? false;
    final isLast = _index >= widget.turns.length - 1;
    return Row(
      children: [
        Expanded(
          child:
              passed
                  ? FilledButton.icon(
                    onPressed: _advance,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      isLast
                          ? uiText(
                            lang,
                            ar: 'إنهاء',
                            es: 'Finalizar',
                            other: 'Finish',
                          )
                          : uiText(
                            lang,
                            ar: 'التالي',
                            es: 'Siguiente',
                            other: 'Next',
                          ),
                    ),
                  )
                  : OutlinedButton.icon(
                    onPressed: _advance,
                    icon: const Icon(Icons.skip_next),
                    label: Text(
                      uiText(lang, ar: 'تخطي', es: 'Omitir', other: 'Skip'),
                    ),
                  ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _replayPartner,
          icon: const Icon(Icons.volume_up, size: 20),
          label: Text(
            uiText(lang, ar: 'الموديل', es: 'Modelo', other: 'Model'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordRow(BuildContext context) {
    final lang = widget.lang;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleRecord,
            icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
            label: Text(
              _recording
                  ? uiText(
                    lang,
                    ar: 'إيقاف التسجيل',
                    es: 'Detener grabación',
                    other: 'Stop recording',
                  )
                  : uiText(
                    lang,
                    ar: 'سجّل صوتي',
                    es: 'Grabar mi voz',
                    other: 'Record my voice',
                  ),
            ),
          ),
        ),
        if (_recPath != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _playRec,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                uiText(
                  lang,
                  ar: 'استمع لنفسك',
                  es: 'Escuchar mi voz',
                  other: 'Hear myself',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoneCard(BuildContext context) {
    final lang = widget.lang;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.celebration, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              uiText(
                lang,
                ar: 'أحسنت! انتهت المحادثة',
                es: '¡Muy bien! Conversación terminada',
                other: 'Great! Conversation finished',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              uiText(
                lang,
                ar: '${_passed.length}/$_learnerTotal جمل صحيحة',
                es: '${_passed.length}/$_learnerTotal frases correctas',
                other: '${_passed.length}/$_learnerTotal correct phrases',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: Text(
                uiText(lang, ar: 'تم', es: 'Finalizar', other: 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
