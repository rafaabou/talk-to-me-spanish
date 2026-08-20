import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/content_index.dart';
import 'lesson_screen.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';

class SearchResult {
  final String lessonId;
  final String level;
  final String field; // vocabulary / dialogue / reading / grammar
  final TriText text;
  SearchResult(this.lessonId, this.level, this.field, this.text);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchResult>? _index;
  List<SearchResult> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildIndex();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buildIndex() async {
    final index = await ContentIndexRepository.instance.load();
    final results = <SearchResult>[];
    for (final v in index.vocab) {
      results.add(
        SearchResult(v.lesson, v.lesson.split('-').first, 'vocabulary', v.text),
      );
      if (v.example != null) {
        results.add(
          SearchResult(
            v.lesson,
            v.lesson.split('-').first,
            'vocabulary',
            v.example!,
          ),
        );
      }
    }
    for (final d in index.dialogue) {
      results.add(
        SearchResult(d.lesson, d.lesson.split('-').first, 'dialogue', d.text),
      );
    }
    for (final g in index.grammar) {
      results.add(
        SearchResult(
          g.lesson,
          g.lesson.split('-').first,
          'grammar',
          g.explanation,
        ),
      );
      for (final ex in g.examples) {
        results.add(
          SearchResult(g.lesson, g.lesson.split('-').first, 'grammar', ex),
        );
      }
    }
    for (final r in index.reading) {
      results.add(
        SearchResult(r.lesson, r.lesson.split('-').first, 'reading', r.text),
      );
    }
    if (!mounted) return;
    setState(() {
      _index = results;
      _loading = false;
    });
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final index = _index;
    if (index == null) return;
    setState(() {
      _results =
          index
              .where((r) {
                return r.text.es.toLowerCase().contains(query) ||
                    r.text.en.toLowerCase().contains(query) ||
                    r.text.ar.toLowerCase().contains(query);
              })
              .take(50)
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            lang == 'ar'
                ? 'بحث'
                : lang == 'es'
                ? 'Buscar'
                : 'Search',
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText:
                      lang == 'ar'
                          ? 'اكتب كلمة...'
                          : lang == 'es'
                          ? 'Escribe una palabra...'
                          : 'Type a word...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                      ? Center(
                        child: Text(
                          lang == 'ar'
                              ? 'لا توجد نتائج'
                              : lang == 'es'
                              ? 'Sin resultados'
                              : 'No results',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                      : ListView.builder(
                        itemCount: _results.length + 1,
                        itemBuilder: (context, i) {
                          if (i == _results.length) {
                            return const CreditFooter();
                          }
                          final r = _results[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text(
                                  r.level[0],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(
                                r.text.es,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${r.lessonId} · ${_fieldLabel(r.field, lang)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => LessonScreen(
                                            lessonId: r.lessonId,
                                          ),
                                    ),
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

  String _fieldLabel(String field, String lang) {
    switch (field) {
      case 'vocabulary':
        return lang == 'ar'
            ? 'المفردات'
            : lang == 'es'
            ? 'Vocabulario'
            : 'Vocabulary';
      case 'dialogue':
        return lang == 'ar'
            ? 'الحوار'
            : lang == 'es'
            ? 'Diálogo'
            : 'Dialogue';
      case 'reading':
        return lang == 'ar'
            ? 'القراءة'
            : lang == 'es'
            ? 'Lectura'
            : 'Reading';
      default:
        return lang == 'ar'
            ? 'القواعد'
            : lang == 'es'
            ? 'Gramática'
            : 'Grammar';
    }
  }
}
