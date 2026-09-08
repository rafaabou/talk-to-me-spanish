import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/content_index.dart';
import '../services/progress_service.dart';
import '../widgets/audio_button.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import '../services/ui_text.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<VocabWord>? _deck;
  List<String> _keys = [];
  List<TriText?> _examples = [];
  int _index = 0;
  bool _revealed = false;
  int _known = 0;
  int _again = 0;
  bool _loading = true;
  bool _done = false;
  bool _dueOnly = false;
  int _repeatCount = 1;
  static const List<int> _repeatOptions = [1, 3, 7, 10];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final index = await ContentIndexRepository.instance.load();
    final due = await ProgressService.instance.getDueFsrsCards();
    final allKeys =
        (await ProgressService.instance.getFsrsCards()).keys.toSet();
    final repeatCount = await ProgressService.instance.getRepeatCount();
    final words = <VocabWord>[];
    final keys = <String>[];
    final examples = <String, TriText>{};
    for (final v in index.vocab) {
      final key = v.key;
      final inSrs = allKeys.contains(key);
      final isDue = due.containsKey(key);
      final isUnseen = !inSrs;
      if (isDue || (!_dueOnly && isUnseen)) {
        words.add(VocabWord(v.text.es, v.ipa, v.text.en, v.text.ar));
        keys.add(key);
        if (v.example != null) examples[key] = v.example!;
      }
    }
    final pairs = List.generate(words.length, (i) => i)..shuffle(Random());
    final shuffledWords = [for (final i in pairs) words[i]];
    final shuffledKeys = [for (final i in pairs) keys[i]];
    final shuffledExamples = [for (final i in pairs) examples[shuffledKeys[i]]];
    if (!mounted) return;
    setState(() {
      _deck = shuffledWords;
      _keys = shuffledKeys;
      _examples = shuffledExamples;
      _dueOnly = due.isNotEmpty;
      _repeatCount = repeatCount;
      _loading = false;
    });
  }

  Future<void> _setRepeatCount(int count) async {
    await ProgressService.instance.setRepeatCount(count);
    setState(() => _repeatCount = count);
  }

  void _next({required int rating}) {
    final key = _keys[_index];
    ProgressService.instance.markSrs(key, known: rating > 1);
    ProgressService.instance.incrementFlashcardsReviewed(1);
    setState(() {
      if (rating > 1) {
        _known++;
      } else {
        _again++;
        final repeats = _repeatCount.clamp(1, _repeatOptions.last);
        for (int i = 0; i < repeats; i++) {
          _deck!.add(_deck![_index]);
          _keys.add(_keys[_index]);
          _examples.add(_examples[_index]);
        }
      }
      _index++;
      if (_index >= _deck!.length) {
        _done = true;
      }
      _revealed = false;
    });
  }

  void _newSession() {
    setState(() {
      _deck = List.of(_deck!)..shuffle(Random());
      _index = 0;
      _known = 0;
      _again = 0;
      _done = false;
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

    final deck = _deck!;
    final done = _done || _index >= deck.length;

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            uiText(
              lang,
              ar: 'البطاقات التعليمية',
              es: 'Tarjetas de Estudio',
              other: 'Flashcards',
            ),
          ),
          actions: [
            PopupMenuButton<int>(
              icon: const Icon(Icons.replay),
              tooltip: 'Repeat count',
              onSelected: _setRepeatCount,
              itemBuilder:
                  (_) =>
                      _repeatOptions
                          .map(
                            (c) => PopupMenuItem(
                              value: c,
                              child: Text(_repeatCount == c ? '×$c ✓' : '×$c'),
                            ),
                          )
                          .toList(),
            ),
          ],
        ),
        body:
            done
                ? _buildResult(lang)
                : _buildCard(
                  deck[_index],
                  lang,
                  deck.length,
                  _examples[_index],
                ),
      ),
    );
  }

  Widget _buildResult(String lang) {
    final total = _known + _again;
    final pct = total == 0 ? 0 : (_known * 100 / total).round();
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
                    Icons.emoji_events,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    uiText(
                      lang,
                      ar: 'انتهت الجلسة!',
                      es: '¡Sesión completada!',
                      other: 'Session complete!',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    uiText(
                      lang,
                      ar: 'عرفت $pct٪',
                      es: 'Sabías el $pct%',
                      other: 'You knew $pct%',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    uiText(
                      lang,
                      ar: 'معروف: $_known · كرر لاحقًا: $_again',
                      es: 'Sabías: $_known · Repasar después: $_again',
                      other: 'Known: $_known · Review again: $_again',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _newSession,
                    child: Text(
                      uiText(
                        lang,
                        ar: 'جلسة جديدة',
                        es: 'Nueva sesión',
                        other: 'New session',
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
    );
  }

  Widget _buildCard(VocabWord word, String lang, int total, TriText? example) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_index + 1}/$total',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                uiText(
                  lang,
                  ar: 'أصايب: $_known · أخطاء: $_again',
                  es: 'Sabías: $_known · Errores: $_again',
                  other: 'Known: $_known · Errors: $_again',
                ),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _revealed = !_revealed),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word.es,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        word.ipa,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      AudioButton(text: word.es, lang: 'es'),
                      const SizedBox(height: 16),
                      if (_revealed) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          word.tr(lang),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (lang == 'en' && word.ar.isNotEmpty)
                          Text(
                            word.ar,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        if (example != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            example.es,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          Text(
                            uiText(lang, ar: example.ar, other: example.en),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ] else
                        Text(
                          uiText(
                            lang,
                            ar: 'اضغط للكشف عن المعنى',
                            es: 'Toca para revelar',
                            other: 'Tap to reveal',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_revealed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children:
                      _repeatOptions.map((c) {
                        final isSelected = _repeatCount == c;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                        : null,
                              ),
                              onPressed: () => _setRepeatCount(c),
                              child: Text('×$c'),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _next(rating: 1),
                        icon: const Icon(Icons.refresh, color: Colors.orange),
                        label: Text(
                          uiText(
                            lang,
                            ar: 'مرة أخرى',
                            es: 'Otra vez',
                            other: 'Again',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _next(rating: 3),
                        icon: const Icon(Icons.check),
                        label: Text(
                          uiText(
                            lang,
                            ar: 'أعرفها',
                            es: 'Sé',
                            other: 'I know it',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () => _next(rating: 4),
                        icon: const Icon(Icons.flash_on),
                        label: Text(
                          uiText(lang, ar: 'سهل', es: 'Fácil', other: 'Easy'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const CreditFooter(),
      ],
    );
  }
}
