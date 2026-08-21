import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_to_me_spanish/services/fsrs.dart';
import 'package:talk_to_me_spanish/services/progress_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('quiz best score', () {
    test('should_store_first_score', () async {
      await ProgressService.instance.setQuizBest('A1', 5);
      expect(await ProgressService.instance.getQuizBest('A1'), 5);
    });

    test('should_keep_maximum_when_lower_score_reported', () async {
      await ProgressService.instance.setQuizBest('A1', 7);
      await ProgressService.instance.setQuizBest('A1', 3);
      expect(await ProgressService.instance.getQuizBest('A1'), 7);
    });

    test('should_update_when_higher_score_reported', () async {
      await ProgressService.instance.setQuizBest('A1', 4);
      await ProgressService.instance.setQuizBest('A1', 9);
      expect(await ProgressService.instance.getQuizBest('A1'), 9);
    });

    test('should_default_to_zero_for_unknown_level', () async {
      expect(await ProgressService.instance.getQuizBest('C2'), 0);
    });
  });

  group('lesson completion', () {
    test('should_mark_and_report_completed_lessons', () async {
      await ProgressService.instance.markCompleted('A1-01');
      await ProgressService.instance.markCompleted('A1-02');
      await ProgressService.instance.markCompleted('A1-01');
      final completed = await ProgressService.instance.getCompleted();
      expect(completed.length, 2);
      expect(
        await ProgressService.instance.isCompleted('A1-01'),
        isTrue,
      );
    });

    test('should_start_streak_at_1_and_not_double_count_same_day', () async {
      await ProgressService.instance.markCompleted('A1-01');
      expect(await ProgressService.instance.getStreak(), 1);
      await ProgressService.instance.markCompleted('A1-02');
      expect(await ProgressService.instance.getStreak(), 1);
      final days = await ProgressService.instance.getStudyDays();
      expect(days.length, 1);
    });
  });

  group('favorites and exercises', () {
    test('should_toggle_favorite_word', () async {
      await ProgressService.instance.toggleFavorite('casa');
      expect(await ProgressService.instance.getFavorites(), {'casa'});
      await ProgressService.instance.toggleFavorite('casa');
      expect(await ProgressService.instance.getFavorites(), isEmpty);
    });

    test('should_toggle_exercise_done', () async {
      final key = 'A1-01/exercises/0';
      await ProgressService.instance.toggleExerciseDone(key);
      expect(
        await ProgressService.instance.getCompletedExercises(),
        {key},
      );
      await ProgressService.instance.toggleExerciseDone(key);
      expect(await ProgressService.instance.getCompletedExercises(), isEmpty);
    });
  });

  group('Leitner to FSRS migration', () {
    test('should_migrate_leitner_boxes_and_remove_legacy_key', () async {
      SharedPreferences.setMockInitialValues({
        'srs': [
          'word1|2|2026-01-10T00:00:00.000',
          'word2|0|2026-02-01T00:00:00.000',
        ],
      });

      final cards = await ProgressService.instance.getFsrsCards();
      expect(cards.keys, containsAll(['word1', 'word2']));
      expect(cards['word1']!.stability, 1.0);
      expect(cards['word1']!.reviews, 2);
      expect(cards['word2']!.stability, 0.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('srs'), isFalse);
      expect(prefs.containsKey('srs_fsrs'), isTrue);

      final again = await ProgressService.instance.getFsrsCards();
      expect(again.length, 2);
    });

    test('should_skip_corrupt_leitner_entries', () async {
      SharedPreferences.setMockInitialValues({
        'srs': ['garbage'],
      });
      final cards = await ProgressService.instance.getFsrsCards();
      expect(cards, isEmpty);
    });

    test('should_default_malformed_box_to_zero', () async {
      SharedPreferences.setMockInitialValues({
        'srs': ['word|notanumber|2026-01-10T00:00:00.000'],
      });
      final cards = await ProgressService.instance.getFsrsCards();
      expect(cards['word']?.reviews, 0);
    });

    test('should_not_overwrite_existing_fsrs_data', () async {
      final existing = FsrsCard(
        key: 'kept',
        due: DateTime(2026, 12, 1),
        stability: 9,
        difficulty: 5,
        lastReview: DateTime(2026, 8, 1),
        reviews: 6,
        lapses: 0,
      );
      SharedPreferences.setMockInitialValues({
        'srs': ['legacy|3|2026-01-01T00:00:00.000'],
        'srs_fsrs': [jsonEncode(existing.toJson())],
      });

      final cards = await ProgressService.instance.getFsrsCards();
      expect(cards.keys, ['kept']);
    });
  });

  group('SRS scheduling', () {
    test('should_create_card_with_one_review_on_mark_srs_known', () async {
      await ProgressService.instance.markSrs('casa', known: true);
      final cards = await ProgressService.instance.getFsrsCards();
      expect(cards['casa'], isNotNull);
      expect(cards['casa']!.reviews, 1);
      expect(cards['casa']!.lapses, 0);
    });

    test('should_count_lapse_on_mark_srs_unknown', () async {
      await ProgressService.instance.markSrs('casa', known: false);
      final cards = await ProgressService.instance.getFsrsCards();
      expect(cards['casa']!.lapses, 1);
    });

    test('should_count_only_past_due_cards', () async {
      final past = FsrsCard(
        key: 'due_now',
        due: DateTime.now().subtract(const Duration(days: 1)),
        stability: 1,
        difficulty: 5,
        lastReview: DateTime.now().subtract(const Duration(days: 5)),
        reviews: 2,
        lapses: 0,
      );
      final future = FsrsCard(
        key: 'due_later',
        due: DateTime.now().add(const Duration(days: 30)),
        stability: 5,
        difficulty: 5,
        lastReview: DateTime.now(),
        reviews: 3,
        lapses: 0,
      );
      SharedPreferences.setMockInitialValues({
        'srs_fsrs': [jsonEncode(past.toJson()), jsonEncode(future.toJson())],
      });

      expect(await ProgressService.instance.getDueWordCount(), 1);
      final due = await ProgressService.instance.getDueFsrsCards();
      expect(due.keys, ['due_now']);
    });
  });

  group('notes', () {
    test('should_save_and_read_lesson_notes', () async {
      await ProgressService.instance.setLessonNotes('A1-01', 'revisar verbos');
      expect(
        await ProgressService.instance.getLessonNotes('A1-01'),
        'revisar verbos',
      );
      expect(await ProgressService.instance.getLessonNotes('A1-02'), '');
    });
  });

  group('reset', () {
    test('should_clear_all_stored_progress', () async {
      await ProgressService.instance.markCompleted('A1-01');
      await ProgressService.instance.toggleFavorite('casa');
      await ProgressService.instance.setQuizBest('A1', 5);
      await ProgressService.instance.setRepeatCount(3);

      await ProgressService.instance.resetAll();

      expect(await ProgressService.instance.getCompleted(), isEmpty);
      expect(await ProgressService.instance.getFavorites(), isEmpty);
      expect(await ProgressService.instance.getQuizBest('A1'), 0);
      expect(await ProgressService.instance.getStreak(), 0);
      expect(await ProgressService.instance.getRepeatCount(), 1);
    });
  });
}
