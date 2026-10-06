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
  static const _bgSyncKey = 'bg_sync_signature';
  static const _streakKey = 'streak';
  static const _lastStudyKey = 'last_study';
  static const _studyDaysKey = 'study_days';
  static const _srsKey = 'srs_fsrs';
  static const _lastOpenedKey = 'last_opened_lesson';
  static const _notesKey = 'lesson_notes';
  static const _onboardingKey = 'onboarding_done';
  static const _accessibilityKey = 'accessibility_settings';
  static const _repeatCountKey = 'repeat_count';
  static const _flashcardsReviewedKey = 'flashcards_reviewed';
  static const _quizzesTakenKey = 'quizzes_taken';
  static const _speakingDoneKey = 'speaking_done';
  static const _speakingItemsKey = 'speaking_items_done';

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
    await prefs.remove(_flashcardsReviewedKey);
    await prefs.remove(_quizzesTakenKey);
    await prefs.remove(_speakingDoneKey);
    await prefs.remove('achievements_unlocked');
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

  /// Last home-widget/notification sync signature, so reopening the app with
  /// unchanged progress does not repeat five platform-channel round trips.
  Future<String?> getBackgroundSyncSignature() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bgSyncKey);
  }

  Future<void> setBackgroundSyncSignature(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgSyncKey, value);
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

  Future<int> getFlashcardsReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_flashcardsReviewedKey) ?? 0;
  }

  Future<void> incrementFlashcardsReviewed(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_flashcardsReviewedKey) ?? 0;
    await prefs.setInt(_flashcardsReviewedKey, current + count);
  }

  Future<int> getQuizzesTaken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_quizzesTakenKey) ?? 0;
  }

  Future<void> incrementQuizzesTaken() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_quizzesTakenKey) ?? 0;
    await prefs.setInt(_quizzesTakenKey, current + 1);
  }

  Future<int> getSpeakingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_speakingDoneKey) ?? 0;
  }

  /// Which speaking items are complete, keyed `<lessonId>::<index>`. The
  /// count alone cannot restore the ticks when a lesson is reopened, which
  /// used to reset the section and double-count on the next tap.
  Future<Set<String>> getSpeakingItemsDone() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_speakingItemsKey) ?? const []).toSet();
  }

  Future<bool> toggleSpeakingItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final done = (prefs.getStringList(_speakingItemsKey) ?? const []).toSet();
    final nowDone = !done.remove(key);
    if (nowDone) done.add(key);
    await prefs.setStringList(_speakingItemsKey, done.toList()..sort());
    final count = await getSpeakingDone();
    await prefs.setInt(_speakingDoneKey, count + (nowDone ? 1 : -1));
    return nowDone;
  }

  Future<void> incrementSpeakingDone() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_speakingDoneKey) ?? 0;
    await prefs.setInt(_speakingDoneKey, current + 1);
  }

  Future<void> decrementSpeakingDone() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_speakingDoneKey) ?? 0;
    if (current > 0) {
      await prefs.setInt(_speakingDoneKey, current - 1);
    }
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
      'v': 2,
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
      'speaking_done': prefs.getInt(_speakingDoneKey) ?? 0,
      'speaking_items': prefs.getStringList(_speakingItemsKey) ?? const [],
      'exported': DateTime.now().toIso8601String(),
    });
  }

  /// Restores a backup exported by [exportData].
  ///
  /// The whole payload is parsed and checked before a single key is written,
  /// so a truncated or hand-edited file cannot leave progress half-imported.
  /// Throws [FormatException] when the file is not a usable backup.
  Future<void> importData(String jsonString) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      rethrow;
    }
    if (decoded is! Map) {
      throw const FormatException('Backup must be a JSON object');
    }
    final data = decoded.cast<String, dynamic>();
    // Export version: 1 = legacy (pre-1.10.1, no speaking items), 2 = current.
    // Absent means legacy; unsupported (>= 3 / non-int) is refused so we never
    // silently mis-import a future schema.
    final ver = data['v'];
    if (ver != null) {
      if (ver is! int || ver < 1 || ver > 2) {
        throw FormatException('Unsupported backup version: $ver');
      }
    }

    List<String> readList(String name) {
      final raw = data[name];
      if (raw == null) return const [];
      if (raw is! List) {
        throw FormatException('Backup field "$name" must be a list');
      }
      return raw.map((e) => e.toString()).toList();
    }

    // Parse everything up front; nothing is written until this succeeds.
    final completed = readList('completed');
    final exercises = readList('exercises');
    final favorites = readList('favorites');
    final streak = data['streak'];
    final lastStudy = data['last_study'];
    final lastOpened = data['last_opened'];
    final repeatCount = data['repeat_count'];
    final speakingDone = data['speaking_done'];
    final notes = data['notes'];
    final accessibility = data['accessibility'];
    if (streak != null && streak is! int) {
      throw const FormatException('Backup field "streak" must be a number');
    }
    if (notes != null && notes is! Map) {
      throw const FormatException('Backup field "notes" must be an object');
    }
    Map<String, FsrsCard>? cards;
    if (data['srs'] != null) {
      final raw = data['srs'];
      if (raw is! List) {
        throw const FormatException('Backup field "srs" must be a list');
      }
      cards = <String, FsrsCard>{};
      for (final c in raw) {
        if (c is! Map) {
          throw const FormatException('Backup field "srs" is malformed');
        }
        final card = FsrsCard.fromJson(c.cast<String, dynamic>());
        cards[card.key] = card;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, completed);
    await prefs.setStringList(_exercisesKey, exercises);
    await prefs.setStringList(_favoritesKey, favorites);
    if (streak is int) await prefs.setInt(_streakKey, streak);
    if (lastStudy is String) await prefs.setString(_lastStudyKey, lastStudy);
    if (cards != null) await _saveFsrsCards(cards);
    if (lastOpened is String) await prefs.setString(_lastOpenedKey, lastOpened);
    if (notes is Map) await prefs.setString(_notesKey, jsonEncode(notes));
    if (accessibility is Map) {
      await prefs.setString(_accessibilityKey, jsonEncode(accessibility));
    }
    if (repeatCount is int) await prefs.setInt(_repeatCountKey, repeatCount);
    if (speakingDone is int) await prefs.setInt(_speakingDoneKey, speakingDone);
    final speakingItems = data['speaking_items'];
    if (speakingItems is List) {
      await prefs.setStringList(
        _speakingItemsKey,
        speakingItems.map((e) => e.toString()).toList()..sort(),
      );
    }
  }

  Future<String?> exportToFile() async {
    final path = await file_helper.exportToFile(await exportData());
    return path;
  }

  /// Imports from a known path. Returns false instead of throwing so a
  /// missing or malformed file leaves the existing progress untouched.
  Future<bool> importFromFile(String path) async {
    final content = await file_helper.readFromFile(path);
    if (content == null || content.isEmpty) return false;
    try {
      await importData(content);
      return true;
    } on FormatException catch (e) {
      debugPrint('Import rejected: ${e.message}');
      return false;
    }
  }

  /// Restores a backup the user chose: a file dialog on the web, the app's own
  /// last export on a phone (there is no system file picker wired up).
  /// Returns false when nothing usable was found.
  Future<bool> importFromPicker() async {
    final content = await file_helper.pickAndReadFile();
    if (content == null || content.isEmpty) return false;
    try {
      await importData(content);
      return true;
    } on FormatException catch (e) {
      debugPrint('Import rejected: ${e.message}');
      return false;
    }
  }
}
