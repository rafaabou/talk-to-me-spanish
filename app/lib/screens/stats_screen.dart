import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/app_state.dart';
import '../services/course_repository.dart';
import '../services/progress_service.dart';
import '../widgets/app_selection_area.dart';
import '../widgets/credit_footer.dart';
import 'dart:async';
import '../services/ui_text.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _loading = true;
  int _lessons = 0;
  int _exercises = 0;
  int _favorites = 0;
  int _streak = 0;
  final int _totalLessons = 72;
  int _totalExercises = 0;
  Map<String, int> _quizBest = {};
  List<DateTime> _studyDays = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await ProgressService.instance.getCompleted();
    final exercises = await ProgressService.instance.getCompletedExercises();
    final favorites = await ProgressService.instance.getFavorites();
    final streak = await ProgressService.instance.getStreak();
    final studyDays = await ProgressService.instance.getStudyDays();

    var totalExercises = 0;
    final levels = await CourseRepository.instance.loadLevels();
    for (final level in levels.values) {
      for (final lessonMeta in level.lessons) {
        final id = lessonMeta['id'] as String;
        final lesson = await CourseRepository.instance.tryLoadLesson(id);
        if (lesson != null) totalExercises += lesson.exercises.length;
      }
    }

    final quizBest = <String, int>{};
    for (final level in levels.keys) {
      quizBest[level] = await ProgressService.instance.getQuizBest(level);
    }

    if (!mounted) return;
    setState(() {
      _lessons = completed.length;
      _exercises = exercises.length;
      _favorites = favorites.length;
      _streak = streak;
      _totalExercises = totalExercises;
      _quizBest = quizBest;
      _studyDays = studyDays;
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
              ar: 'الإحصائيات',
              es: 'Estadísticas',
              other: 'Statistics',
            ),
          ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _StatCard(
                      icon: Icons.school,
                      label: uiText(
                        lang,
                        ar: 'الدروس المكتملة',
                        es: 'Lecciones completadas',
                        other: 'Lessons completed',
                      ),
                      value: '$_lessons/$_totalLessons',
                    ),
                    _StatCard(
                      icon: Icons.assignment_turned_in,
                      label: uiText(
                        lang,
                        ar: 'التمارين المكتملة',
                        es: 'Ejercicios completados',
                        other: 'Exercises completed',
                      ),
                      value: '$_exercises/$_totalExercises',
                    ),
                    _StatCard(
                      icon: Icons.star,
                      label: uiText(
                        lang,
                        ar: 'الكلمات المفضلة',
                        es: 'Palabras favoritas',
                        other: 'Favorite words',
                      ),
                      value: '$_favorites',
                    ),
                    _StatCard(
                      icon: Icons.local_fire_department,
                      label: uiText(
                        lang,
                        ar: 'أيام متتالية',
                        es: 'Días consecutivos',
                        other: 'Day streak',
                      ),
                      value: '$_streak',
                    ),
                    const SizedBox(height: 12),
                    _StreakCalendar(studyDays: _studyDays, lang: lang),
                    const SizedBox(height: 12),
                    _ActivityChart(studyDays: _studyDays, lang: lang),
                    const SizedBox(height: 12),
                    Text(
                      uiText(
                        lang,
                        ar: 'أفضل نتائج الاختبارات',
                        es: 'Mejores resultados de exámenes',
                        other: 'Best quiz scores',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final entry in _quizBest.entries)
                      _StatCard(
                        icon: Icons.quiz,
                        label: entry.key,
                        value: '${entry.value}/10',
                      ),
                    const CreditFooter(),
                  ],
                ),
      ),
    );
  }
}

class _StreakCalendar extends StatelessWidget {
  final List<DateTime> studyDays;
  final String lang;
  const _StreakCalendar({required this.studyDays, required this.lang});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final firstWeekday = monthStart.weekday % 7; // 0 = Sunday
    final daysInMonth = monthEnd.day;
    final studySet =
        studyDays.map((d) => '${d.year}-${d.month}-${d.day}').toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiText(
                lang,
                ar: 'تقويم النشاط',
                es: 'Calendario de Actividad',
                other: 'Activity Calendar',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (d) => Text(
                          d,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, i) {
                if (i < firstWeekday) return const SizedBox();
                final day = i - firstWeekday + 1;
                final key = '${now.year}-${now.month}-$day';
                final studied = studySet.contains(key);
                final isToday = day == now.day;
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          studied
                              ? Theme.of(context).colorScheme.primary
                              : isToday
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                      border:
                          isToday && !studied
                              ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              )
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              studied
                                  ? Colors.white
                                  : Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<DateTime> studyDays;
  final String lang;
  const _ActivityChart({required this.studyDays, required this.lang});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last14 = List.generate(
      14,
      (i) => now.subtract(Duration(days: 13 - i)),
    );
    final studySet =
        studyDays.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiText(
                lang,
                ar: 'نشاط 14 يوماً',
                es: 'Actividad de los últimos 14 días',
                other: '14-day Activity',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.5,
                  minY: 0,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < 14) {
                            final day = last14[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${day.day}/${day.month}',
                                style: const TextStyle(fontSize: 8),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                        reservedSize: 8,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(14, (i) {
                    final studied = studySet.contains(
                      DateTime(last14[i].year, last14[i].month, last14[i].day),
                    );
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: studied ? 1.0 : 0.0,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          color:
                              studied
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
