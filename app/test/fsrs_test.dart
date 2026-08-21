import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:talk_to_me_spanish/services/fsrs.dart';

void main() {
  final now = DateTime(2026, 8, 21, 12);
  final scheduler = FsrsScheduler();

  group('FsrsCard JSON round-trip', () {
    test('should_preserve_all_fields_when_serializing_and_deserializing', () {
      final card = FsrsCard(
        key: 'w1',
        due: now.add(const Duration(days: 3)),
        stability: 2.5,
        difficulty: 6.1,
        lastReview: now,
        reviews: 4,
        lapses: 1,
      );
      final restored = FsrsCard.fromJson(card.toJson());
      expect(restored.key, card.key);
      expect(restored.due, card.due);
      expect(restored.stability, card.stability);
      expect(restored.difficulty, card.difficulty);
      expect(restored.lastReview, card.lastReview);
      expect(restored.reviews, card.reviews);
      expect(restored.lapses, card.lapses);
    });
  });

  group('newCard', () {
    test('should_start_with_zero_progress', () {
      final card = scheduler.newCard('k', now);
      expect(card.reviews, 0);
      expect(card.lapses, 0);
      expect(card.stability, 0.0);
      expect(card.difficulty, 0.0);
      expect(card.due, now);
    });
  });

  group('firstReview', () {
    test('should_apply_lapse_constants_for_rating_1', () {
      final card = scheduler.firstReview('k', 1, now);
      expect(card.lapses, 1);
      expect(card.reviews, 1);
      expect(card.stability, FsrsScheduler.w0);
      expect(card.due.isAfter(now), isTrue);
    });

    test('should_apply_success_constants_for_rating_3', () {
      final card = scheduler.firstReview('k', 3, now);
      expect(card.lapses, 0);
      expect(card.stability, FsrsScheduler.w4);
      expect(card.difficulty, closeTo(FsrsScheduler.w1 + FsrsScheduler.w2 * 3, 1e-9));
      expect(card.due.isAfter(now), isTrue);
    });

    test('should_set_reviews_to_1_for_any_rating', () {
      for (final rating in [1, 2, 3, 4]) {
        expect(scheduler.firstReview('k', rating, now).reviews, 1);
      }
    });
  });

  group('reviewCard', () {
    test('should_increment_reviews_and_lower_difficulty_on_success', () {
      final card = scheduler.firstReview('k', 3, now);
      final reviewed = scheduler.reviewCard(card, 3, now.add(const Duration(days: 5)));
      expect(reviewed.reviews, card.reviews + 1);
      expect(reviewed.difficulty, lessThan(card.difficulty));
      expect(reviewed.difficulty, greaterThanOrEqualTo(1.0));
      expect(reviewed.lapses, card.lapses);
      expect(reviewed.lastReview, now.add(const Duration(days: 5)));
      expect(reviewed.due.isAfter(reviewed.lastReview), isTrue);
      expect(reviewed.stability, greaterThanOrEqualTo(card.stability));
    });

    test('should_never_go_below_difficulty_floor_of_1', () {
      var card = scheduler.firstReview('k', 4, now);
      for (var i = 0; i < 20; i++) {
        card = scheduler.reviewCard(card, 4, now.add(Duration(days: i + 1)));
      }
      expect(card.difficulty, greaterThanOrEqualTo(1.0));
    });

    test('should_count_lapse_and_raise_difficulty_on_rating_1', () {
      final card = scheduler.firstReview('k', 3, now);
      final lapsed = scheduler.reviewCard(card, 1, now.add(const Duration(days: 1)));
      expect(lapsed.lapses, card.lapses + 1);
      expect(lapsed.difficulty, greaterThan(card.difficulty));
      expect(lapsed.difficulty, lessThanOrEqualTo(10.0));
      expect(lapsed.due.isAfter(lapsed.lastReview), isTrue);
    });

    test('should_cap_difficulty_at_10_after_repeated_lapses', () {
      var card = scheduler.firstReview('k', 1, now);
      for (var i = 0; i < 30; i++) {
        card = scheduler.reviewCard(card, 1, now.add(Duration(days: i + 1)));
      }
      expect(card.difficulty, lessThanOrEqualTo(10.0));
    });

    test('should_cap_interval_at_maximum_365_days', () {
      final card = FsrsCard(
        key: 'k',
        due: now,
        stability: 100000,
        difficulty: 1.0,
        lastReview: now,
        reviews: 10,
        lapses: 0,
      );
      final reviewed = scheduler.reviewCard(card, 3, now);
      expect(reviewed.due.difference(now).inDays, 365);
    });
  });

  group('nextInterval', () {
    test('should_return_lapse_interval_for_rating_1', () {
      final card = scheduler.firstReview('k', 3, now);
      expect(
        scheduler.nextInterval(card, 1),
        closeTo(min(card.stability * FsrsScheduler.w11, 365.0), 1e-9),
      );
    });

    test('should_follow_success_formula_for_each_rating', () {
      final card = FsrsCard(
        key: 'k',
        due: now,
        stability: 5,
        difficulty: 6,
        lastReview: now,
        reviews: 3,
        lapses: 0,
      );
      expect(
        scheduler.nextInterval(card, 2),
        closeTo(
          min(card.stability * exp(FsrsScheduler.w9 * (1 - card.difficulty / 10)), 365.0),
          1e-9,
        ),
      );
      expect(
        scheduler.nextInterval(card, 3),
        closeTo(
          min(card.stability * exp(FsrsScheduler.w10 * (1 - card.difficulty / 10)), 365.0),
          1e-9,
        ),
      );
      expect(
        scheduler.nextInterval(card, 4),
        closeTo(
          min(card.stability * exp(FsrsScheduler.w8 * (1 - card.difficulty / 10)), 365.0),
          1e-9,
        ),
      );
    });

    test('should_order_success_intervals_hard_le_good_le_easy', () {
      final card = FsrsCard(
        key: 'k',
        due: now,
        stability: 5,
        difficulty: 6,
        lastReview: now,
        reviews: 3,
        lapses: 0,
      );
      final iHard = scheduler.nextInterval(card, 2);
      final iGood = scheduler.nextInterval(card, 3);
      final iEasy = scheduler.nextInterval(card, 4);
      expect(iHard, lessThanOrEqualTo(iGood));
      expect(iGood, lessThanOrEqualTo(iEasy));
    });
  });
}
