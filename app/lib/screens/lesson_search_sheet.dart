import 'package:flutter/material.dart';
import '../models/course_models.dart';
import '../services/exercise_dedup.dart';
import '../services/ui_text.dart';

class LessonSearchSheet extends StatefulWidget {
  final Lesson lesson;
  final String lang;
  final void Function(String section, int index) onSelect;
  const LessonSearchSheet({
    super.key,
    required this.lesson,
    required this.lang,
    required this.onSelect,
  });

  @override
  State<LessonSearchSheet> createState() => _LessonSearchSheetState();
}

class _LessonSearchSheetState extends State<LessonSearchSheet> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];

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
    final results = <SearchResult>[];

    // Search vocabulary
    for (int i = 0; i < lesson.vocabulary.length; i++) {
      final v = lesson.vocabulary[i];
      if (v.es.toLowerCase().contains(query) ||
          v.en.toLowerCase().contains(query) ||
          v.ar.toLowerCase().contains(query) ||
          (v.example?.es.toLowerCase().contains(query) ?? false) ||
          (v.example?.en.toLowerCase().contains(query) ?? false)) {
        results.add(
          SearchResult(
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
          SearchResult(
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
          SearchResult(
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
          SearchResult(
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
    // Search exercises (deduplicated, but keeping the original index so the
    // jump-to-exercise offset still lines up)
    for (final entry in dedupeExercises(lesson.exercises, 'es')) {
      final i = entry.key;
      final e = entry.value;
      if (e.prompt.es.toLowerCase().contains(query) ||
          e.prompt.en.toLowerCase().contains(query) ||
          e.prompt.ar.toLowerCase().contains(query) ||
          e.options.any((o) => o.es.toLowerCase().contains(query))) {
        results.add(
          SearchResult(
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

class SearchResult {
  final String section;
  final int index;
  final String title;
  final String subtitle;
  SearchResult({
    required this.section,
    required this.index,
    required this.title,
    required this.subtitle,
  });
}

class _Translations {
  final String lang;
  _Translations(this.lang);
  String get searchInLesson => uiText(
    lang,
    ar: 'البحث في الدرس',
    es: 'Buscar en la lección',
    other: 'Search in lesson',
  );
  String get searchHint => uiText(
    lang,
    ar: 'اكتب للبحث...',
    es: 'Escribe para buscar...',
    other: 'Type to search...',
  );
  String get noResults => uiText(
    lang,
    ar: 'لا توجد نتائج',
    es: 'Sin resultados',
    other: 'No results',
  );
}
