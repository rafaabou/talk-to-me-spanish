import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/course_models.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/progress_service.dart';
import '../services/notification_service.dart';
import '../services/home_widget_service.dart';
import '../services/progress_file_helper.dart' as file_helper;
import 'lesson_list_screen.dart';
import 'flashcard_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'quiz_screen.dart';
import 'favorites_screen.dart';
import 'grammar_screen.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import 'verb_screen.dart';
import 'stats_screen.dart';
import 'lesson_screen.dart';
import '../services/ui_text.dart';

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
  String? _error;
  String? _lastOpened;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
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
    } catch (e) {
      debugPrint('Failed to load levels: $e');
      if (!mounted || _levels != null) return;
      setState(() {
        _loading = false;
        _error = 'load_failed';
      });
      return;
    }
    // Update home widget
    final totalCompleted =
        _completed
            .where(
              (id) =>
                  id.startsWith('A') ||
                  id.startsWith('B') ||
                  id.startsWith('C'),
            )
            .length;
    try {
      await HomeWidgetService.updateWidget(
        dueCount: _dueCount,
        streak: _streak,
        lessonsCompleted: totalCompleted,
      );
      // Schedule notifications
      await NotificationService.instance.init();
      await NotificationService.instance.updateReviewNotification(_dueCount);
      await NotificationService.instance.scheduleDailyReviewReminder();
      await NotificationService.instance.scheduleStreakNudge();
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
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
    final lang = context.read<AppState>().lang;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uiText(
            lang,
            ar: 'تم نسخ التقدم إلى الحافظة',
            es: 'Progreso copiado al portapapeles',
            other: 'Progress copied to clipboard',
          ),
        ),
        duration: const Duration(seconds: 2),
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

    if (_error != null) {
      return AppSelectionArea(
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  uiText(
                    lang,
                    ar: 'تعذر تحميل المحتوى',
                    es: 'Error al cargar el contenido',
                    other: 'Failed to load content',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
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
            ),
          ),
        ),
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
                    label: uiText(
                      lang,
                      ar: 'بطاقات تعليمية',
                      es: 'Tarjetas de estudio',
                      other: 'Flashcards',
                    ),
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
                    label: uiText(
                      lang,
                      ar: 'بحث',
                      es: 'Buscar',
                      other: 'Search',
                    ),
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
                    label: uiText(
                      lang,
                      ar: 'القواعد',
                      es: 'Gramática',
                      other: 'Grammar',
                    ),
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
                    label: uiText(
                      lang,
                      ar: 'مفضل',
                      es: 'Favoritos',
                      other: 'Favorites',
                    ),
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
                    label: uiText(
                      lang,
                      ar: 'الأفعال',
                      es: 'Verbos',
                      other: 'Verbs',
                    ),
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
                    label: uiText(
                      lang,
                      ar: 'الإحصائيات',
                      es: 'Estadísticas',
                      other: 'Stats',
                    ),
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
              uiText(lang, ar: 'الاختبارات', es: 'Exámenes', other: 'Quizzes'),
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
              uiText(lang, ar: 'الدروس', es: 'Lecciones', other: 'Lessons'),
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
    final label = uiText(
      lang,
      ar: 'اكتملت $done من $total',
      es: '$done de $total lecciones completadas',
      other: '$done of $total lessons completed',
    );
    final streakLabel = uiText(
      lang,
      ar: 'أيام متتالية: $streak',
      es: 'Racha: $streak días',
      other: 'Streak: $streak days',
    );
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
                Flexible(
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          streakLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
    final lang = context.watch<AppState>().lang;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.play_arrow),
        title: Text(
          '${uiText(lang, ar: 'متابعة:', es: 'Continuar:', other: 'Continue:')} $lessonId',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          uiText(
            lang,
            ar: 'استئناف آخر درس',
            es: 'Retomar tu última lección',
            other: 'Resume your last lesson',
          ),
        ),
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
          uiText(
            lang,
            ar: '10 أسئلة',
            es: '10 preguntas',
            other: '10 questions',
          ),
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
          (_) => [
            PopupMenuItem(
              value: ThemeMode.light,
              child: Text(
                uiText(state.lang, ar: 'فاتح', es: 'Claro', other: 'Light'),
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.dark,
              child: Text(
                uiText(state.lang, ar: 'داكن', es: 'Oscuro', other: 'Dark'),
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.system,
              child: Text(
                uiText(
                  state.lang,
                  ar: 'النظام',
                  es: 'Sistema',
                  other: 'System',
                ),
              ),
            ),
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
          case 'open_settings':
            SettingsScreen.open(context);
          case 'export_file':
            final path = await ProgressService.instance.exportToFile();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    uiText(
                      state.lang,
                      ar: 'تم حفظ التقدم في: $path',
                      es: 'Progreso guardado en: $path',
                      other: 'Progress saved to: $path',
                    ),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          case 'import_file':
            final jsonString = await file_helper.pickAndReadFile();
            if (jsonString == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      uiText(
                        state.lang,
                        ar: 'لم يتم اختيار ملف',
                        es: 'Ningún archivo seleccionado',
                        other: 'No file selected',
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              await ProgressService.instance.importData(jsonString);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      uiText(
                        state.lang,
                        ar: 'تم استيراد التقدم',
                        es: 'Progreso importado',
                        other: 'Progress imported',
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          case 'reset':
            final confirmed = await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: Text(
                      uiText(
                        state.lang,
                        ar: 'مسح التقدم',
                        es: 'Borrar progreso',
                        other: 'Reset Progress',
                      ),
                    ),
                    content: Text(
                      uiText(
                        state.lang,
                        ar: 'هل أنت متأكد؟ لن تتمكن من التراجع.',
                        es: '¿Estás seguro? No se podrá deshacer.',
                        other: 'Are you sure? This cannot be undone.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          uiText(
                            state.lang,
                            ar: 'إلغاء',
                            es: 'Cancelar',
                            other: 'Cancel',
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          uiText(
                            state.lang,
                            ar: 'مسح',
                            es: 'Borrar',
                            other: 'Reset',
                          ),
                        ),
                      ),
                    ],
                  ),
            );
            if (confirmed == true) {
              ProgressService.instance.resetAll();
            }
        }
      },
      itemBuilder:
          (_) => [
            PopupMenuItem(
              value: 'speed_0.5',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'السرعة 0.5×',
                    es: 'Velocidad 0.5×',
                    other: 'Speed 0.5×',
                  ),
                  state.speed == 0.5,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'speed_0.75',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'السرعة 0.75×',
                    es: 'Velocidad 0.75×',
                    other: 'Speed 0.75×',
                  ),
                  state.speed == 0.75,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'speed_1.0',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'السرعة 1.0×',
                    es: 'Velocidad 1.0×',
                    other: 'Speed 1.0×',
                  ),
                  state.speed == 1.0,
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'repeat_1',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'تكرار مرة واحدة',
                    es: 'Repetir una vez',
                    other: 'Repeat once',
                  ),
                  state.repeat == 1,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'repeat_3',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'تكرار 3×',
                    es: 'Repetir 3×',
                    other: 'Repeat 3×',
                  ),
                  state.repeat == 3,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'repeat_7',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'تكرار 7×',
                    es: 'Repetir 7×',
                    other: 'Repeat 7×',
                  ),
                  state.repeat == 7,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'repeat_10',
              child: Text(
                _withCheck(
                  uiText(
                    state.lang,
                    ar: 'تكرار 10×',
                    es: 'Repetir 10×',
                    other: 'Repeat 10×',
                  ),
                  state.repeat == 10,
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text(
                '${uiText(state.lang, ar: 'حجم النص:', es: 'Tamaño del texto:', other: 'Text size:')} ${(state.zoom * 100).round()}%',
              ),
            ),
            PopupMenuItem(
              value: 'zoom_minus',
              child: Text(
                uiText(
                  state.lang,
                  ar: 'تصغير',
                  es: 'Reducir zoom',
                  other: 'Zoom −',
                ),
              ),
            ),
            PopupMenuItem(
              value: 'zoom_plus',
              child: Text(
                uiText(
                  state.lang,
                  ar: 'تكبير',
                  es: 'Aumentar zoom',
                  other: 'Zoom +',
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'export_file',
              child: Text(
                uiText(
                  state.lang,
                  ar: 'تصدير ملف التقدم',
                  es: 'Exportar archivo de progreso',
                  other: 'Export progress file',
                ),
              ),
            ),
            PopupMenuItem(
              value: 'import_file',
              child: Text(
                uiText(
                  state.lang,
                  ar: 'استيراد ملف التقدم',
                  es: 'Importar archivo de progreso',
                  other: 'Import progress file',
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'open_settings',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    uiText(
                      state.lang,
                      ar: 'كل الإعدادات',
                      es: 'Todos los ajustes',
                      other: 'All settings',
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'reset',
              child: Text(
                uiText(
                  state.lang,
                  ar: 'إعادة تعيين التقدم',
                  es: 'Restablecer progreso',
                  other: 'Reset progress',
                ),
              ),
            ),
          ],
    );
  }

  String _withCheck(String label, bool checked) => checked ? '$label ✓' : label;
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
              MaterialPageRoute(
                builder: (_) => const FlashcardScreen(weakestFirst: true),
              ),
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
                      uiText(
                        lang,
                        ar: 'كلمات للمراجعة: $dueCount',
                        es: 'Palabras para repasar: $dueCount',
                        other: 'Words due for review: $dueCount',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uiText(
                        lang,
                        ar: 'ابدأ بالأضعف — اضغط للمراجعة',
                        es: 'Empieza por las más débiles — toca para repasar',
                        other: 'Weakest first — tap to review',
                      ),
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
