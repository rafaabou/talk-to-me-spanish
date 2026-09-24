import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/verb_models.dart';
import '../services/app_state.dart';
import '../services/progress_service.dart';
import '../services/verb_repository.dart';
import '../widgets/audio_button.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../services/ui_text.dart';

class VerbScreen extends StatefulWidget {
  const VerbScreen({super.key});

  @override
  State<VerbScreen> createState() => _VerbScreenState();
}

class _VerbScreenState extends State<VerbScreen> {
  VerbData? _data;
  String _query = '';
  bool _loading = true;
  bool _audioOnly = false;
  bool _showCommonOnly = false;
  bool _favoritesOnly = false;
  Set<String> _favorites = {};

  /// Verb favorites share the progress store with word favorites, namespaced
  /// so `hablar` and an English word can never collide.
  static String verbFavoriteKey(String infinitive) => 'verb:$infinitive';

  Future<void> _loadFavorites() async {
    final favorites = await ProgressService.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favorites.where((k) => k.startsWith('verb:')).toSet();
    });
  }

  Future<void> _toggleVerbFavorite(String infinitive) async {
    final key = verbFavoriteKey(infinitive);
    await ProgressService.instance.toggleFavorite(key);
    if (!mounted) return;
    setState(() {
      if (_favorites.contains(key)) {
        _favorites = {..._favorites}..remove(key);
      } else {
        _favorites = {..._favorites, key};
      }
    });
  }

  static const _commonVerbs = {
    'ser',
    'estar',
    'ter',
    'ir',
    'fazer',
    'poder',
    'dizer',
    'saber',
    'querer',
    'ver',
    'dar',
    'ficar',
    'haver',
    'deixar',
    'passar',
    'trazer',
    'começar',
    'partir',
    'achar',
    'esperar',
    'voltar',
    'chamar',
    'viver',
    'sentir',
    'olhar',
    'gostar',
    'jogar',
    'contar',
    'andar',
    'trabalhar',
    'estudar',
    'falar',
    'comer',
    'beber',
    'dormir',
    'abrir',
    'fechar',
    'correr',
    'ler',
    'escrever',
    'comprar',
    'vender',
    'pagar',
    'receber',
    'tomar',
    'usar',
    'precisar',
    'tentar',
    'entender',
    'lembrar',
  };

  @override
  void initState() {
    super.initState();
    _load();
    _loadFavorites();
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
            uiText(
              lang,
              ar: 'تصريف الأفعال',
              es: 'Conjugación de Verbos',
              other: 'Verb Conjugations',
            ),
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
                          hintText: uiText(
                            lang,
                            ar: 'ابحث عن فعل...',
                            es: 'Buscar verbo...',
                            other: 'Search verb...',
                          ),
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
                    _buildAudioFilter(data!, lang),
                    Expanded(child: _buildGroupedList(data, lang)),
                  ],
                ),
      ),
    );
  }

  Widget _buildAudioFilter(VerbData data, String lang) {
    final total = data.verbs.length;
    final favoriteCount =
        data.verbs
            .where((v) => _favorites.contains(verbFavoriteKey(v.inf)))
            .length;
    final withAudio = data.verbs.where((v) => v.hasFullAudio).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(
                uiText(
                  lang,
                  ar: 'الأكثر شيوعاً',
                  es: 'Más comunes',
                  other: 'Common',
                ),
              ),
              selected: _showCommonOnly,
              onSelected:
                  (_) => setState(() {
                    _showCommonOnly = !_showCommonOnly;
                    _audioOnly = false;
                    _favoritesOnly = false;
                  }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(
                uiText(
                  lang,
                  ar: 'الكل ($total)',
                  es: 'Todos ($total)',
                  other: 'All ($total)',
                ),
              ),
              selected: !_audioOnly && !_showCommonOnly && !_favoritesOnly,
              onSelected:
                  (_) => setState(() {
                    _audioOnly = false;
                    _showCommonOnly = false;
                    _favoritesOnly = false;
                  }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.volume_up, size: 18),
              label: Text(
                uiText(
                  lang,
                  ar: 'صوت ($withAudio)',
                  es: 'Con Audio ($withAudio)',
                  other: 'Audio ($withAudio)',
                ),
              ),
              selected: _audioOnly,
              onSelected:
                  (_) => setState(() {
                    _audioOnly = true;
                    _showCommonOnly = false;
                    _favoritesOnly = false;
                  }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.star, size: 18),
              label: Text(
                uiText(
                  lang,
                  ar: 'المفضلة ($favoriteCount)',
                  es: 'Favoritos ($favoriteCount)',
                  other: 'Favorites ($favoriteCount)',
                ),
              ),
              selected: _favoritesOnly,
              onSelected:
                  (_) => setState(() {
                    _favoritesOnly = !_favoritesOnly;
                    _audioOnly = false;
                    _showCommonOnly = false;
                  }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(VerbData data, String lang) {
    List<VerbInfo> verbs =
        _favoritesOnly
            ? data.verbs
                .where((v) => _favorites.contains(verbFavoriteKey(v.inf)))
                .toList()
            : _audioOnly
            ? data.verbs.where((v) => v.hasFullAudio).toList()
            : _showCommonOnly
            ? data.verbs.where((v) => _commonVerbs.contains(v.inf)).toList()
            : data.verbs;

    if (_query.isNotEmpty) {
      final results =
          verbs
              .where(
                (v) =>
                    v.inf.contains(_query) ||
                    v.en.toLowerCase().contains(_query) ||
                    v.ar.contains(_query),
              )
              .toList();
      return ListView(
        children: [
          ...results.map((v) => _verbTile(data, v, lang)),
          const CreditFooter(),
        ],
      );
    }

    if (_audioOnly) {
      return ListView(
        children: [
          ...verbs.map((v) => _verbTile(data, v, lang)),
          const CreditFooter(),
        ],
      );
    }

    final groups = data.conjGroups;
    if (groups.isEmpty) {
      return ListView(
        children: [
          ...verbs.map((v) => _verbTile(data, v, lang)),
          const CreditFooter(),
        ],
      );
    }

    return ListView(
      children: [
        for (final entry in groups.entries) ...[
          _sectionHeader(entry.key, entry.value.length, lang),
          ...entry.value
              .map((inf) => data.verbs.firstWhere((v) => v.inf == inf))
              .map((v) => _verbTile(data, v, lang)),
        ],
        const CreditFooter(),
      ],
    );
  }

  Widget _sectionHeader(String conjType, int count, String lang) {
    final label = 'Verbos -${conjType.toUpperCase()} ($count)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _verbTile(VerbData data, VerbInfo v, String lang) {
    final typeColors = {
      '-AR': Colors.blue,
      '-ER': Colors.orange,
      '-IR': Colors.green,
      '-OR': Colors.purple,
    };
    final badge =
        typeColors.entries
            .where((e) => v.inf.endsWith(e.key.substring(1).toLowerCase()))
            .map((e) => e.value)
            .firstOrNull;
    final isCommon = _commonVerbs.contains(v.inf);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              badge != null
                  ? badge.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.primaryContainer,
          child:
              v.hasFullAudio
                  ? const Icon(Icons.volume_up, size: 20)
                  : Text(
                    v.inf[0].toUpperCase(),
                    style: TextStyle(color: badge, fontWeight: FontWeight.bold),
                  ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                v.inf,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_favorites.contains(verbFavoriteKey(v.inf)))
              const Icon(Icons.star, size: 20, color: Colors.amber),
            if (isCommon) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  uiText(lang, ar: 'شائع', es: 'Común', other: 'Common'),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text('${v.en} · ${v.ar}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _favorites.contains(verbFavoriteKey(v.inf))
                    ? Icons.star
                    : Icons.star_border,
                color:
                    _favorites.contains(verbFavoriteKey(v.inf))
                        ? Colors.amber
                        : null,
              ),
              tooltip: uiText(
                lang,
                ar: 'أضف إلى المفضلة',
                es: 'Añadir a favoritos',
                other: 'Add to favorites',
              ),
              onPressed: () => _toggleVerbFavorite(v.inf),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerbDetailScreen(data: data, verb: v),
              ),
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

  Widget _verbSummaryHeader(VerbData data, String lang) {
    final v = widget.verb;
    final typeColors = {
      '-AR': Colors.blue,
      '-ER': Colors.orange,
      '-IR': Colors.green,
      '-OR': Colors.purple,
    };
    final badgeColor =
        typeColors.entries
            .where((e) => v.inf.endsWith(e.key.substring(1).toLowerCase()))
            .map((e) => e.value)
            .firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                v.inf,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              if (badgeColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    v.conjType.toUpperCase(),
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              const Spacer(),
              AudioButton(text: v.inf, lang: 'es', compact: false),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${v.en} · ${v.ar}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => VerbQuizScreen(
                              verb: v,
                              tenseId: data.tenses[_tenseIndex].id,
                            ),
                      ),
                    ),
                icon: const Icon(Icons.quiz, size: 18),
                label: Text(
                  uiText(lang, ar: 'اختبار', es: 'Quiz', other: 'Quiz'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final tense = widget.data.tenses[_tenseIndex];
    final forms = widget.verb.conjugation(tense.id);

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.verb.inf),
          actions: [
            IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: uiText(
                lang,
                ar: 'استمع',
                es: 'Escuchar',
                other: 'Listen',
              ),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            _verbSummaryHeader(widget.data, lang),
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
                                text:
                                    widget.verb.hasFullAudio
                                        ? form
                                        : widget.verb.inf,
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
          appBar: AppBar(title: const Text('Quiz Result')),
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
                            uiText(
                              lang,
                              ar: 'إنهاء',
                              es: 'Terminar',
                              other: 'Done',
                            ),
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
                    uiText(lang, ar: 'التالي', es: 'Siguiente', other: 'Next'),
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
