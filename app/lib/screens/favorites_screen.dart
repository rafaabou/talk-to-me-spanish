import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/progress_service.dart';
import '../widgets/audio_button.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../services/ui_text.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<VocabWord> _words = [];
  List<String> _keys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favKeys = await ProgressService.instance.getFavorites();
    final words = <VocabWord>[];
    final keys = <String>[];
    for (final key in favKeys) {
      final parts = key.split('::');
      if (parts.length != 2) continue;
      final lesson = await CourseRepository.instance.tryLoadLesson(parts[0]);
      final idx = int.tryParse(parts[1]);
      if (lesson != null && idx != null && idx < lesson.vocabulary.length) {
        words.add(lesson.vocabulary[idx]);
        keys.add(key);
      }
    }
    if (!mounted) return;
    setState(() {
      _words = words;
      _keys = keys;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            uiText(
              lang,
              ar: 'الكلمات المفضلة',
              es: 'Palabras favoritas',
              other: 'Favorite words',
            ),
          ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                ? Center(
                  child: Text(
                    uiText(
                      lang,
                      ar: 'لا توجد كلمات مفضلة بعد',
                      es: 'Aún no hay palabras favoritas',
                      other: 'No favorite words yet',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
                : ListView.builder(
                  itemCount: _words.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _words.length) {
                      return const CreditFooter();
                    }
                    final w = _words[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          w.es,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${w.en} · ${w.ar}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AudioButton(text: w.es, lang: 'es', compact: true),
                            IconButton(
                              icon: const Icon(Icons.star, color: Colors.amber),
                              onPressed: () async {
                                await ProgressService.instance.toggleFavorite(
                                  _keys[i],
                                );
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
