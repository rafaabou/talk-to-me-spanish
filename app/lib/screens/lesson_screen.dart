import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/pdf_export_service.dart';
import '../services/progress_service.dart';
import '../widgets/audio_button.dart';
import '../widgets/tr_text.dart';
import '../widgets/tri_block.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';

class LessonScreen extends StatefulWidget {
  final String lessonId;
  const LessonScreen({super.key, required this.lessonId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Lesson? _lesson;
  bool _loading = true;
  List<String> _siblings = [];
  int _siblingIndex = 0;
  Set<String> _doneExercises = {};
  Set<String> _favorites = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lesson = await CourseRepository.instance.tryLoadLesson(
      widget.lessonId,
    );
    final siblings = await _loadSiblings(widget.lessonId);
    final doneExercises =
        await ProgressService.instance.getCompletedExercises();
    final favorites = await ProgressService.instance.getFavorites();
    ProgressService.instance.setLastOpened(widget.lessonId);
    if (!mounted) return;
    setState(() {
      _lesson = lesson;
      _siblings = siblings;
      _siblingIndex = siblings.indexOf(widget.lessonId);
      _doneExercises = doneExercises;
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<List<String>> _loadSiblings(String lessonId) async {
    final levels = await CourseRepository.instance.loadLevels();
    final levelId = lessonId.split('-').first;
    final level = levels[levelId];
    if (level == null) return [];
    return level.lessons.map((l) => l['id'] as String).toList();
  }

  Future<void> _goTo(String id) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LessonScreen(lessonId: id)),
    );
  }

  Future<void> _markComplete() async {
    await ProgressService.instance.markCompleted(widget.lessonId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('✓'), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _exportPdf() async {
    try {
      final path = await PdfExportService.instance.exportLessonToPdf(
        lessonId: widget.lessonId,
        appState: context.read<AppState>(),
      );
      if (!mounted) return;
      await PdfExportService.instance.sharePdf(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSearch() {
    final lesson = _lesson;
    if (lesson == null) return;
    final lang = context.read<AppState>().lang;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => _LessonSearchSheet(
            lesson: lesson,
            lang: lang,
            onSelect: (section, index) {
              Navigator.pop(ctx);
              _scrollToSection(section, index);
            },
          ),
    );
  }

  void _scrollToSection(String section, int index) {
    // For now just scroll to approximate position
    // Could be enhanced with GlobalKeys per section
    double offset = 0;
    switch (section) {
      case 'vocab':
        offset = index * 72.0;
        break;
      case 'grammar':
        offset = 300 + index * 120.0;
        break;
      case 'dialogue':
        offset = 600 + index * 60.0;
        break;
      case 'reading':
        offset = 800;
        break;
      case 'exercises':
        offset = 900 + index * 100.0;
        break;
    }
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    if (_loading) {
      return AppSelectionArea(
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final lesson = _lesson;
    if (lesson == null) {
      return AppSelectionArea(
        child: Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Text('Lesson not found', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(lesson.title.tr(lang)),
          actions: [
            if (_siblingIndex > 0)
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous',
                onPressed: () => _goTo(_siblings[_siblingIndex - 1]),
              ),
            if (_siblingIndex >= 0 && _siblingIndex < _siblings.length - 1)
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next',
                onPressed: () => _goTo(_siblings[_siblingIndex + 1]),
              ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Mark complete',
              onPressed: _markComplete,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search in lesson',
              onPressed: _showSearch,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _exportPdf,
            ),
          ],
        ),
        body: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          children: [
            _SectionTitle('${lesson.level} · ${lesson.id}'),
            const SizedBox(height: 8),
            // Objectives
            _SectionHeader(
              lang == 'ar'
                  ? 'الأهداف'
                  : lang == 'es'
                  ? 'Objetivos'
                  : 'Objectives',
            ),
            ...lesson.objectives.map(
              (o) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: TrText(o, lang)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Vocabulary
            _SectionHeader(
              lang == 'ar'
                  ? 'المفردات'
                  : lang == 'es'
                  ? 'Vocabulario'
                  : 'Vocabulary',
            ),
            ...lesson.vocabulary.asMap().entries.map(
              (e) => _VocabTile(
                lesson.id,
                e.key,
                e.value,
                lang,
                isFavorite: _favorites.contains('${lesson.id}::${e.key}'),
                onToggleFavorite: () async {
                  await ProgressService.instance.toggleFavorite(
                    '${lesson.id}::${e.key}',
                  );
                  setState(() {
                    _favorites =
                        _favorites.contains('${lesson.id}::${e.key}')
                            ? _favorites.difference({
                              ('${lesson.id}::${e.key}'),
                            })
                            : {..._favorites, '${lesson.id}::${e.key}'};
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            // Grammar
            _SectionHeader(
              lang == 'ar'
                  ? 'القواعد'
                  : lang == 'es'
                  ? 'Gramática'
                  : 'Grammar',
            ),
            ...lesson.grammar.map((g) => _GrammarTile(g, lang)),
            const SizedBox(height: 12),
            // Dialogue
            if (lesson.dialogueLines.isNotEmpty) ...[
              _SectionHeader(
                lang == 'ar'
                    ? 'الحوار'
                    : lang == 'es'
                    ? 'Diálogo'
                    : 'Dialogue',
              ),
              ...lesson.dialogueLines.map((l) => _DialogueLineTile(l, lang)),
            ],
            const SizedBox(height: 12),
            // Reading
            if (lesson.readingText != null) ...[
              _SectionHeader(
                lang == 'ar'
                    ? 'القراءة'
                    : lang == 'es'
                    ? 'Lectura'
                    : 'Reading',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.readingText!.es,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          AudioButton(text: lesson.readingText!.es, lang: 'es'),
                        ],
                      ),
                      if (lesson.readingText!.en.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          lesson.readingText!.en,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (lesson.readingText!.ar.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          lesson.readingText!.ar,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Lesson Notes
            _LessonNotesSection(lessonId: lesson.id, lang: lang),
            const SizedBox(height: 12),
            // Cultural Tips
            if (lesson.culturalTips != null &&
                lesson.culturalTips!.es.isNotEmpty) ...[
              _SectionHeader(
                lang == 'ar'
                    ? 'نصيحة ثقافية'
                    : lang == 'es'
                    ? 'Dato Cultural'
                    : 'Cultural Tip',
              ),
              _CulturalTipsSection(tips: lesson.culturalTips!, lang: lang),
              const SizedBox(height: 12),
            ],
            // Speaking
            if (lesson.speaking.isNotEmpty) ...[
              _SectionHeader(
                lang == 'ar'
                    ? 'تحدث الآن'
                    : lang == 'es'
                    ? 'Habla Ahora'
                    : 'Speaking',
              ),
              _SpeakingSection(items: lesson.speaking, lang: lang),
            ],
            const SizedBox(height: 12),
            // Exercises
            _SectionHeader(
              lang == 'ar'
                  ? 'التمارين'
                  : lang == 'es'
                  ? 'Ejercicios'
                  : 'Exercises',
            ),
            ...lesson.exercises.asMap().entries.map(
              (e) => _ExerciseTile(
                lesson.id,
                e.key,
                e.value,
                lang,
                isDone: _doneExercises.contains('${lesson.id}::${e.key}'),
                onToggleDone: () async {
                  await ProgressService.instance.toggleExerciseDone(
                    '${lesson.id}::${e.key}',
                  );
                  setState(() {
                    _doneExercises =
                        _doneExercises.contains('${lesson.id}::${e.key}')
                            ? _doneExercises.difference({
                              ('${lesson.id}::${e.key}'),
                            })
                            : {..._doneExercises, '${lesson.id}::${e.key}'};
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _markComplete,
              icon: const Icon(Icons.check),
              label: Text(
                lang == 'ar'
                    ? 'إكمال الدرس'
                    : lang == 'es'
                    ? 'Marcar lección completada'
                    : 'Mark lesson complete',
              ),
            ),
            const CreditFooter(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class _VocabTile extends StatelessWidget {
  final String lessonId;
  final int index;
  final VocabWord v;
  final String lang;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _VocabTile(
    this.lessonId,
    this.index,
    this.v,
    this.lang, {
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                v.es,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (v.ipa.isNotEmpty)
              Text(v.ipa, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${v.tr(lang)}'
              '${lang == 'en' && v.ar.isNotEmpty ? ' · ${v.ar}' : ''}',
            ),
            if (v.example != null) ...[
              const SizedBox(height: 2),
              Text(
                v.example!.es,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
              Text(
                lang == 'ar' ? v.example!.ar : v.example!.en,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AudioButton(text: v.es, lang: 'es'),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : null,
              ),
              tooltip: 'Favorite',
              onPressed: onToggleFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

class _GrammarTile extends StatelessWidget {
  final GrammarSection g;
  final String lang;
  const _GrammarTile(this.g, this.lang);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          g.title.tr(lang),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TriBlock(g.explanation),
          ),
          ...g.examples.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TriBlock(e, audio: true, compact: true),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DialogueLineTile extends StatelessWidget {
  final DialogueLine l;
  final String lang;
  const _DialogueLineTile(this.l, this.lang);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            radius: 16,
            child: Text(l.speaker.isNotEmpty ? l.speaker[0] : '?'),
          ),
          title: TriBlock(l.text),
          trailing: AudioButton(text: l.text.es, lang: 'es'),
        ),
      ),
    );
  }
}

class _SpeakingSection extends StatefulWidget {
  final List<SpeakingItem> items;
  final String lang;
  const _SpeakingSection({required this.items, required this.lang});

  @override
  State<_SpeakingSection> createState() => _SpeakingSectionState();
}

class _SpeakingSectionState extends State<_SpeakingSection> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'ar'
                  ? 'كرر الجمل بصوت عالٍ بعد الاستماع'
                  : lang == 'es'
                  ? 'Repite cada frase en voz alta después de escuchar'
                  : 'Repeat each phrase aloud after listening',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...widget.items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final done = _done.contains(i);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.record_voice_over,
                      size: 20,
                      color:
                          done
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: TriBlock(item.text, compact: true)),
                    AudioButton(text: item.text.es, lang: 'es', compact: true),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip:
                          lang == 'ar'
                              ? 'تم'
                              : lang == 'es'
                              ? 'Lo logré'
                              : 'Got it',
                      onPressed: () => setState(() => _done.add(i)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '${_done.length}/${widget.items.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonNotesSection extends StatefulWidget {
  final String lessonId;
  final String lang;
  const _LessonNotesSection({required this.lessonId, required this.lang});

  @override
  State<_LessonNotesSection> createState() => _LessonNotesSectionState();
}

class _LessonNotesSectionState extends State<_LessonNotesSection> {
  bool _loading = true;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await ProgressService.instance.getLessonNotes(
      widget.lessonId,
    );
    if (!mounted) return;
    setState(() {
      _controller.text = notes;
      _loading = false;
    });
  }

  Future<void> _saveNotes() async {
    await ProgressService.instance.setLessonNotes(
      widget.lessonId,
      _controller.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.lang == 'ar'
              ? 'تم حفظ الملاحظات'
              : widget.lang == 'es'
              ? 'Notas salvas'
              : 'Notes saved',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  lang == 'ar'
                      ? 'ملاحظاتي'
                      : lang == 'es'
                      ? 'Mis Notas'
                      : 'My Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          lang == 'ar'
                              ? 'اكتب ملاحظاتك هنا...'
                              : lang == 'es'
                              ? 'Escribe tus notas aquí...'
                              : 'Write your notes here...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _controller.clear();
                          _saveNotes();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          lang == 'ar'
                              ? 'مسح'
                              : lang == 'es'
                              ? 'Limpiar'
                              : 'Clear',
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saveNotes,
                        icon: const Icon(Icons.save),
                        label: Text(
                          lang == 'ar'
                              ? 'حفظ'
                              : lang == 'es'
                              ? 'Guardar'
                              : 'Save',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CulturalTipsSection extends StatelessWidget {
  final TriText tips;
  final String lang;
  const _CulturalTipsSection({required this.tips, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  lang == 'ar'
                      ? 'نصيحة ثقافية'
                      : lang == 'es'
                      ? 'Dato Cultural'
                      : 'Cultural Tip',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(tips.tr(lang), style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ReorderItem {
  final String text;
  bool dragging = false;
  _ReorderItem({required this.text});
}

class _MatchPair {
  final String left;
  final String right;
  final String correctRight;
  bool selected = false;
  _MatchPair({
    required this.left,
    required this.right,
    required this.correctRight,
  });
}

class _ExerciseTile extends StatefulWidget {
  final String lessonId;
  final int index;
  final Exercise e;
  final String lang;
  final bool isDone;
  final VoidCallback onToggleDone;
  const _ExerciseTile(
    this.lessonId,
    this.index,
    this.e,
    this.lang, {
    required this.isDone,
    required this.onToggleDone,
  });

  @override
  State<_ExerciseTile> createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<_ExerciseTile> {
  String? _selected;
  bool _revealed = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isMC =>
      widget.e.type == 'multiple_choice' ||
      widget.e.type == 'fill_blank' ||
      widget.e.type == 'listening' ||
      widget.e.type == 'listening_mcq';

  bool get _isReorder => widget.e.type == 'sentence_reorder';

  bool get _isMatchPairs => widget.e.type == 'match_pairs';

  bool get _isListeningMCQ => widget.e.type == 'listening_mcq';

  List<String> get _reorderWords {
    final scrambled = widget.e.options.map((o) => o.es).toList();
    return scrambled;
  }

  List<String> get _matchLeft {
    if (widget.e.type != 'match_pairs') return [];
    final pairs = widget.e.answer.split('|');
    return pairs.map((p) => p.split('::').first).toList();
  }

  List<String> get _matchRight {
    if (widget.e.type != 'match_pairs') return [];
    final pairs = widget.e.answer.split('|');
    final right = pairs.map((p) => p.split('::').last).toList();
    final shuffled = List<String>.from(right)..shuffle();
    return shuffled;
  }

  List<_ReorderItem> _reorderState = [];
  List<_MatchPair> _matchState = [];

  @override
  void initState() {
    super.initState();
    _initReorder();
    _initMatchPairs();
  }

  void _initReorder() {
    if (!_isReorder) return;
    _reorderState = _reorderWords.map((w) => _ReorderItem(text: w)).toList();
  }

  void _initMatchPairs() {
    if (!_isMatchPairs) return;
    final left = _matchLeft;
    final right = _matchRight;
    _matchState = List.generate(
      left.length,
      (i) => _MatchPair(
        left: left[i],
        right: right[i],
        correctRight: left.length > i ? _getCorrectRight(left[i]) : '',
      ),
    );
  }

  String _getCorrectRight(String left) {
    final pairs = widget.e.answer.split('|');
    for (final p in pairs) {
      final parts = p.split('::');
      if (parts.length == 2 && parts[0] == left) return parts[1];
    }
    return '';
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final item = _reorderState.removeAt(oldIndex);
      _reorderState.insert(newIndex, item);
    });
  }

  void _onMatchTap(int index) {
    setState(() {
      _matchState[index].selected = !_matchState[index].selected;
    });
  }

  bool _checkReorder() {
    final userOrder = _reorderState.map((i) => i.text).join(' ');
    final correct = widget.e.answer;
    return _normalize(userOrder) == _normalize(correct);
  }

  bool _checkMatchPairs() {
    for (final m in _matchState) {
      if (m.selected && m.right != m.correctRight) return false;
      if (!m.selected && m.right == m.correctRight) return false;
    }
    return true;
  }

  void _submitAnswer(String selected) {
    setState(() {
      _selected = selected;
      _revealed = true;
    });
    bool correct = false;
    if (_isMC) {
      correct = selected == widget.e.answer;
    } else if (_isReorder) {
      correct = _checkReorder();
    } else if (_isMatchPairs) {
      correct = _checkMatchPairs();
    } else if (_isListeningMCQ) {
      correct = selected == widget.e.answer;
    } else {
      correct = _checkAnswer(selected);
    }
    if (correct && !widget.isDone) {
      widget.onToggleDone();
    }
  }

  String _normalize(String s) {
    final out = StringBuffer();
    for (final rune in s.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      if (c.codeUnitAt(0) < 32) continue;
      out.write(_stripAccents(c));
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripAccents(String c) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final idx = from.indexOf(c);
    return idx >= 0 ? to[idx] : c;
  }

  bool _checkAnswer(String input) {
    final norm = _normalize(input);
    if (norm.isEmpty) return false;
    final e = widget.e;
    final answers = <String>{_normalize(e.answer)};
    if (e.answer.contains('/')) {
      for (final a in e.answer.split('/')) {
        answers.add(_normalize(a));
      }
    }
    for (final a in e.accepted) {
      answers.add(_normalize(a));
    }
    return answers.contains(norm);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final lang = widget.lang;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.type == 'listening' ||
                    e.type == 'dictation' ||
                    _isListeningMCQ) ...[
                  AudioButton(text: e.audio ?? e.answer, lang: 'es'),
                  const SizedBox(width: 8),
                ],
                Expanded(child: TriBlock(e.prompt)),
                if (widget.isDone)
                  const Icon(Icons.check_circle, color: Colors.green),
                if (widget.isDone)
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Reset',
                    onPressed: widget.onToggleDone,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isReorder)
              _buildReorder(context, lang)
            else if (_isMatchPairs)
              _buildMatchPairs(context, lang)
            else if (_isMC)
              ...e.options.map(
                (o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: OutlinedButton(
                    onPressed: () => _submitAnswer(o.es),
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            o.tr(lang),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (o.en.isNotEmpty && o.en != o.es) ...[
                            const SizedBox(height: 2),
                            Text(
                              o.en,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (o.ar.isNotEmpty && o.ar != o.es) ...[
                            const SizedBox(height: 2),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                o.ar,
                                style: Theme.of(context).textTheme.bodySmall,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: '...'),
                onSubmitted: (v) => _submitAnswer(v),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => _submitAnswer(_controller.text),
                child: Text(
                  lang == 'ar'
                      ? 'تحقق'
                      : lang == 'es'
                      ? 'Comprobar'
                      : 'Check',
                ),
              ),
            ],
            if (_revealed) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    (_isReorder
                            ? _checkReorder()
                            : _isMatchPairs
                            ? _checkMatchPairs()
                            : _isMC
                            ? _selected == e.answer
                            : _checkAnswer(_selected ?? ''))
                        ? Icons.check_circle
                        : Icons.cancel,
                    color:
                        (_isReorder
                                ? _checkReorder()
                                : _isMatchPairs
                                ? _checkMatchPairs()
                                : _isMC
                                ? _selected == e.answer
                                : _checkAnswer(_selected ?? ''))
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TriBlock(e.explanation),
                        if (!_isMC && !_isReorder && !_isMatchPairs) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                e.answer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              AudioButton(
                                text: e.answer.split('/')[0],
                                lang: 'es',
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                        if (_isReorder || _isMatchPairs) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                e.answer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              AudioButton(
                                text: e.answer.split('/')[0],
                                lang: 'es',
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReorder(BuildContext context, String lang) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: _onReorder,
      children:
          _reorderState.asMap().entries.map((entry) {
            final item = entry.value;
            return Card(
              key: ValueKey(item.text),
              child: ListTile(
                leading: const Icon(Icons.drag_handle),
                title: Text(
                  item.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing:
                    item.dragging ? const Icon(Icons.drag_indicator) : null,
              ),
            );
          }).toList(),
    );
  }

  Widget _buildMatchPairs(BuildContext context, String lang) {
    return Column(
      children:
          _matchState.asMap().entries.map((entry) {
            final index = entry.key;
            final pair = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Text(
                  pair.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                title: GestureDetector(
                  onTap: () => _onMatchTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          pair.selected
                              ? (pair.right == pair.correctRight
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2))
                              : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color:
                            pair.selected
                                ? (pair.right == pair.correctRight
                                    ? Colors.green
                                    : Colors.red)
                                : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pair.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            pair.selected ? FontWeight.bold : FontWeight.normal,
                        color:
                            pair.selected
                                ? (pair.right == pair.correctRight
                                    ? Colors.green
                                    : Colors.red)
                                : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
                trailing:
                    pair.selected
                        ? Icon(
                          pair.right == pair.correctRight
                              ? Icons.check_circle
                              : Icons.cancel,
                          color:
                              pair.right == pair.correctRight
                                  ? Colors.green
                                  : Colors.red,
                        )
                        : null,
              ),
            );
          }).toList(),
    );
  }
}

class _LessonSearchSheet extends StatefulWidget {
  final Lesson lesson;
  final String lang;
  final void Function(String section, int index) onSelect;
  const _LessonSearchSheet({
    required this.lesson,
    required this.lang,
    required this.onSelect,
  });

  @override
  State<_LessonSearchSheet> createState() => _LessonSearchSheetState();
}

class _LessonSearchSheetState extends State<_LessonSearchSheet> {
  final _controller = TextEditingController();
  List<_SearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final lesson = widget.lesson;
    final lang = widget.lang;
    final results = <_SearchResult>[];

    // Search vocabulary
    for (int i = 0; i < lesson.vocabulary.length; i++) {
      final v = lesson.vocabulary[i];
      if (v.es.toLowerCase().contains(query) ||
          v.en.toLowerCase().contains(query) ||
          v.ar.toLowerCase().contains(query) ||
          (v.example?.es.toLowerCase().contains(query) ?? false) ||
          (v.example?.en.toLowerCase().contains(query) ?? false)) {
        results.add(
          _SearchResult(
            section: 'vocab',
            index: i,
            title: v.es,
            subtitle: v.tr(lang),
          ),
        );
      }
    }

    // Search grammar
    for (int i = 0; i < lesson.grammar.length; i++) {
      final g = lesson.grammar[i];
      if (g.title.tr(lang).toLowerCase().contains(query) ||
          g.explanation.tr(lang).toLowerCase().contains(query) ||
          g.examples.any((ex) => ex.es.toLowerCase().contains(query))) {
        results.add(
          _SearchResult(
            section: 'grammar',
            index: i,
            title: g.title.tr(lang),
            subtitle: g.explanation.tr(lang),
          ),
        );
      }
    }

    // Search dialogue
    for (int i = 0; i < lesson.dialogueLines.length; i++) {
      final d = lesson.dialogueLines[i];
      if (d.text.es.toLowerCase().contains(query) ||
          d.text.en.toLowerCase().contains(query) ||
          d.text.ar.toLowerCase().contains(query)) {
        results.add(
          _SearchResult(
            section: 'dialogue',
            index: i,
            title: '${d.speaker}: ${d.text.es}',
            subtitle: d.text.tr(lang),
          ),
        );
      }
    }

    // Search reading
    if (lesson.readingText != null) {
      final r = lesson.readingText!;
      if (r.es.toLowerCase().contains(query) ||
          r.en.toLowerCase().contains(query) ||
          r.ar.toLowerCase().contains(query)) {
        results.add(
          _SearchResult(
            section: 'reading',
            index: 0,
            title:
                widget.lang == 'ar'
                    ? 'النص القرائي'
                    : widget.lang == 'es'
                    ? 'Texto de Lectura'
                    : 'Reading Text',
            subtitle: r.tr(lang),
          ),
        );
      }
    }

    // Search exercises
    for (int i = 0; i < lesson.exercises.length; i++) {
      final e = lesson.exercises[i];
      if (e.prompt.es.toLowerCase().contains(query) ||
          e.prompt.en.toLowerCase().contains(query) ||
          e.prompt.ar.toLowerCase().contains(query) ||
          e.options.any((o) => o.es.toLowerCase().contains(query))) {
        results.add(
          _SearchResult(
            section: 'exercises',
            index: i,
            title:
                '${widget.lang == 'ar'
                    ? 'تمرين'
                    : widget.lang == 'es'
                    ? 'Exercício'
                    : 'Exercise'} ${i + 1}',
            subtitle: e.prompt.tr(lang),
          ),
        );
      }
    }

    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final t = _Translations(widget.lang);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder:
          (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.searchInLesson,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: t.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      _results.isEmpty && _controller.text.isNotEmpty
                          ? Center(child: Text(t.noResults))
                          : ListView.builder(
                            controller: scrollController,
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final r = _results[i];
                              return ListTile(
                                leading: _sectionIcon(r.section),
                                title: Text(r.title),
                                subtitle: Text(
                                  r.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap:
                                    () => widget.onSelect(r.section, r.index),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  Icon _sectionIcon(String section) {
    switch (section) {
      case 'vocab':
        return const Icon(Icons.menu_book);
      case 'grammar':
        return const Icon(Icons.rule);
      case 'dialogue':
        return const Icon(Icons.chat_bubble);
      case 'reading':
        return const Icon(Icons.article);
      case 'exercises':
        return const Icon(Icons.fitness_center);
      default:
        return const Icon(Icons.search);
    }
  }
}

class _SearchResult {
  final String section;
  final int index;
  final String title;
  final String subtitle;
  _SearchResult({
    required this.section,
    required this.index,
    required this.title,
    required this.subtitle,
  });
}

class _Translations {
  final String lang;
  _Translations(this.lang);
  String get searchInLesson =>
      lang == 'ar'
          ? 'البحث في الدرس'
          : lang == 'es'
          ? 'Buscar en la lección'
          : 'Search in lesson';
  String get searchHint =>
      lang == 'ar'
          ? 'اكتب للبحث...'
          : lang == 'es'
          ? 'Escribe para buscar...'
          : 'Type to search...';
  String get noResults =>
      lang == 'ar'
          ? 'لا توجد نتائج'
          : lang == 'es'
          ? 'Sin resultados'
          : 'No results';
}
