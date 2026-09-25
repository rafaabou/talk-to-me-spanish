import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/course_models.dart';
import '../services/progress_service.dart';
import '../widgets/audio_button.dart';
import '../widgets/tri_block.dart';
import '../services/ui_text.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});
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

class VocabTile extends StatelessWidget {
  final String lessonId;
  final int index;
  final VocabWord v;
  final String lang;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const VocabTile(
    this.lessonId,
    this.index,
    this.v,
    this.lang, {
    super.key,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  /// Same rule as [TriBlock]: the course language, the English line when the
  /// reader wants it, and Arabic — which is always shown.
  List<String> _translationLangs(BuildContext context, String uiLang) {
    final showEnglish = context.select<AppState, bool>(
      (s) => s.showEnglishTranslation,
    );
    return visibleTranslationLangs(
      contentLang: 'es',
      uiLang: uiLang,
      showEnglish: showEnglish,
    );
  }

  /// [TriText.tr] falls back to the course language when a translation is
  /// missing, so skip anything that would just repeat the primary line.
  bool _visible(String value, String primary) {
    final v = value.trim();
    return v.isNotEmpty && v != primary.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        // The word's speaker sits on the word's own line. In `trailing` it was
        // centred against the whole card, next to the example sentence, so it
        // read as sentence audio. `Wrap` keeps the IPA readable: entries whose
        // "word" is really a phrase carry long IPA strings, and those move to
        // their own line instead of squeezing the word out of the row.
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    v.es,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (v.ipa.isNotEmpty)
                    Text(v.ipa, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 4),
            AudioButton(text: v.es, lang: 'es'),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in _translationLangs(context, lang))
              if (_visible(v.tr(l), v.es))
                Align(
                  alignment:
                      l == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    v.tr(l),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textDirection: l == 'ar' ? TextDirection.rtl : null,
                    textAlign: l == 'ar' ? TextAlign.right : null,
                  ),
                ),
            if (v.example != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v.example!.es,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AudioButton(text: v.example!.es, lang: 'es', compact: true),
                ],
              ),
              for (final l in _translationLangs(context, lang))
                if (_visible(v.example!.tr(l), v.example!.es))
                  Align(
                    alignment:
                        l == 'ar'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Text(
                      v.example!.tr(l),
                      style: Theme.of(context).textTheme.bodySmall,
                      textDirection: l == 'ar' ? TextDirection.rtl : null,
                      textAlign: l == 'ar' ? TextAlign.right : null,
                    ),
                  ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.amber : null,
          ),
          tooltip: 'Favorite',
          onPressed: onToggleFavorite,
        ),
      ),
    );
  }
}

class GrammarTile extends StatelessWidget {
  final GrammarSection g;
  final String lang;
  const GrammarTile(this.g, this.lang, {super.key});

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

class DialogueLineTile extends StatelessWidget {
  final DialogueLine l;
  final String lang;
  const DialogueLineTile(this.l, this.lang, {super.key});

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

class SpeakingSection extends StatefulWidget {
  final List<SpeakingItem> items;
  final String lang;
  const SpeakingSection({super.key, required this.items, required this.lang});

  @override
  State<SpeakingSection> createState() => _SpeakingSectionState();
}

class _SpeakingSectionState extends State<SpeakingSection> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final progress =
        widget.items.isEmpty ? 0.0 : _done.length / widget.items.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uiText(
                      lang,
                      ar: 'تمارين التحدث',
                      es: 'Ejercicios de Habla',
                      other: 'Speaking Exercises',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_done.length}/${widget.items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              uiText(
                lang,
                ar: 'استمع ثم كرر الجمل بصوت عالٍ',
                es: 'Escucha y repite cada frase en voz alta',
                other: 'Listen and repeat each phrase aloud',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            ...widget.items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final done = _done.contains(i);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Card(
                  color:
                      done
                          ? Colors.green.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          done ? Icons.check_circle : Icons.mic,
                          size: 20,
                          color:
                              done
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TriBlock(item.text, compact: true)),
                        AudioButton(
                          text: item.text.es,
                          lang: 'es',
                          compact: true,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            done ? Icons.replay : Icons.check,
                            color: done ? Colors.orange : Colors.green,
                          ),
                          tooltip:
                              done
                                  ? uiText(
                                    lang,
                                    ar: 'إعادة',
                                    es: 'Rehacer',
                                    other: 'Redo',
                                  )
                                  : uiText(
                                    lang,
                                    ar: 'تم',
                                    es: 'Logré',
                                    other: 'Got it',
                                  ),
                          onPressed:
                              () => setState(() {
                                if (done) {
                                  _done.remove(i);
                                  ProgressService.instance
                                      .decrementSpeakingDone();
                                } else {
                                  _done.add(i);
                                  ProgressService.instance
                                      .incrementSpeakingDone();
                                }
                              }),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class LessonNotesSection extends StatefulWidget {
  final String lessonId;
  final String lang;
  const LessonNotesSection({
    super.key,
    required this.lessonId,
    required this.lang,
  });

  @override
  State<LessonNotesSection> createState() => _LessonNotesSectionState();
}

class _LessonNotesSectionState extends State<LessonNotesSection> {
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
              ? 'Notas guardadas'
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
                  uiText(
                    lang,
                    ar: 'ملاحظاتي',
                    es: 'Mis Notas',
                    other: 'My Notes',
                  ),
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
                      hintText: uiText(
                        lang,
                        ar: 'اكتب ملاحظاتك هنا...',
                        es: 'Escribe tus notas aquí...',
                        other: 'Write your notes here...',
                      ),
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
                          uiText(
                            lang,
                            ar: 'مسح',
                            es: 'Limpiar',
                            other: 'Clear',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saveNotes,
                        icon: const Icon(Icons.save),
                        label: Text(
                          uiText(lang, ar: 'حفظ', es: 'Guardar', other: 'Save'),
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

class CulturalTipsSection extends StatelessWidget {
  final TriText tips;
  final String lang;
  const CulturalTipsSection({
    super.key,
    required this.tips,
    required this.lang,
  });

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
                  uiText(
                    lang,
                    ar: 'نصيحة ثقافية',
                    es: 'Dato Cultural',
                    other: 'Cultural Tip',
                  ),
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
