import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/exercise_dedup.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/pdf_export_service.dart';
import '../services/progress_service.dart';
import '../widgets/audio_button.dart';
import '../widgets/tr_text.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../widgets/text_size_sheet.dart';
import '../services/ui_text.dart';
import 'lesson_exercise_tile.dart';
import 'lesson_search_sheet.dart';
import 'lesson_sections.dart';
import 'conversation_screen.dart';
import '../services/conversation_turn_engine.dart';

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

  /// Original exercise index -> "n/total" position among the audio drills of
  /// its type, so repeated instructions stay distinguishable.
  Map<int, (int, int)> _drillOrdinals = {};
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
    final drillOrdinals =
        lesson == null
            ? <int, (int, int)>{}
            : audioDrillOrdinals(_visibleExercises(lesson));
    if (!mounted) return;
    setState(() {
      _lesson = lesson;
      _siblings = siblings;
      _siblingIndex = siblings.indexOf(widget.lessonId);
      _doneExercises = doneExercises;
      _favorites = favorites;
      _drillOrdinals = drillOrdinals;
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
      await PdfExportService.instance.exportLessonToPdf(
        lessonId: widget.lessonId,
        appState: context.read<AppState>(),
      );
      if (!mounted) return;
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
          (ctx) => LessonSearchSheet(
            lesson: lesson,
            lang: lang,
            onSelect: (section, index) {
              Navigator.pop(ctx);
              _scrollToSection(section, index);
            },
          ),
    );
  }

  List<MapEntry<int, Exercise>> _visibleExercises(Lesson lesson) =>
      dedupeExercises(lesson.exercises, 'es');

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
          title: Text(lesson.title.tr(lang), overflow: TextOverflow.ellipsis),
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
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'search':
                    _showSearch();
                  case 'text_size':
                    TextSizeSheet.show(context);
                  case 'pdf':
                    _exportPdf();
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            uiText(
                              lang,
                              ar: 'بحث في الدرس',
                              es: 'Buscar en la lección',
                              other: 'Search in lesson',
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'text_size',
                      child: Row(
                        children: [
                          const Icon(Icons.text_fields, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            uiText(
                              lang,
                              ar: 'حجم النص',
                              es: 'Tamaño del texto',
                              other: 'Text size',
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            uiText(
                              lang,
                              ar: 'تصدير PDF',
                              es: 'Exportar PDF',
                              other: 'Export PDF',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
        body: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          children: [
            SectionTitle('${lesson.level} · ${lesson.id}'),
            const SizedBox(height: 8),
            // Objectives
            SectionHeader(
              uiText(lang, ar: 'الأهداف', es: 'Objetivos', other: 'Objectives'),
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
            SectionHeader(
              uiText(
                lang,
                ar: 'المفردات',
                es: 'Vocabulario',
                other: 'Vocabulary',
              ),
            ),
            ...lesson.vocabulary.asMap().entries.map(
              (e) => VocabTile(
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
            SectionHeader(
              uiText(lang, ar: 'القواعد', es: 'Gramática', other: 'Grammar'),
            ),
            ...lesson.grammar.map((g) => GrammarTile(g, lang)),
            const SizedBox(height: 12),
            // Dialogue
            if (lesson.dialogueLines.isNotEmpty) ...[
              SectionHeader(
                uiText(lang, ar: 'الحوار', es: 'Diálogo', other: 'Dialogue'),
              ),
              ...lesson.dialogueLines.map((l) => DialogueLineTile(l, lang)),
              const SizedBox(height: 4),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ConversationScreen(
                            lang: lang,
                            title:
                                lesson.dialogueTitle?.tr(lang) ??
                                uiText(
                                  lang,
                                  ar: 'المحادثة',
                                  es: 'Conversación',
                                  other: 'Conversation',
                                ),
                            turns: ConversationTurnEngine.build(
                              lines: lesson.dialogueLines,
                              exercises: lesson.exercises,
                              targetLang: 'es',
                            ),
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.record_voice_over),
                label: Text(
                  uiText(
                    lang,
                    ar: 'تدرب على المحادثة',
                    es: 'Practicar conversación',
                    other: 'Practice conversation',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Reading
            if (lesson.readingText != null) ...[
              SectionHeader(
                uiText(lang, ar: 'القراءة', es: 'Lectura', other: 'Reading'),
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
            LessonNotesSection(lessonId: lesson.id, lang: lang),
            const SizedBox(height: 12),
            // Cultural Tips
            if (lesson.culturalTips != null &&
                lesson.culturalTips!.es.isNotEmpty) ...[
              SectionHeader(
                uiText(
                  lang,
                  ar: 'نصيحة ثقافية',
                  es: 'Dato Cultural',
                  other: 'Cultural Tip',
                ),
              ),
              CulturalTipsSection(tips: lesson.culturalTips!, lang: lang),
              const SizedBox(height: 12),
            ],
            // Speaking
            if (lesson.speaking.isNotEmpty) ...[
              SectionHeader(
                uiText(
                  lang,
                  ar: 'تحدث الآن',
                  es: 'Habla Ahora',
                  other: 'Speaking',
                ),
              ),
              SpeakingSection(items: lesson.speaking, lang: lang),
            ],
            const SizedBox(height: 12),
            // Exercises
            SectionHeader(
              uiText(
                lang,
                ar: 'التمارين',
                es: 'Ejercicios',
                other: 'Exercises',
              ),
            ),
            ..._visibleExercises(lesson).map(
              (e) => ExerciseTile(
                lesson.id,
                e.key,
                e.value,
                lang,
                isDone: _doneExercises.contains('${lesson.id}::${e.key}'),
                drillNumber: _drillOrdinals[e.key]?.$1,
                drillTotal: _drillOrdinals[e.key]?.$2,
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
                uiText(
                  lang,
                  ar: 'إكمال الدرس',
                  es: 'Marcar lección completada',
                  other: 'Mark lesson complete',
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
