import 'package:flutter/material.dart';
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
                uiText(lang, ar: v.example!.ar, other: v.example!.en),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiText(
                lang,
                ar: 'كرر الجمل بصوت عالٍ بعد الاستماع',
                es: 'Repite cada frase en voz alta después de escuchar',
                other: 'Repeat each phrase aloud after listening',
              ),
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
                      tooltip: uiText(
                        lang,
                        ar: 'تم',
                        es: 'Lo logré',
                        other: 'Got it',
                      ),
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
