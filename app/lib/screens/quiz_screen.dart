import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/exercise_dedup.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/progress_service.dart';
import '../widgets/audio_button.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../services/ui_text.dart';

class QuizScreen extends StatefulWidget {
  final String levelId;
  const QuizScreen({super.key, required this.levelId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Exercise>? _questions;
  int _index = 0;
  String? _selected;
  String? _selectedMatchLeft;
  bool _revealed = false;
  int _score = 0;
  int _best = 0;
  bool _loading = true;
  bool _finished = false;
  final Set<int> _wrong = {};
  List<String> _matchPairsLeft = [];
  List<String> _matchPairsRight = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await CourseRepository.instance.loadLevels();
    final level = levels[widget.levelId];
    final questions = <Exercise>[];
    final seenWork = <String>{};
    final seenChoice = <String>{};
    if (level != null) {
      for (final lessonMeta in level.lessons) {
        final id = lessonMeta['id'] as String;
        final lesson = await CourseRepository.instance.tryLoadLesson(id);
        if (lesson == null) continue;
        for (final e in lesson.exercises) {
          if (!const [
            'multiple_choice',
            'fill_blank',
            'listening',
            'listening_mcq',
          ].contains(e.type)) {
            continue;
          }
          if (!seenWork.add(exerciseWorkKey(e, 'es'))) continue;
          final choice = exerciseChoiceKey(e, 'es');
          if (choice.isNotEmpty && !seenChoice.add(choice)) continue;
          questions.add(e);
        }
      }
    }
    final best = await ProgressService.instance.getQuizBest(widget.levelId);
    questions.shuffle(Random());
    if (!mounted) return;
    setState(() {
      _questions = questions.take(10).toList();
      _best = best;
      _loading = false;
    });
  }

  void _answer(String pt) {
    setState(() {
      _selected = pt;
      _revealed = true;
      if (pt == _questions![_index].answer) {
        _score++;
      } else {
        _wrong.add(_index);
      }
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _selectedMatchLeft = null;
      _revealed = false;
      if (_index >= _questions!.length) {
        _finished = true;
        _finish();
      }
    });
  }

  void _finish() {
    ProgressService.instance.setQuizBest(widget.levelId, _score);
    ProgressService.instance.incrementQuizzesTaken();
  }

  void _retryWrong() {
    final wrongQs = _wrong.toList();
    if (wrongQs.isEmpty) return;
    setState(() {
      _questions = [for (final i in wrongQs) _questions![i]];
      _wrong.clear();
      _index = 0;
      _score = 0;
      _selected = null;
      _selectedMatchLeft = null;
      _revealed = false;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;

    if (_loading) {
      return AppSelectionArea(
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            uiText(
              lang,
              ar: 'اختبار ${widget.levelId}',
              es: 'Examen ${widget.levelId}',
              other: '${widget.levelId} Quiz',
            ),
          ),
        ),
        body:
            _finished
                ? _buildResult(lang)
                : _buildQuestion(_questions![_index], lang),
      ),
    );
  }

  List<String> _matchCorrectRight = [];
  final Set<String> _matchedLeft = {};
  final Set<String> _matchedRight = {};

  Widget _buildMatchPairs(Exercise e, String lang) {
    if (_matchPairsLeft.isEmpty ||
        _matchPairsLeft.length != _matchPairsRight.length) {
      _initMatchPairsState(e);
    }
    final allMatched = _matchedLeft.length == _matchPairsLeft.length;
    if (allMatched && !_revealed) {
      _revealed = true;
      _score++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${_index + 1}/${_questions!.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            e.prompt.es,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        uiText(
                          lang,
                          pt: 'Português',
                          es: 'Español',
                          ar: 'الإسبانية',
                          other: 'Spanish',
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _matchPairsLeft.length,
                          itemBuilder: (context, i) {
                            final pt = _matchPairsLeft[i];
                            final matched = _matchedLeft.contains(pt);
                            final selected = _selectedMatchLeft == pt;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: OutlinedButton(
                                onPressed:
                                    matched
                                        ? null
                                        : () => setState(() {
                                          _selectedMatchLeft = pt;
                                        }),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      matched
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : selected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.15)
                                          : null,
                                  side: BorderSide(
                                    color:
                                        matched
                                            ? Colors.green
                                            : selected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Colors.grey,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                ),
                                child: Text(
                                  pt,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        uiText(
                          lang,
                          pt: 'Inglês',
                          es: 'Inglés',
                          ar: 'الإنجليزية',
                          other: 'English',
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _matchPairsRight.length,
                          itemBuilder: (context, i) {
                            final en = _matchPairsRight[i];
                            final matched = _matchedRight.contains(en);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: OutlinedButton(
                                onPressed:
                                    matched || _selectedMatchLeft == null
                                        ? null
                                        : () => _tryMatchPair(en),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      matched
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : null,
                                  side: BorderSide(
                                    color: matched ? Colors.green : Colors.grey,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                ),
                                child: Text(
                                  en,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (allMatched)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _next,
              child: Text(
                uiText(lang, ar: 'التالي', es: 'Siguiente', other: 'Next'),
              ),
            ),
          ),
        const CreditFooter(),
      ],
    );
  }

  void _initMatchPairsState(Exercise e) {
    final pairs = e.answer.split('|');
    final left = <String>[];
    final right = <String>[];
    final correct = <String>[];
    for (final p in pairs) {
      final parts = p.split('::');
      if (parts.length == 2) {
        left.add(parts[0]);
        right.add(parts[1]);
        correct.add(parts[1]);
      }
    }
    final shuffledRight = List<String>.from(right)..shuffle();
    _matchPairsLeft = left;
    _matchPairsRight = shuffledRight;
    _matchCorrectRight = correct;
    _matchedLeft.clear();
    _matchedRight.clear();
    _selectedMatchLeft = null;
  }

  void _tryMatchPair(String en) {
    final left = _selectedMatchLeft;
    if (left == null) return;

    final leftIdx = _matchPairsLeft.indexOf(left);
    final correctEn =
        leftIdx < _matchCorrectRight.length ? _matchCorrectRight[leftIdx] : '';

    if (en == correctEn) {
      setState(() {
        _matchedLeft.add(left);
        _matchedRight.add(en);
        _selectedMatchLeft = null;
      });
    } else {
      _wrong.add(_index);
      setState(() {
        _selectedMatchLeft = null;
      });
    }
  }

  Widget _buildResult(String lang) {
    final total = _questions!.length;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _score * 10 >= 60 ? Icons.emoji_events : Icons.menu_book,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_score/$total',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiText(
                      lang,
                      ar: 'أفضل نتيجة: $_best/$total',
                      es: 'Mejor resultado: $_best/$total',
                      other: 'Best score: $_best/$total',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_wrong.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      uiText(
                        lang,
                        ar: 'أخطأت في ${_wrong.length}',
                        es: 'Errores: ${_wrong.length}',
                        other: 'Mistakes: ${_wrong.length}',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_wrong.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _retryWrong,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        uiText(
                          lang,
                          ar: 'مراجعة الأخطاء',
                          es: 'Repasar errores',
                          other: 'Review mistakes',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      uiText(lang, ar: 'إنهاء', es: 'Terminar', other: 'Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const CreditFooter(),
      ],
    );
  }

  Widget _buildQuestion(Exercise e, String lang) {
    if (e.type == 'match_pairs') return _buildMatchPairs(e, lang);
    final q = e.prompt;
    final isMC = const [
      'multiple_choice',
      'fill_blank',
      'listening',
      'listening_mcq',
    ].contains(e.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${_index + 1}/${_questions!.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            q.es,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        if ((e.type == 'listening' || e.type == 'listening_mcq') &&
            e.audio != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(child: AudioButton(text: e.audio!, lang: 'es')),
          ),
        const SizedBox(height: 16),
        if (isMC)
          ...e.options.map(
            (o) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton(
                onPressed: _revealed ? null : () => _answer(o.es),
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      _revealed && o.es == e.answer
                          ? Colors.green.withValues(alpha: 0.2)
                          : _revealed && _selected == o.es
                          ? Colors.red.withValues(alpha: 0.2)
                          : null,
                  side: BorderSide(
                    color:
                        _revealed && o.es == e.answer
                            ? Colors.green
                            : _revealed && _selected == o.es
                            ? Colors.red
                            : Colors.grey,
                  ),
                ),
                child: Text(o.tr(lang)),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              q.en,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const Spacer(),
        if (_revealed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _next,
              child: Text(
                uiText(lang, ar: 'التالي', es: 'Siguiente', other: 'Next'),
              ),
            ),
          ),
        const CreditFooter(),
      ],
    );
  }
}
