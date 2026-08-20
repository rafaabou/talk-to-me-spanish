import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/progress_service.dart';
import '../models/course_models.dart';
import 'lesson_screen.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';

class LessonListScreen extends StatefulWidget {
  final String levelId;
  final String levelName;
  final List<String> lessonIds;

  const LessonListScreen({
    super.key,
    required this.levelId,
    required this.levelName,
    required this.lessonIds,
  });

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  Map<String, TriText>? _titles;
  Set<String> _completed = {};
  Map<String, int> _exDone = {};
  Map<String, int> _exTotal = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await ProgressService.instance.getCompleted();
    final doneExercises =
        await ProgressService.instance.getCompletedExercises();
    final titles = <String, TriText>{};
    final exDone = <String, int>{};
    final exTotal = <String, int>{};
    for (final id in widget.lessonIds) {
      final lesson = await CourseRepository.instance.tryLoadLesson(id);
      if (lesson != null) {
        titles[id] = lesson.title;
        exTotal[id] = lesson.exercises.length;
        exDone[id] =
            lesson.exercises
                .asMap()
                .entries
                .where((e) => doneExercises.contains('$id::${e.key}'))
                .length;
      }
    }
    if (!mounted) return;
    setState(() {
      _titles = titles;
      _completed = completed;
      _exDone = exDone;
      _exTotal = exTotal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.levelId} - ${widget.levelName}')),
        body: ListView.builder(
          itemCount: widget.lessonIds.length + 1,
          itemBuilder: (context, i) {
            if (i == widget.lessonIds.length) {
              return const CreditFooter();
            }
            final id = widget.lessonIds[i];
            final title = _titles?[id];
            final done = _completed.contains(id);
            final total = _exTotal[id] ?? 0;
            final exDone = _exDone[id] ?? 0;
            final pct = total == 0 ? 0.0 : exDone / total;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          done
                              ? Colors.green
                              : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      child:
                          done
                              ? const Icon(Icons.check, color: Colors.white)
                              : Text('${i + 1}'),
                    ),
                    title: Text(
                      title?.tr(lang) ?? id,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonScreen(lessonId: id),
                        ),
                      );
                      _load();
                    },
                  ),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  if (total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$exDone/$total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
