import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/verb_models.dart';
import '../services/app_state.dart';
import '../services/verb_repository.dart';
import '../widgets/audio_button.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';

class VerbScreen extends StatefulWidget {
  const VerbScreen({super.key});

  @override
  State<VerbScreen> createState() => _VerbScreenState();
}

class _VerbScreenState extends State<VerbScreen> {
  VerbData? _data;
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VerbRepository.instance.loadVerbs();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final data = _data;
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            lang == 'ar'
                ? 'تصريف الأفعال'
                : lang == 'es'
                ? 'Conjugación de Verbos'
                : 'Verb Conjugations',
          ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText:
                              lang == 'ar'
                                  ? 'ابحث عن فعل...'
                                  : lang == 'es'
                                  ? 'Buscar verbo...'
                                  : 'Search verb...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged:
                            (v) => setState(() => _query = v.toLowerCase()),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          ...data!.verbs
                              .where(
                                (v) =>
                                    _query.isEmpty ||
                                    v.inf.contains(_query) ||
                                    v.en.toLowerCase().contains(_query) ||
                                    v.ar.contains(_query),
                              )
                              .map(
                                (v) => Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                      child: Text(v.inf[0].toUpperCase()),
                                    ),
                                    title: Text(
                                      v.inf,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      lang == 'ar'
                                          ? v.ar
                                          : lang == 'es'
                                          ? v.en
                                          : v.en,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => VerbDetailScreen(
                                                  data: data,
                                                  verb: v,
                                                ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                          const CreditFooter(),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class VerbDetailScreen extends StatefulWidget {
  final VerbData data;
  final VerbInfo verb;
  const VerbDetailScreen({super.key, required this.data, required this.verb});

  @override
  State<VerbDetailScreen> createState() => _VerbDetailScreenState();
}

class _VerbDetailScreenState extends State<VerbDetailScreen> {
  int _tenseIndex = 0;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final tense = widget.data.tenses[_tenseIndex];
    final forms = widget.verb.conjugation(tense.id);
    final title =
        lang == 'ar'
            ? widget.verb.ar
            : lang == 'es'
            ? widget.verb.inf
            : widget.verb.inf;

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.quiz),
              tooltip: 'Conjugation Quiz',
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => VerbQuizScreen(
                            verb: widget.verb,
                            tenseId: widget.data.tenses[_tenseIndex].id,
                          ),
                    ),
                  ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                lang == 'ar' ? widget.verb.en : widget.verb.en,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.data.tenses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = widget.data.tenses[i];
                  final selected = i == _tenseIndex;
                  return ChoiceChip(
                    label: Text(
                      lang == 'ar'
                          ? t.label.ar
                          : lang == 'es'
                          ? t.label.es
                          : t.label.en,
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _tenseIndex = i),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: widget.data.persons.length + 1,
                itemBuilder: (context, i) {
                  if (i == widget.data.persons.length) {
                    return const CreditFooter();
                  }
                  final person = widget.data.persons[i];
                  final form = forms.length > i ? forms[i] : '';
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(
                        lang == 'es' ? '$person $form' : '$form ($person)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        tense.tr(lang),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing:
                          form.isEmpty
                              ? null
                              : AudioButton(
                                text: form,
                                lang: 'es',
                                compact: true,
                              ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on TenseInfo {
  String tr(String lang) {
    switch (lang) {
      case 'ar':
        return label.ar;
      case 'en':
        return label.en;
      default:
        return label.es;
    }
  }
}

class VerbQuizScreen extends StatefulWidget {
  final VerbInfo verb;
  final String tenseId;
  const VerbQuizScreen({super.key, required this.verb, required this.tenseId});

  @override
  State<VerbQuizScreen> createState() => _VerbQuizScreenState();
}

class _VerbQuizScreenState extends State<VerbQuizScreen> {
  int _index = 0;
  String? _selected;
  bool _revealed = false;
  int _score = 0;
  int _total = 0;
  bool _finished = false;
  final List<_QuizQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _buildQuestions();
  }

  void _buildQuestions() {
    final forms = widget.verb.conjugation(widget.tenseId);
    final persons = [
      'yo',
      'tú',
      'él/ella',
      'nosotros',
      'ustedes',
      'ellos/ellas',
    ];
    for (int i = 0; i < forms.length; i++) {
      final correct = forms[i];
      if (correct.isEmpty) continue;
      // Build 3 distractors from other persons in same tense
      final otherForms =
          forms.where((f) => f != correct && f.isNotEmpty).toList();
      otherForms.shuffle(Random());
      final options = <String>[correct];
      for (final f in otherForms.take(2)) {
        options.add(f);
      }
      options.shuffle(Random());
      _questions.add(
        _QuizQuestion(person: persons[i], correct: correct, options: options),
      );
    }
    _questions.shuffle(Random());
    _total = _questions.length;
  }

  void _answer(String ans) {
    setState(() {
      _selected = ans;
      _revealed = true;
      if (ans == _questions[_index].correct) _score++;
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _revealed = false;
      if (_index >= _questions.length) _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final tenseLabel =
        widget.verb.conjugation(widget.tenseId).isNotEmpty
            ? widget.tenseId
            : 'quiz';

    if (_finished) {
      return AppSelectionArea(
        child: Scaffold(
          appBar: AppBar(title: Text('Quiz Result')),
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _score * 10 >= 60
                              ? Icons.emoji_events
                              : Icons.menu_book,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_score/$_total',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            lang == 'ar'
                                ? 'إنهاء'
                                : lang == 'es'
                                ? 'Terminar'
                                : 'Done',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const CreditFooter(),
            ],
          ),
        ),
      );
    }

    final q = _questions[_index];
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.verb.inf} · $tenseLabel · ${_index + 1}/$_total',
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${q.person}: ___',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...q.options.map(
              (o) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: OutlinedButton(
                  onPressed: _revealed ? null : () => _answer(o),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _revealed && o == q.correct
                            ? Colors.green.withValues(alpha: 0.2)
                            : _revealed && _selected == o
                            ? Colors.red.withValues(alpha: 0.2)
                            : null,
                    side: BorderSide(
                      color:
                          _revealed && o == q.correct
                              ? Colors.green
                              : _revealed && _selected == o
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                  child: Text(o),
                ),
              ),
            ),
            const Spacer(),
            if (_revealed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    lang == 'ar'
                        ? 'التالي'
                        : lang == 'es'
                        ? 'Siguiente'
                        : 'Next',
                  ),
                ),
              ),
            const CreditFooter(),
          ],
        ),
      ),
    );
  }
}

class _QuizQuestion {
  final String person;
  final String correct;
  final List<String> options;
  _QuizQuestion({
    required this.person,
    required this.correct,
    required this.options,
  });
}
