import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_file_helper.dart' as file_helper;
import 'course_repository.dart';
import 'fsrs.dart';

class ProgressService {
  static final ProgressService instance = ProgressService._();
  ProgressService._();

  static const _key = 'completed_lessons';
  static const _exercisesKey = 'completed_exercises';
  static const _favoritesKey = 'favorite_words';
  static const _streakKey = 'streak';
  static const _lastStudyKey = 'last_study';
  static const _studyDaysKey = 'study_days';
  static const _srsKey = 'srs_fsrs';
  static const _lastOpenedKey = 'last_opened_lesson';
  static const _notesKey = 'lesson_notes';
  static const _onboardingKey = 'onboarding_done';
  static const _accessibilityKey = 'accessibility_settings';
  static const _repeatCountKey = 'repeat_count';

  final FsrsScheduler _fsrs = FsrsScheduler();

  Future<void> setLastOpened(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey, lessonId);
  }

  Future<String?> getLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenedKey);
  }

  Future<Map<String, FsrsCard>> _loadFsrsCards() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_srsKey) ?? [];
    final map = <String, FsrsCard>{};
    for (final entry in list) {
      try {
        final card = FsrsCard.fromJson(
          jsonDecode(entry) as Map<String, dynamic>,
        );
        map[card.key] = card;
      } catch (e) {
        debugPrint('Failed to parse FSRS card: $e');
      }
    }
    return map;
  }

  Future<void> _saveFsrsCards(Map<String, FsrsCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _srsKey,
      cards.values.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> _migrateLeitnerToFsrs() async {
    final prefs = await SharedPreferences.getInstance();
    final fsrsExists = prefs.containsKey(_srsKey);
    if (fsrsExists) return;

    final leitnerKey = 'srs';
    final leitnerList = prefs.getStringList(leitnerKey) ?? [];
    if (leitnerList.isEmpty) return;

    final now = DateTime.now();
    final fsrsCards = <String, FsrsCard>{};

    for (final entry in leitnerList) {
      final parts = entry.split('|');
      if (parts.length != 3) continue;
      final key = parts[0];
      final box = int.tryParse(parts[1]) ?? 0;
      final due = DateTime.tryParse(parts[2]);
      if (due == null) continue;

      final stability = [0.0, 0.5, 1.0, 3.0, 10.0, 30.0][box.clamp(0, 5)];
      final difficulty = 5.0;

      fsrsCards[key] = FsrsCard(
        key: key,
        due: due,
        stability: stability,
        difficulty: difficulty,
        lastReview: now.subtract(
          Duration(days: due.difference(now).inDays.abs()),
        ),
        reviews: box,
        lapses: 0,
      );
    }

    await _saveFsrsCards(fsrsCards);
    await prefs.remove(leitnerKey);
  }

  Future<Map<String, FsrsCard>> getFsrsCards() async {
    await _migrateLeitnerToFsrs();
    return _loadFsrsCards();
  }

  Future<Map<String, FsrsCard>> getDueFsrsCards() async {
    final cards = await getFsrsCards();
    final now = DateTime.now();
    return Map.fromEntries(
      cards.entries.where((e) => !e.value.due.isAfter(now)),
    );
  }

  Future<void> markSrs(String wordKey, {required bool known}) async {
    await _migrateLeitnerToFsrs();
    final cards = await _loadFsrsCards();
    final now = DateTime.now();

    final existing = cards[wordKey];
    FsrsCard updated;
    if (existing == null) {
      updated = _fsrs.firstReview(wordKey, known ? 3 : 1, now);
    } else {
      updated = _fsrs.reviewCard(existing, known ? 3 : 1, now);
    }

    cards[wordKey] = updated;
    await _saveFsrsCards(cards);
  }

  Future<int> getDueWordCount() async {
    final due = await getDueFsrsCards();
    return due.length;
  }

  Future<Set<String>> getCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  Future<void> markCompleted(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (!list.contains(lessonId)) {
      list.add(lessonId);
      await prefs.setStringList(_key, list);
    }
    await _bumpStreak();
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_exercisesKey);
    await prefs.remove(_favoritesKey);
    await prefs.remove(_streakKey);
    await prefs.remove(_lastStudyKey);
    await prefs.remove(_studyDaysKey);
    await prefs.remove(_srsKey);
    await prefs.remove(_lastOpenedKey);
    await prefs.remove(_notesKey);
    await prefs.remove(_onboardingKey);
    await prefs.remove(_accessibilityKey);
    await prefs.remove(_repeatCountKey);
    for (final key in prefs.getKeys().where(
      (k) => k.startsWith('quiz_best_'),
    )) {
      await prefs.remove(key);
    }
  }

  Future<bool> isCompleted(String lessonId) async {
    final completed = await getCompleted();
    return completed.contains(lessonId);
  }

  Future<Set<String>> getCompletedExercises() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_exercisesKey)?.toSet() ?? {};
  }

  Future<void> toggleExerciseDone(String exerciseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_exercisesKey) ?? [];
    if (list.contains(exerciseKey)) {
      list.remove(exerciseKey);
    } else {
      list.add(exerciseKey);
    }
    await prefs.setStringList(_exercisesKey, list);
  }

  Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey)?.toSet() ?? {};
  }

  Future<void> toggleFavorite(String wordKey) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    if (list.contains(wordKey)) {
      list.remove(wordKey);
    } else {
      list.add(wordKey);
    }
    await prefs.setStringList(_favoritesKey, list);
  }

  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  Future<int> getQuizBest(String levelId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('quiz_best_$levelId') ?? 0;
  }

  Future<void> setQuizBest(String levelId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt('quiz_best_$levelId') ?? 0;
    if (score > best) {
      await prefs.setInt('quiz_best_$levelId', score);
    }
  }

  Future<void> _bumpStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final last = prefs.getString(_lastStudyKey) ?? '';
    if (last == today) return;
    final streak = prefs.getInt(_streakKey) ?? 0;
    if (last.isEmpty) {
      await prefs.setInt(_streakKey, 1);
    } else {
      final lastDate = DateTime.tryParse(last);
      final yesterday = now.subtract(const Duration(days: 1));
      if (lastDate != null &&
          lastDate.year == yesterday.year &&
          lastDate.month == yesterday.month &&
          lastDate.day == yesterday.day) {
        await prefs.setInt(_streakKey, streak + 1);
      } else {
        await prefs.setInt(_streakKey, 1);
      }
    }
    await prefs.setString(_lastStudyKey, today);
    final studyDays = prefs.getStringList(_studyDaysKey) ?? [];
    if (!studyDays.contains(today)) {
      studyDays.add(today);
      await prefs.setStringList(_studyDaysKey, studyDays);
    }
  }

  Future<List<DateTime>> getStudyDays() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_studyDaysKey) ?? [];
    return list.map((s) => DateTime.tryParse(s)).whereType<DateTime>().toList();
  }

  Future<String> getLessonNotes(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final map =
        jsonDecode(prefs.getString(_notesKey) ?? '{}') as Map<String, dynamic>;
    return map[lessonId] as String? ?? '';
  }

  Future<void> setLessonNotes(String lessonId, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    final map =
        jsonDecode(prefs.getString(_notesKey) ?? '{}') as Map<String, dynamic>;
    map[lessonId] = notes;
    await prefs.setString(_notesKey, jsonEncode(map));
  }

  Future<bool> getOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  Future<Map<String, dynamic>> getAccessibilitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString(_accessibilityKey) ?? '{}')
        as Map<String, dynamic>;
  }

  Future<void> setAccessibilitySettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessibilityKey, jsonEncode(settings));
  }

  Future<int> getRepeatCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_repeatCountKey) ?? 1;
  }

  Future<void> setRepeatCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_repeatCountKey, count);
  }

  Future<String> exportSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_key) ?? [];
    final exercises = prefs.getStringList(_exercisesKey) ?? [];
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    final streak = prefs.getInt(_streakKey) ?? 0;
    final fsrsCards = await getFsrsCards();
    final dueCount =
        fsrsCards.values.where((c) => !c.due.isAfter(DateTime.now())).length;
    final levels = await CourseRepository.instance.loadLevels();
    var totalLessons = 0;
    for (final level in levels.values) {
      totalLessons += level.lessons.length;
    }
    return 'Talk To Me Spanish By Mohamed Rafaa Tounekti — Progress\n'
        'Lessons completed: ${completed.length}/$totalLessons\n'
        'Exercises completed: ${exercises.length}\n'
        'Favorite words: ${favorites.length}\n'
        'Day streak: $streak\n'
        'Words due for review: $dueCount\n'
        'Exported: ${DateTime.now().toIso8601String()}';
  }

  Future<String> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonEncode({
      'completed': prefs.getStringList(_key) ?? [],
      'exercises': prefs.getStringList(_exercisesKey) ?? [],
      'favorites': prefs.getStringList(_favoritesKey) ?? [],
      'streak': prefs.getInt(_streakKey) ?? 0,
      'last_study': prefs.getString(_lastStudyKey) ?? '',
      'srs': (await getFsrsCards()).values.map((c) => c.toJson()).toList(),
      'last_opened': prefs.getString(_lastOpenedKey) ?? '',
      'notes': jsonDecode(prefs.getString(_notesKey) ?? '{}'),
      'accessibility': jsonDecode(prefs.getString(_accessibilityKey) ?? '{}'),
      'repeat_count': prefs.getInt(_repeatCountKey) ?? 1,
      'exported': DateTime.now().toIso8601String(),
    });
  }

  Future<void> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        (data['completed'] as List? ?? []).cast<String>(),
      );
      await prefs.setStringList(
        _exercisesKey,
        (data['exercises'] as List? ?? []).cast<String>(),
      );
      await prefs.setStringList(
        _favoritesKey,
        (data['favorites'] as List? ?? []).cast<String>(),
      );
      if (data['streak'] is int) {
        await prefs.setInt(_streakKey, data['streak'] as int);
      }
      if (data['last_study'] is String) {
        await prefs.setString(_lastStudyKey, data['last_study'] as String);
      }
      if (data['srs'] is List) {
        final cards = <String, FsrsCard>{};
        for (final c in data['srs']) {
          final card = FsrsCard.fromJson(c as Map<String, dynamic>);
          cards[card.key] = card;
        }
        await _saveFsrsCards(cards);
      }
      if (data['last_opened'] is String) {
        await prefs.setString(_lastOpenedKey, data['last_opened'] as String);
      }
      if (data['notes'] is Map) {
        await prefs.setString(_notesKey, jsonEncode(data['notes']));
      }
      if (data['accessibility'] is Map) {
        await prefs.setString(
          _accessibilityKey,
          jsonEncode(data['accessibility']),
        );
      }
      if (data['repeat_count'] is int) {
        await prefs.setInt(_repeatCountKey, data['repeat_count'] as int);
      }
    } catch (e) {
      debugPrint('Import data failed: $e');
    }
  }

  Future<String?> exportToFile() async {
    final path = await file_helper.exportToFile(await exportData());
    return path;
  }

  Future<bool> importFromFile(String path) async {
    final content = await file_helper.readFromFile(path);
    if (content == null || content.isEmpty) return false;
    await importData(content);
    return true;
  }
}
