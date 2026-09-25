import 'package:flutter/material.dart';
import '../models/course_models.dart';
import '../widgets/audio_button.dart';
import '../widgets/tri_block.dart';
import '../services/ui_text.dart';

class _ReorderItem {
  final int id;
  final String text;
  bool dragging = false;
  _ReorderItem({required this.id, required this.text});
}

class ExerciseTile extends StatefulWidget {
  /// Language of the course content, which is what audio keys are built from.
  /// This is not the UI language.
  static const String contentLang = 'es';

  final String lessonId;
  final int index;
  final Exercise e;
  final String lang;
  final bool isDone;
  final VoidCallback onToggleDone;
  final int? drillNumber;
  final int? drillTotal;
  const ExerciseTile(
    this.lessonId,
    this.index,
    this.e,
    this.lang, {
    super.key,
    required this.isDone,
    required this.onToggleDone,
    this.drillNumber,
    this.drillTotal,
  });

  @override
  State<ExerciseTile> createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<ExerciseTile> {
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

  /// "Audio 2/4" style label so repeated audio drills are distinguishable.
  String? get _drillLabel {
    final number = widget.drillNumber;
    final total = widget.drillTotal;
    if (number == null || total == null || total < 2) return null;
    return uiText(
      widget.lang,
      ar: 'الصوت $number/$total',
      es: 'Audio $number/$total',
      other: 'Audio $number/$total',
    );
  }

  List<String> get _reorderWords {
    final scrambled = widget.e.options.map((o) => o.es).toList();
    return scrambled;
  }

  List<_ReorderItem> _reorderState = [];
  List<String> _matchPairsLeft = [];
  List<String> _matchPairsRight = [];
  String? _selectedMatchLeft;
  final Set<String> _matchedLeft = {};
  final Set<String> _matchedRight = {};

  @override
  void initState() {
    super.initState();
    _initReorder();
    _initMatchPairs();
  }

  void _initReorder() {
    if (!_isReorder) return;
    final words = _reorderWords;
    _reorderState = [
      for (var i = 0; i < words.length; i++)
        _ReorderItem(id: i, text: words[i]),
    ];
  }

  void _initMatchPairs() {
    if (!_isMatchPairs) return;
    final pairs = widget.e.answer.split('|');
    final left = <String>[];
    final right = <String>[];
    for (final p in pairs) {
      final parts = p.split('::');
      if (parts.length == 2) {
        left.add(parts[0]);
        right.add(parts[1]);
      }
    }
    _matchPairsLeft = left;
    _matchPairsRight = List<String>.from(right)..shuffle();
    _matchedLeft.clear();
    _matchedRight.clear();
    _selectedMatchLeft = null;
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

  void _onMatchLeftTap(String pt) {
    setState(() {
      _selectedMatchLeft = pt;
    });
  }

  void _onMatchRightTap(String en) {
    final left = _selectedMatchLeft;
    if (left == null) return;
    final correctEn = _getCorrectRight(left);
    setState(() {
      if (en == correctEn) {
        _matchedLeft.add(left);
        _matchedRight.add(en);
        _selectedMatchLeft = null;
      } else {
        _selectedMatchLeft = null;
      }
    });
    if (_checkMatchPairs()) {
      _submitAnswer('');
    }
  }

  bool _checkReorder() {
    final userOrder = _reorderState.map((i) => i.text).join(' ');
    final correct = widget.e.answer;
    return _normalize(userOrder) == _normalize(correct);
  }

  bool _checkMatchPairs() {
    return _matchedLeft.length == _matchPairsLeft.length;
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
                  AudioButton(
                    text: (e.audio ?? e.answer.split('/')[0]).trim(),
                    lang: ExerciseTile.contentLang,
                  ),
                  const SizedBox(width: 8),
                  if (_drillLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _drillLabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                      alignment: AlignmentDirectional.centerStart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: () {
                          // The option is shown in the course language, which
                          // is also what [Exercise.answer] is keyed on. Using
                          // the interface language here made the English line
                          // repeat itself and hid the Spanish word the learner
                          // actually has to recognise.
                          final primary = o.tr(ExerciseTile.contentLang).trim();
                          final en = o.en.trim();
                          final ar = o.ar.trim();
                          final showEn = en.isNotEmpty && en != primary;
                          final showAr =
                              ar.isNotEmpty && ar != primary && ar != en;
                          final small = Theme.of(context).textTheme.bodySmall;
                          return [
                            Text(
                              primary,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (showEn) ...[
                              const SizedBox(height: 2),
                              Text(en, style: small),
                            ],
                            if (showAr) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Text(
                                  ar,
                                  style: small,
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ];
                        }(),
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
                  uiText(lang, ar: 'تحقق', es: 'Comprobar', other: 'Check'),
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
                        if (!_isMC) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                e.answer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!e.answer.contains('::')) ...[
                                const SizedBox(width: 6),
                                AudioButton(
                                  text: e.answer.split('/')[0].trim(),
                                  lang: 'es',
                                  compact: true,
                                ),
                              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            uiText(
              lang,
              ar: 'اضغط الكلمات بالترتيب — لا تهم علامات التشكيل',
              es: 'Toca las palabras en orden — las tildes no importan',
              other: 'Tap the words in order — accents do not matter',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: _onReorder,
          children:
              _reorderState.map((item) {
                return Card(
                  key: ValueKey('reorder_${item.id}'),
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
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => _submitAnswer(''),
          child: Text(
            uiText(lang, ar: 'تحقق', es: 'Comprobar', other: 'Check'),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchPairs(BuildContext context, String lang) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    uiText(
                      lang,
                      pt: 'Português',
                      es: 'Español',
                      ar: 'الإسبانية',
                      other: 'Spanish',
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(_matchPairsLeft.length, (i) {
                    final pt = _matchPairsLeft[i];
                    final matched = _matchedLeft.contains(pt);
                    final selected = _selectedMatchLeft == pt;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: OutlinedButton(
                        onPressed: matched ? null : () => _onMatchLeftTap(pt),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              matched
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : selected
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.15)
                                  : null,
                          side: BorderSide(
                            color:
                                matched
                                    ? Colors.green
                                    : selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(pt, style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Text(
                    uiText(
                      lang,
                      pt: 'Inglês',
                      es: 'Inglés',
                      ar: 'الإنجليزية',
                      other: 'English',
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(_matchPairsRight.length, (i) {
                    final en = _matchPairsRight[i];
                    final matched = _matchedRight.contains(en);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: OutlinedButton(
                        onPressed:
                            matched || _selectedMatchLeft == null
                                ? null
                                : () => _onMatchRightTap(en),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              matched
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : null,
                          side: BorderSide(
                            color: matched ? Colors.green : Colors.grey,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(en, style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
