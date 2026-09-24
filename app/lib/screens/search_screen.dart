import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../models/verb_models.dart';
import '../services/app_state.dart';
import '../services/content_index.dart';
import '../services/verb_repository.dart';
import 'lesson_screen.dart';
import 'verb_screen.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../services/ui_text.dart';

class SearchResult {
  final String lessonId;
  final String level;
  final String field; // vocabulary / dialogue / reading / grammar / verb
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
  List<VerbInfo>? _verbs;
  bool _searchingVerbs = false;
  bool _loading = true;
  bool _failed = false;

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
    late final ContentIndex index;
    try {
      index = await ContentIndexRepository.instance.load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
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
    // Show course matches immediately. The verb list is a multi-megabyte file,
    // so it is loaded in the background on the first search and the verb hits
    // are appended when it lands, rather than freezing the field until then.
    final courseResults =
        index
            .where((r) {
              return r.text.es.toLowerCase().contains(query) ||
                  r.text.en.toLowerCase().contains(query) ||
                  r.text.ar.toLowerCase().contains(query);
            })
            .take(50)
            .toList();
    final verbsReady = _verbs != null;
    final verbResults =
        verbsReady
            ? (_verbs!
                .where(
                  (v) =>
                      v.inf.toLowerCase().contains(query) ||
                      v.en.toLowerCase().contains(query) ||
                      v.ar.contains(query),
                )
                .map(
                  (v) => SearchResult(
                    'verbs',
                    'verbs',
                    'verb',
                    TriText(v.inf, v.en, v.ar),
                  ),
                )
                .take(20)
                .toList())
            : const <SearchResult>[];
    setState(() {
      _results = [...courseResults, ...verbResults];
      _searchingVerbs = !verbsReady;
    });
    if (!verbsReady) _loadVerbs();
  }

  Future<void> _loadVerbs() async {
    final verbs = await VerbRepository.instance.loadVerbs();
    if (!mounted) return;
    setState(() {
      _verbs = verbs.verbs;
      _searchingVerbs = false;
    });
    final text = _controller.text.trim();
    if (text.isNotEmpty) _search(text);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(uiText(lang, ar: 'بحث', es: 'Buscar', other: 'Search')),
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
                  hintText: uiText(
                    lang,
                    ar: 'اكتب كلمة...',
                    es: 'Escribe una palabra...',
                    other: 'Type a word...',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _failed
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 56,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            uiText(
                              lang,
                              ar: 'تعذر تحميل فهرس البحث',
                              es: 'Error al cargar el índice de búsqueda',
                              other: 'Failed to load search index',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _failed = false;
                              });
                              _buildIndex();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              uiText(
                                lang,
                                ar: 'إعادة المحاولة',
                                es: 'Reintentar',
                                other: 'Retry',
                              ),
                            ),
                          ),
                        ],
                      )
                      : _results.isEmpty
                      ? Center(
                        child:
                            _searchingVerbs
                                ? const CircularProgressIndicator()
                                : Text(
                                  uiText(
                                    lang,
                                    ar: 'لا توجد نتائج',
                                    es: 'Sin resultados',
                                    other: 'No results',
                                  ),
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
                                r.field == 'verb'
                                    ? _fieldLabel(r.field, lang)
                                    : '${r.lessonId} · ${_fieldLabel(r.field, lang)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap:
                                  r.field == 'verb'
                                      ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const VerbScreen(),
                                        ),
                                      )
                                      : () => Navigator.push(
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
        return uiText(
          lang,
          ar: 'المفردات',
          es: 'Vocabulario',
          other: 'Vocabulary',
        );
      case 'dialogue':
        return uiText(lang, ar: 'الحوار', es: 'Diálogo', other: 'Dialogue');
      case 'verb':
        return uiText(
          lang,
          ar: 'أفعال — افتح شاشة الأفعال',
          es: 'Verbos — abre la pantalla de verbos',
          other: 'Verb — open the verbs screen',
        );
      case 'reading':
        return uiText(lang, ar: 'القراءة', es: 'Lectura', other: 'Reading');
      default:
        return uiText(lang, ar: 'القواعد', es: 'Gramática', other: 'Grammar');
    }
  }
}
