import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/content_index.dart';
import '../widgets/tri_block.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';

class GrammarItem {
  final String lessonId;
  final String level;
  final GrammarSection section;
  GrammarItem(this.lessonId, this.level, this.section);
}

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  List<GrammarItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final index = await ContentIndexRepository.instance.load();
    final items = index.grammar.map(
      (g) => GrammarItem(
        g.lesson,
        g.lesson.split('-').first,
        GrammarSection(g.title, g.explanation, g.examples),
      ),
    );
    if (!mounted) return;
    setState(() {
      _items = items.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final items = _items ?? <GrammarItem>[];
    final levels = <String, List<GrammarItem>>{};
    for (final item in items) {
      levels.putIfAbsent(item.level, () => []).add(item);
    }
    final orderedLevels =
        ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].where(levels.containsKey).toList();

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            lang == 'ar'
                ? 'مرجع القواعد'
                : lang == 'es'
                ? 'Guía de Gramática'
                : 'Grammar Guide',
          ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final levelId in orderedLevels) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          levelId,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      for (final item in levels[levelId]!)
                        Card(
                          child: ExpansionTile(
                            title: Text(
                              item.section.title.tr(lang),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${item.lessonId} · ${item.section.title.es}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: TriBlock(item.section.explanation),
                              ),
                              ...item.section.examples.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: TriBlock(
                                    e,
                                    audio: true,
                                    compact: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                    ],
                    CreditFooter(),
                  ],
                ),
      ),
    );
  }
}
