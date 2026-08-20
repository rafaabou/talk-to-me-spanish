import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/progress_service.dart';
import '../services/notification_service.dart';
import '../services/home_widget_service.dart';
import 'lesson_list_screen.dart';
import 'flashcard_screen.dart';
import 'search_screen.dart';
import 'quiz_screen.dart';
import 'favorites_screen.dart';
import 'grammar_screen.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import 'verb_screen.dart';
import 'stats_screen.dart';
import 'lesson_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, LevelInfo>? _levels;
  Set<String> _completed = {};
  int _streak = 0;
  bool _loading = true;
  String? _lastOpened;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await CourseRepository.instance.loadLevels();
    final completed = await ProgressService.instance.getCompleted();
    final streak = await ProgressService.instance.getStreak();
    final lastOpened = await ProgressService.instance.getLastOpened();
    final dueCount = await ProgressService.instance.getDueWordCount();
    if (!mounted) return;
    setState(() {
      _levels = levels;
      _completed = completed;
      _streak = streak;
      _lastOpened = lastOpened;
      _dueCount = dueCount;
      _loading = false;
    });
    // Update home widget
    final totalCompleted =
        completed
            .where(
              (id) =>
                  id.startsWith('A') ||
                  id.startsWith('B') ||
                  id.startsWith('C'),
            )
            .length;
    await HomeWidgetService.updateWidget(
      dueCount: dueCount,
      streak: streak,
      lessonsCompleted: totalCompleted,
    );
    // Schedule notifications
    await NotificationService.instance.init();
    await NotificationService.instance.updateReviewNotification(dueCount);
    await NotificationService.instance.scheduleDailyReviewReminder();
    await NotificationService.instance.scheduleStreakNudge();
  }

  int _dueCount = 0;

  Future<void> _resume() async {
    final id = _lastOpened;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonScreen(lessonId: id)),
    );
    _load();
  }

  Future<void> _export() async {
    final summary = await ProgressService.instance.exportSummary();
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;

    if (_loading) {
      return AppSelectionArea(
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final levels = _levels!.values.toList();
    final totalLessons = levels.fold<int>(
      0,
      (sum, l) => sum + l.lessons.length,
    );
    final totalCompleted =
        _completed
            .where(
              (id) =>
                  id.startsWith('A') ||
                  id.startsWith('B') ||
                  id.startsWith('C'),
            )
            .length;

    return AppSelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Talk To Me Spanish By Mohamed Rafaa Tounekti',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export progress',
              onPressed: _export,
            ),
            _LangSelector(state: state),
            _ThemeSelector(state: state),
            _SettingsMenu(state: state),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_lastOpened != null) ...[
              _ContinueCard(lessonId: _lastOpened!, onTap: _resume),
              const SizedBox(height: 12),
            ],
            _buildProgressCard(totalCompleted, totalLessons, lang, _streak),
            const SizedBox(height: 12),
            if (_dueCount > 0) _DueCard(dueCount: _dueCount, lang: lang),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.style,
                    label:
                        lang == 'ar'
                            ? 'بطاقات تعليمية'
                            : lang == 'es'
                            ? 'Tarjetas de estudio'
                            : 'Flashcards',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FlashcardScreen(),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.search,
                    label:
                        lang == 'ar'
                            ? 'بحث'
                            : lang == 'es'
                            ? 'Buscar'
                            : 'Search',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.menu_book,
                    label:
                        lang == 'ar'
                            ? 'القواعد'
                            : lang == 'es'
                            ? 'Gramática'
                            : 'Grammar',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GrammarScreen(),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.star,
                    label:
                        lang == 'ar'
                            ? 'مفضل'
                            : lang == 'es'
                            ? 'Favoritos'
                            : 'Favorites',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FavoritesScreen(),
                          ),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.account_tree_outlined,
                    label:
                        lang == 'ar'
                            ? 'الأفعال'
                            : lang == 'es'
                            ? 'Verbos'
                            : 'Verbs',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VerbScreen()),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bar_chart,
                    label:
                        lang == 'ar'
                            ? 'الإحصائيات'
                            : lang == 'es'
                            ? 'Estadísticas'
                            : 'Stats',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionHeader(
              lang == 'ar'
                  ? 'الاختبارات'
                  : lang == 'es'
                  ? 'Exámenes'
                  : 'Quizzes',
            ),
            ...levels.map(
              (level) => _QuizCard(
                level: level,
                lang: lang,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(levelId: level.id),
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionHeader(
              lang == 'ar'
                  ? 'الدروس'
                  : lang == 'es'
                  ? 'Lecciones'
                  : 'Lessons',
            ),
            ...levels.map(
              (level) => _LevelCard(
                level: level,
                lang: lang,
                completedCount:
                    level.lessons
                        .where((l) => _completed.contains(l['id']))
                        .length,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => LessonListScreen(
                            levelId: level.id,
                            levelName: level.name.tr(lang),
                            lessonIds:
                                level.lessons
                                    .map((l) => l['id'] as String)
                                    .toList(),
                          ),
                    ),
                  );
                  _load();
                },
              ),
            ),
            const CreditFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int done, int total, String lang, int streak) {
    final pct = total == 0 ? 0.0 : done / total;
    final label =
        lang == 'ar'
            ? 'اكتملت $done من $total'
            : lang == 'es'
            ? '$done de $total lecciones completadas'
            : '$done of $total lessons completed';
    final streakLabel =
        lang == 'ar'
            ? 'أيام متتالية: $streak'
            : lang == 'es'
            ? 'Racha: $streak días'
            : 'Streak: $streak days';
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: pct, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      streakLabel,
                      style: Theme.of(context).textTheme.bodySmall,
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

class _ContinueCard extends StatelessWidget {
  final String lessonId;
  final VoidCallback onTap;
  const _ContinueCard({required this.lessonId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.play_arrow),
        title: Text(
          'Continue: $lessonId',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Resume your last lesson'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
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

class _QuizCard extends StatelessWidget {
  final LevelInfo level;
  final String lang;
  final VoidCallback onTap;

  const _QuizCard({
    required this.level,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          child: const Icon(Icons.quiz),
        ),
        title: Text(
          '${level.id} · ${level.name.tr(lang)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          lang == 'ar'
              ? '10 أسئلة'
              : lang == 'es'
              ? '10 preguntas'
              : '10 questions',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final LevelInfo level;
  final String lang;
  final int completedCount;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.lang,
    required this.completedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = level.lessons.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  level.id,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name.tr(lang),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.description.tr(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedCount/$total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangSelector extends StatelessWidget {
  final AppState state;
  const _LangSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      onSelected: (v) => state.setLang(v),
      itemBuilder:
          (_) => const [
            PopupMenuItem(value: 'en', child: Text('English')),
            PopupMenuItem(value: 'ar', child: Text('العربية')),
            PopupMenuItem(value: 'es', child: Text('Español')),
          ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final AppState state;
  const _ThemeSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (state.themeMode) {
      case ThemeMode.dark:
        icon = Icons.dark_mode;
      case ThemeMode.light:
        icon = Icons.light_mode;
      case ThemeMode.system:
        icon = Icons.brightness_auto;
    }
    return PopupMenuButton<ThemeMode>(
      icon: Icon(icon),
      onSelected: state.setThemeMode,
      itemBuilder:
          (_) => const [
            PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
            PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            PopupMenuItem(value: ThemeMode.system, child: Text('System')),
          ],
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  final AppState state;
  const _SettingsMenu({required this.state});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      onSelected: (v) async {
        switch (v) {
          case 'speed_0.5':
            state.setSpeed(0.5);
          case 'speed_0.75':
            state.setSpeed(0.75);
          case 'speed_1.0':
            state.setSpeed(1.0);
          case 'repeat_1':
            state.setRepeat(1);
          case 'repeat_3':
            state.setRepeat(3);
          case 'repeat_7':
            state.setRepeat(7);
          case 'repeat_10':
            state.setRepeat(10);
          case 'zoom_minus':
            state.setZoom(state.zoom - 0.1);
          case 'zoom_plus':
            state.setZoom(state.zoom + 0.1);
          case 'export_file':
            final path = await ProgressService.instance.exportToFile();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Progress saved to: $path'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          case 'import_file':
            final path = await _findImportFile();
            if (path == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No progress file found'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              final ok = await ProgressService.instance.importFromFile(path);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Progress imported' : 'Import failed'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          case 'reset':
            ProgressService.instance.resetAll();
        }
      },
      itemBuilder:
          (_) => [
            PopupMenuItem(
              value: 'speed_0.5',
              child: Text(state.speed == 0.5 ? 'Speed 0.5× ✓' : 'Speed 0.5×'),
            ),
            PopupMenuItem(
              value: 'speed_0.75',
              child: Text(
                state.speed == 0.75 ? 'Speed 0.75× ✓' : 'Speed 0.75×',
              ),
            ),
            PopupMenuItem(
              value: 'speed_1.0',
              child: Text(state.speed == 1.0 ? 'Speed 1.0× ✓' : 'Speed 1.0×'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'repeat_1',
              child: Text(state.repeat == 1 ? 'Repeat once ✓' : 'Repeat once'),
            ),
            PopupMenuItem(
              value: 'repeat_3',
              child: Text(state.repeat == 3 ? 'Repeat 3× ✓' : 'Repeat 3×'),
            ),
            PopupMenuItem(
              value: 'repeat_7',
              child: Text(state.repeat == 7 ? 'Repeat 7× ✓' : 'Repeat 7×'),
            ),
            PopupMenuItem(
              value: 'repeat_10',
              child: Text(state.repeat == 10 ? 'Repeat 10× ✓' : 'Repeat 10×'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text('Text size: ${(state.zoom * 100).round()}%'),
            ),
            PopupMenuItem(value: 'zoom_minus', child: const Text('Zoom −')),
            PopupMenuItem(value: 'zoom_plus', child: const Text('Zoom +')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'export_file',
              child: Text('Export progress file'),
            ),
            const PopupMenuItem(
              value: 'import_file',
              child: Text('Import progress file'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'reset', child: Text('Reset progress')),
          ],
    );
  }

  Future<String?> _findImportFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/eszero_progress.json');
      if (await file.exists()) return file.path;
    } catch (_) {}
    return null;
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  final int dueCount;
  final String lang;
  const _DueCard({required this.dueCount, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlashcardScreen()),
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                size: 28,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'ar'
                          ? 'كلمات للمراجعة: $dueCount'
                          : lang == 'es'
                          ? 'Palabras para repasar: $dueCount'
                          : 'Words due for review: $dueCount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang == 'ar'
                          ? 'اضغط لبدء المراجعة'
                          : lang == 'es'
                          ? 'Toca para repasar'
                          : 'Tap to review',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
