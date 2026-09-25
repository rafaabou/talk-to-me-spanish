import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String icon;
  final String titleEn;
  final String titleEs;
  final String titleAr;
  final String descEn;
  final String descEs;
  final String descAr;
  final bool Function(AchievementProgress) check;

  Achievement({
    required this.id,
    required this.icon,
    required this.titleEn,
    required this.titleEs,
    required this.titleAr,
    required this.descEn,
    required this.descEs,
    required this.descAr,
    required this.check,
  });
}

class AchievementProgress {
  final int lessonsCompleted;
  final int exercisesCompleted;
  final int favorites;
  final int streak;
  final int flashcardsReviewed;
  final int quizzesTaken;
  final int verbsExplored;
  final int daysStudied;
  final int speakingDone;
  final bool backupDone;

  AchievementProgress({
    required this.lessonsCompleted,
    required this.exercisesCompleted,
    required this.favorites,
    required this.streak,
    required this.flashcardsReviewed,
    required this.quizzesTaken,
    required this.verbsExplored,
    required this.daysStudied,
    required this.speakingDone,
    required this.backupDone,
  });
}

class AchievementService {
  static final AchievementService instance = AchievementService._();
  AchievementService._();

  static const _unlockedKey = 'achievements_unlocked';

  final List<Achievement> all = [
    Achievement(
      id: 'first_lesson',
      icon: '📖',
      titleEn: 'First Steps',
      titleEs: 'Primeros Pasos',
      titleAr: 'خطوات أولى',
      descEn: 'Complete your first lesson',
      descEs: 'Completa tu primera lección',
      descAr: 'أكمل درسك الأول',
      check: (p) => p.lessonsCompleted >= 1,
    ),
    Achievement(
      id: 'five_lessons',
      icon: '📚',
      titleEn: 'Student',
      titleEs: 'Estudiante',
      titleAr: 'طالب',
      descEn: 'Complete 5 lessons',
      descEs: 'Completa 5 lecciones',
      descAr: 'أكمل 5 دروس',
      check: (p) => p.lessonsCompleted >= 5,
    ),
    Achievement(
      id: 'twenty_lessons',
      icon: '🎓',
      titleEn: 'Scholar',
      titleEs: 'Estudioso',
      titleAr: 'طالب علم',
      descEn: 'Complete 20 lessons',
      descEs: 'Completa 20 lecciones',
      descAr: 'أكمل 20 درساً',
      check: (p) => p.lessonsCompleted >= 20,
    ),
    Achievement(
      id: 'fifty_lessons',
      icon: '🏅',
      titleEn: 'Master',
      titleEs: 'Maestro',
      titleAr: 'خبير',
      descEn: 'Complete 50 lessons',
      descEs: 'Completa 50 lecciones',
      descAr: 'أكمل 50 درساً',
      check: (p) => p.lessonsCompleted >= 50,
    ),
    Achievement(
      id: 'all_lessons',
      icon: '🏆',
      titleEn: 'Graduate',
      titleEs: 'Graduado',
      titleAr: 'خريج',
      descEn: 'Complete all 72 lessons',
      descEs: 'Completa las 72 lecciones',
      descAr: 'أكمل جميع الدروس الـ 72',
      check: (p) => p.lessonsCompleted >= 72,
    ),
    Achievement(
      id: 'first_exercise',
      icon: '✏️',
      titleEn: 'Getting Started',
      titleEs: 'Comenzando',
      titleAr: 'بداية',
      descEn: 'Complete 10 exercises',
      descEs: 'Completa 10 ejercicios',
      descAr: 'أكمل 10 تمارين',
      check: (p) => p.exercisesCompleted >= 10,
    ),
    Achievement(
      id: 'hundred_exercises',
      icon: '💪',
      titleEn: 'Practice Makes Perfect',
      titleEs: 'La Práctica Hace al Maestro',
      titleAr: 'الPractice تؤدي إلى الكمال',
      descEn: 'Complete 100 exercises',
      descEs: 'Completa 100 ejercicios',
      descAr: 'أكمل 100 تمرين',
      check: (p) => p.exercisesCompleted >= 100,
    ),
    Achievement(
      id: 'five_hundred_exercises',
      icon: '🔥',
      titleEn: 'Exercise Master',
      titleEs: 'Maestro de Ejercicios',
      titleAr: 'خبير التمارين',
      descEn: 'Complete 500 exercises',
      descEs: 'Completa 500 ejercicios',
      descAr: 'أكمل 500 تمرين',
      check: (p) => p.exercisesCompleted >= 500,
    ),
    Achievement(
      id: 'first_favorite',
      icon: '⭐',
      titleEn: 'Collector',
      titleEs: 'Coleccionista',
      titleAr: 'جامع',
      descEn: 'Add 5 words to favorites',
      descEs: 'Agrega 5 palabras a favoritos',
      descAr: 'أضف 5 كلمات للمفضلة',
      check: (p) => p.favorites >= 5,
    ),
    Achievement(
      id: 'streak_3',
      icon: '🔥',
      titleEn: 'On Fire',
      titleEs: 'En Llamas',
      titleAr: 'في الطريق',
      descEn: 'Study 3 days in a row',
      descEs: 'Estudia 3 días seguidos',
      descAr: 'ادرس 3 أيام متتالية',
      check: (p) => p.streak >= 3,
    ),
    Achievement(
      id: 'streak_7',
      icon: '🔥',
      titleEn: 'Week Warrior',
      titleEs: 'Guerrero de la Semana',
      titleAr: 'محارب الأسبوع',
      descEn: 'Study 7 days in a row',
      descEs: 'Estudia 7 días seguidos',
      descAr: 'ادرس 7 أيام متتالية',
      check: (p) => p.streak >= 7,
    ),
    Achievement(
      id: 'streak_30',
      icon: '💎',
      titleEn: 'Monthly Champion',
      titleEs: 'Campeón Mensual',
      titleAr: 'بطل الشهر',
      descEn: 'Study 30 days in a row',
      descEs: 'Estudia 30 días seguidos',
      descAr: 'ادرس 30 يوماً متتالياً',
      check: (p) => p.streak >= 30,
    ),
    Achievement(
      id: 'quiz_perfect',
      icon: '🎯',
      titleEn: 'Perfect Score',
      titleEs: 'Puntuación Perfecta',
      titleAr: 'نتيجة مثالية',
      descEn: 'Get 10/10 on any quiz',
      descEs: 'Obtén 10/10 en cualquier prueba',
      descAr: 'احصل على 10/10 في أي اختبار',
      check: (p) => p.quizzesTaken >= 1,
    ),
    Achievement(
      id: 'flashcards_50',
      icon: '🧠',
      titleEn: 'Brain Trainer',
      titleEs: 'Entrenador Cerebral',
      titleAr: 'مدرس الدماغ',
      descEn: 'Review 50 flashcards',
      descEs: 'Revisa 50 tarjetas',
      descAr: 'راجع 50 بطاقة تعليمية',
      check: (p) => p.flashcardsReviewed >= 50,
    ),
    Achievement(
      id: 'flashcards_200',
      icon: '🧩',
      titleEn: 'Memory Master',
      titleEs: 'Maestro de la Memoria',
      titleAr: 'خبير الذاكرة',
      descEn: 'Review 200 flashcards',
      descEs: 'Revisa 200 tarjetas',
      descAr: 'راجع 200 بطاقة تعليمية',
      check: (p) => p.flashcardsReviewed >= 200,
    ),
    Achievement(
      id: 'explorer',
      icon: '🗺️',
      titleEn: 'Explorer',
      titleEs: 'Explorador',
      titleAr: 'مستكشف',
      descEn: 'Study on 10 different days',
      descEs: 'Estudia en 10 días diferentes',
      descAr: 'ادرس في 10 أيام مختلفة',
      check: (p) => p.daysStudied >= 10,
    ),
    Achievement(
      id: 'dedicated',
      icon: '🌟',
      titleEn: 'Dedicated Learner',
      titleEs: 'Estudiante Dedicado',
      titleAr: 'طالب مجتهد',
      descEn: 'Study on 30 different days',
      descEs: 'Estudia en 30 días diferentes',
      descAr: 'ادرس في 30 يوماً مختلفاً',
      check: (p) => p.daysStudied >= 30,
    ),
    Achievement(
      id: 'voice_master',
      icon: '🎤',
      titleEn: 'Voice Master',
      titleEs: 'Maestro de la Voz',
      titleAr: 'خبير الصوت',
      descEn: 'Complete 10 speaking exercises',
      descEs: 'Completa 10 ejercicios de habla',
      descAr: 'أكمل 10 تمارين تحدث',
      check: (p) => p.speakingDone >= 10,
    ),
    Achievement(
      id: 'backup_champion',
      icon: '🛡️',
      titleEn: 'Data Guardian',
      titleEs: 'Guardián de Datos',
      titleAr: 'حارس البيانات',
      descEn: 'Export your progress for the first time',
      descEs: 'Exporta tu progreso por primera vez',
      descAr: 'صدر تقدمك للمرة الأولى',
      check: (p) => p.backupDone,
    ),
  ];

  Future<Set<String>> _getUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedKey)?.toSet() ?? {};
  }

  Future<void> _saveUnlocked(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, ids.toList());
  }

  Future<List<Achievement>> getUnlocked() async {
    final ids = await _getUnlocked();
    return all.where((a) => ids.contains(a.id)).toList();
  }

  Future<List<Achievement>> checkNew(AchievementProgress progress) async {
    final unlocked = await _getUnlocked();
    final newOnes = <Achievement>[];
    for (final a in all) {
      if (!unlocked.contains(a.id) && a.check(progress)) {
        newOnes.add(a);
        unlocked.add(a.id);
      }
    }
    if (newOnes.isNotEmpty) {
      await _saveUnlocked(unlocked);
    }
    return newOnes;
  }
}
