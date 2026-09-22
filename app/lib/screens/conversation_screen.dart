import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:app_settings/app_settings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/audio_service.dart';
import '../services/conversation_turn_engine.dart';
import '../services/progress_service.dart';
import '../services/speech_service.dart';
import '../services/ui_text.dart';
import '../services/voice_compare_service.dart';

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
  bool _rationaleShown = false;
  bool _busy = false;
  final List<_ChatEntry> _history = [];

  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  String? _recPath;
  Timer? _recSafety;
  AudioPlayer? _abPlayer;

  ConversationTurn? get _current =>
      _index < widget.turns.length ? widget.turns[_index] : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTurn());
    _initSpeechQuietly();
  }

  Future<void> _initSpeechQuietly() async {
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
                pt: 'Microfone',
                other: 'Microphone',
              ),
            ),
            content: Text(
              uiText(
                widget.lang,
                ar:
                    'نستخدم الميكروفون لسماع نطقك وتقييم الإجابة. لن يُسجَّل شيء خارج الجهاز.',
                pt:
                    'Usamos o microfone para ouvir sua fala e avaliar sua resposta. Nada é gravado fora do aparelho.',
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
                    pt: 'Cancelar',
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
                    pt: 'Permitir',
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
    if (_busy) return;
    if (_phase == _Phase.listening) {
      await SpeechService.instance.cancelCurrent();
      return;
    }
    final turn = _current;
    if (turn == null || turn.role != TurnRole.learner) return;

    if (!_sttChecked || !SpeechService.instance.available) {
      final ok = await SpeechService.instance.ensureInitialized();
      if (!ok) {
        setState(() {
          _fallback = true;
          _sttChecked = true;
        });
        _msg(
          uiText(
            widget.lang,
            ar: 'التعرف على الصوت غير متاح — استخدم الوضع اليدوي',
            pt: 'Reconhecimento de voz indisponível — use o modo manual',
            other: 'Speech recognition unavailable — use manual mode',
          ),
        );
        return;
      }
    }

    final allowed = await _showRationale();
    if (!allowed) return;

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
            pt: 'Não foi possível usar o microfone — use o modo manual',
            other: 'Could not use the microphone — use manual mode',
          ),
        );
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
    if (score.passed && _passed.add(_index)) {
      ProgressService.instance.incrementSpeakingDone();
    }
  }

  Future<void> _retryMic() async {
    setState(() {
      _fallback = false;
      _sttChecked = false;
    });
    final ok = await SpeechService.instance.ensureInitialized();
    if (!mounted) return;
    setState(() => _sttChecked = true);
    if (!ok) {
      setState(() => _fallback = true);
      _msg(
        uiText(
          widget.lang,
          ar: 'ما زال الميكروفون غير متاح',
          pt: 'O microfone ainda está indisponível',
          other: 'Microphone still unavailable',
        ),
      );
      return;
    }
    _msg(
      uiText(
        widget.lang,
        ar: 'الميكروفون جاهز',
        pt: 'Microfone pronto',
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
          pt: 'Abra as Configurações para conceder o microfone',
          other: 'Open Settings to grant the microphone',
        ),
      );
    }
  }

  String _errorText(String? code) {
    switch (code) {
      case 'no_match':
      case 'timeout':
      case 'error_speech_timeout':
      case 'error_no_match':
        return uiText(
          widget.lang,
          ar: 'لم أسمع شيئاً — حاول مرة أخرى',
          pt: 'Não ouvi nada — tente de novo',
          other: "Didn't catch that — try again",
        );
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server':
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return uiText(
          widget.lang,
          ar:
              'حمّل حزمة اللغة دون اتصال: الإعدادات ← Google ← التعرف على الصوت دون اتصال',
          pt:
              'Baixe o pacote offline: Configurações → Google → Reconhecimento de voz offline',
          other:
              'Install the offline pack: Settings → Google → Offline speech recognition',
        );
      default:
        return uiText(
          widget.lang,
          ar: 'تعذر التعرف على الكلام — حاول مرة أخرى',
          pt: 'Não foi reconhecido — tente de novo',
          other: 'Not recognized — try again',
        );
    }
  }

  Future<void> _toggleRecord() async {
    if (kIsWeb) return;
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
            pt: 'Permissão de microfone negada',
            other: 'Microphone permission denied',
          ),
        );
        return;
      }
      await _cleanupOldRecordings();
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/talktome_user_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(numChannels: 1), path: path);
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
          pt: 'Não foi possível gravar',
          other: 'Could not record',
        ),
      );
    }
  }

  Future<void> _cleanupOldRecordings() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final p = entity.path;
        if (!p.contains('talktome_user_') || !p.endsWith('.m4a')) continue;
        if (_recPath != null && p == _recPath) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _playRec() async {
    final path = _recPath;
    if (path == null) return;
    try {
      _abPlayer ??= AudioPlayer();
      await _abPlayer!.setFilePath(path);
      await _abPlayer!.play();
    } catch (e) {
      _msg(
        uiText(
          widget.lang,
          ar: 'تعذر تشغيل التسجيل',
          pt: 'Não foi possível reproduzir a gravação',
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
          pt: 'Avaliação manual',
          other: 'Manually graded',
        ),
        expected: turn.accepted.isNotEmpty ? turn.accepted.first : '',
      );
    });
    _haptic();
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
                pt: '${_passed.length} corretas',
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
      alignment: isLearner ? Alignment.centerRight : Alignment.centerLeft,
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
            bottomLeft: Radius.circular(isLearner ? 14 : 4),
            bottomRight: Radius.circular(isLearner ? 4 : 14),
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
                  pt: '${turn.speaker} fala…',
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
                        uiText(lang, ar: 'استمع', pt: 'Ouvir', other: 'Listen'),
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
                          pt: 'Sua vez',
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
              pt: 'Responda livremente à pergunta',
              other: 'Answer the question freely',
            )
            : uiText(
              lang,
              ar: 'قل هذه الجملة',
              pt: 'Diga esta frase',
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
                      pt: 'Sua vez — ${turn.speaker}',
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
                  pt: 'Dica: a frase esperada aparece após a avaliação',
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
                      pt: 'Ouvir pergunta',
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
                          pt: 'Falei',
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
                              pt: 'Ouvindo…',
                              other: 'Listening…',
                            )
                            : _phase == _Phase.result
                            ? uiText(
                              lang,
                              ar: 'إعادة المحاولة',
                              pt: 'Tentar de novo',
                              other: 'Try again',
                            )
                            : uiText(
                              lang,
                              ar: 'تحدَّث',
                              pt: 'Falar',
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
                  pt: 'Toque para parar',
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
                uiText(
                  lang,
                  ar: 'وضع يدوي: استمع ثم قل الجملة ثم تحقق بنفسك',
                  pt: 'Modo manual: ouça, fale a frase e verifique você mesmo',
                  other: 'Manual mode: listen, say the phrase, and self-check',
                ),
                style: style.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
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
                        pt: 'Tentar o microfone de novo',
                        other: 'Retry microphone',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings, size: 18),
                    label: Text(
                      uiText(
                        lang,
                        ar: 'الإعدادات',
                        pt: 'Configurações',
                        other: 'Settings',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_phase == _Phase.result && _score != null) ...[
              const SizedBox(height: 12),
              _buildScoreCard(context, _score!, turn),
              const SizedBox(height: 8),
              _buildResultActions(context, turn),
            ],
            if (_phase == _Phase.result && !kIsWeb) ...[
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
            ? uiText(lang, ar: 'أحسنت!', pt: 'Muito bem!', other: 'Great!')
            : score.retry
            ? uiText(
              lang,
              ar: 'اقتربت! أعد المحاولة',
              pt: 'Quase! Tente de novo',
              other: 'Almost! Try again',
            )
            : uiText(
              lang,
              ar: 'لم أفهم — أعد المحاولة',
              pt: 'Não entendi — tente de novo',
              other: "Didn't catch that — try again",
            );
    final manual =
        score.heard ==
        uiText(
          lang,
          ar: 'تم تقييم يدوي',
          pt: 'Avaliação manual',
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
                '${uiText(lang, ar: 'المتوقع:', pt: 'Esperado:', other: 'Expected:')} "${score.expected}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!manual && score.heard.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${uiText(lang, ar: 'سمعت:', pt: 'Ouvi:', other: 'Heard:')} "${score.heard}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${uiText(lang, ar: 'أجابات مقبولة:', pt: 'Respostas aceitas:', other: 'Accepted answers:')} ${alternatives.join(' · ')}',
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
                            pt: 'Concluir',
                            other: 'Finish',
                          )
                          : uiText(
                            lang,
                            ar: 'التالي',
                            pt: 'Próxima',
                            other: 'Next',
                          ),
                    ),
                  )
                  : OutlinedButton.icon(
                    onPressed: _advance,
                    icon: const Icon(Icons.skip_next),
                    label: Text(
                      uiText(lang, ar: 'تخطي', pt: 'Pular', other: 'Skip'),
                    ),
                  ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _replayPartner,
          icon: const Icon(Icons.volume_up, size: 20),
          label: Text(
            uiText(lang, ar: 'الموديل', pt: 'Modelo', other: 'Model'),
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
                    pt: 'Parar gravação',
                    other: 'Stop recording',
                  )
                  : uiText(
                    lang,
                    ar: 'سجّل صوتي',
                    pt: 'Gravar minha voz',
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
                  pt: 'Ouvir minha voz',
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
                pt: 'Muito bem! Conversa concluída',
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
                ar: '${_passed.length}/${widget.turns.length} جمل صحيحة',
                pt: '${_passed.length}/${widget.turns.length} frases corretas',
                other:
                    '${_passed.length}/${widget.turns.length} correct phrases',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: Text(
                uiText(lang, ar: 'تم', pt: 'Concluir', other: 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
