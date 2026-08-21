import 'package:flutter/material.dart';
import '../models/course_models.dart';
import '../widgets/audio_button.dart';
import '../widgets/tri_block.dart';
import '../services/ui_text.dart';

class _ReorderItem {
  final String text;
  bool dragging = false;
  _ReorderItem({required this.text});
}

class _MatchPair {
  final String left;
  final String right;
  final String correctRight;
  bool selected = false;
  _MatchPair({
    required this.left,
    required this.right,
    required this.correctRight,
  });
}

class ExerciseTile extends StatefulWidget {
  final String lessonId;
  final int index;
  final Exercise e;
  final String lang;
  final bool isDone;
  final VoidCallback onToggleDone;
  const ExerciseTile(
    this.lessonId,
    this.index,
    this.e,
    this.lang, {
    super.key,
    required this.isDone,
    required this.onToggleDone,
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

  List<String> get _reorderWords {
    final scrambled = widget.e.options.map((o) => o.es).toList();
    return scrambled;
  }

  List<String> get _matchLeft {
    if (widget.e.type != 'match_pairs') return [];
    final pairs = widget.e.answer.split('|');
    return pairs.map((p) => p.split('::').first).toList();
  }

  List<String> get _matchRight {
    if (widget.e.type != 'match_pairs') return [];
    final pairs = widget.e.answer.split('|');
    final right = pairs.map((p) => p.split('::').last).toList();
    final shuffled = List<String>.from(right)..shuffle();
    return shuffled;
  }

  List<_ReorderItem> _reorderState = [];
  List<_MatchPair> _matchState = [];

  @override
  void initState() {
    super.initState();
    _initReorder();
    _initMatchPairs();
  }

  void _initReorder() {
    if (!_isReorder) return;
    _reorderState = _reorderWords.map((w) => _ReorderItem(text: w)).toList();
  }

  void _initMatchPairs() {
    if (!_isMatchPairs) return;
    final left = _matchLeft;
    final right = _matchRight;
    _matchState = List.generate(
      left.length,
      (i) => _MatchPair(
        left: left[i],
        right: right[i],
        correctRight: left.length > i ? _getCorrectRight(left[i]) : '',
      ),
    );
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

  void _onMatchTap(int index) {
    setState(() {
      _matchState[index].selected = !_matchState[index].selected;
    });
  }

  bool _checkReorder() {
    final userOrder = _reorderState.map((i) => i.text).join(' ');
    final correct = widget.e.answer;
    return _normalize(userOrder) == _normalize(correct);
  }

  bool _checkMatchPairs() {
    for (final m in _matchState) {
      if (m.selected && m.right != m.correctRight) return false;
      if (!m.selected && m.right == m.correctRight) return false;
    }
    return true;
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
                  AudioButton(text: e.audio ?? e.answer, lang: 'es'),
                  const SizedBox(width: 8),
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
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            o.tr(lang),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (o.en.isNotEmpty && o.en != o.es) ...[
                            const SizedBox(height: 2),
                            Text(
                              o.en,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (o.ar.isNotEmpty && o.ar != o.es) ...[
                            const SizedBox(height: 2),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                o.ar,
                                style: Theme.of(context).textTheme.bodySmall,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ],
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
                        if (!_isMC && !_isReorder && !_isMatchPairs) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                e.answer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              AudioButton(
                                text: e.answer.split('/')[0],
                                lang: 'es',
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                        if (_isReorder || _isMatchPairs) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                e.answer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              AudioButton(
                                text: e.answer.split('/')[0],
                                lang: 'es',
                                compact: true,
                              ),
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
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: _onReorder,
      children:
          _reorderState.asMap().entries.map((entry) {
            final item = entry.value;
            return Card(
              key: ValueKey(item.text),
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
    );
  }

  Widget _buildMatchPairs(BuildContext context, String lang) {
    return Column(
      children:
          _matchState.asMap().entries.map((entry) {
            final index = entry.key;
            final pair = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Text(
                  pair.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                title: GestureDetector(
                  onTap: () => _onMatchTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          pair.selected
                              ? (pair.right == pair.correctRight
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2))
                              : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color:
                            pair.selected
                                ? (pair.right == pair.correctRight
                                    ? Colors.green
                                    : Colors.red)
                                : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pair.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            pair.selected ? FontWeight.bold : FontWeight.normal,
                        color:
                            pair.selected
                                ? (pair.right == pair.correctRight
                                    ? Colors.green
                                    : Colors.red)
                                : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
                trailing:
                    pair.selected
                        ? Icon(
                          pair.right == pair.correctRight
                              ? Icons.check_circle
                              : Icons.cancel,
                          color:
                              pair.right == pair.correctRight
                                  ? Colors.green
                                  : Colors.red,
                        )
                        : null,
              ),
            );
          }).toList(),
    );
  }
}
