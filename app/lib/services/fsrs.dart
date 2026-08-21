import 'dart:math';

class FsrsCard {
  final String key;
  final DateTime due;
  final double stability;
  final double difficulty;
  final DateTime lastReview;
  final int reviews;
  final int lapses;

  FsrsCard({
    required this.key,
    required this.due,
    required this.stability,
    required this.difficulty,
    required this.lastReview,
    required this.reviews,
    required this.lapses,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'due': due.toIso8601String(),
    'stability': stability,
    'difficulty': difficulty,
    'lastReview': lastReview.toIso8601String(),
    'reviews': reviews,
    'lapses': lapses,
  };

  factory FsrsCard.fromJson(Map<String, dynamic> json) => FsrsCard(
    key: json['key'] as String,
    due: DateTime.parse(json['due'] as String),
    stability: (json['stability'] as num).toDouble(),
    difficulty: (json['difficulty'] as num).toDouble(),
    lastReview: DateTime.parse(json['lastReview'] as String),
    reviews: json['reviews'] as int,
    lapses: json['lapses'] as int,
  );
}

class FsrsScheduler {
  static const double requestRetention = 0.9;
  static const double maximumInterval = 365.0;
  static const double w0 = 0.4;
  static const double w1 = 0.6;
  static const double w2 = 2.4;
  static const double w3 = 5.8;
  static const double w4 = 4.93;
  static const double w5 = 0.94;
  static const double w6 = 0.86;
  static const double w7 = 0.01;
  static const double w8 = 1.49;
  static const double w9 = 0.14;
  static const double w10 = 0.94;
  static const double w11 = 2.18;
  static const double w12 = 0.05;
  static const double w13 = 0.34;
  static const double w14 = 1.26;
  static const double w15 = 0.29;
  static const double w16 = 2.61;

  double nextInterval(FsrsCard card, int rating) {
    if (rating == 1) {
      return _lapseInterval(card);
    }
    return _successInterval(card, rating);
  }

  double _successInterval(FsrsCard card, int rating) {
    final s = card.stability;
    final d = card.difficulty;
    final r = rating == 2 ? w8 : (rating == 3 ? w9 : w10);
    return min(s * exp(r * (1 - d)), maximumInterval);
  }

  double _lapseInterval(FsrsCard card) {
    return min(card.stability * w11, maximumInterval);
  }

  FsrsCard reviewCard(FsrsCard card, int rating, DateTime now) {
    double newStability;
    double newDifficulty;
    int newLapses = card.lapses;

    if (rating == 1) {
      newStability = _newStabilityAfterLapse(card);
      newDifficulty = min(card.difficulty + w7, 10.0);
      newLapses = card.lapses + 1;
    } else {
      newStability = _newStabilityAfterSuccess(card, rating);
      newDifficulty = max(card.difficulty - w6 * (rating - 2), 1.0);
    }

    final interval =
        rating == 1 ? _lapseInterval(card) : _successInterval(card, rating);
    final due = now.add(Duration(days: interval.ceil()));

    return FsrsCard(
      key: card.key,
      due: due,
      stability: newStability,
      difficulty: newDifficulty,
      lastReview: now,
      reviews: card.reviews + 1,
      lapses: newLapses,
    );
  }

  double _newStabilityAfterSuccess(FsrsCard card, int rating) {
    final s = card.stability;
    final d = card.difficulty;
    final r = rating == 2 ? w8 : (rating == 3 ? w9 : w10);
    return s *
        (1 + exp(r * (1 - d)) - 1) *
        pow(rating == 2 ? w12 : (rating == 3 ? w13 : w14), 1);
  }

  double _newStabilityAfterLapse(FsrsCard card) {
    final s = card.stability;
    final d = card.difficulty;
    return max(w11 * pow(d, -w12) * pow(s + 1, w13) * exp(w14 * (1 - d)), 0.01);
  }

  FsrsCard newCard(String key, DateTime now) {
    return FsrsCard(
      key: key,
      due: now,
      stability: 0.0,
      difficulty: 0.0,
      lastReview: now,
      reviews: 0,
      lapses: 0,
    );
  }

  FsrsCard firstReview(String key, int rating, DateTime now) {
    double stability;
    double difficulty;

    switch (rating) {
      case 1:
        stability = w0;
        difficulty = w1 + w2 * 1;
        break;
      case 2:
        stability = w3;
        difficulty = w1 + w2 * 2;
        break;
      case 3:
        stability = w4;
        difficulty = w1 + w2 * 3;
        break;
      case 4:
        stability = w5;
        difficulty = w1 + w2 * 4;
        break;
      default:
        stability = w3;
        difficulty = w1 + w2 * 2;
    }

    final interval =
        rating == 1
            ? _lapseInterval(
              FsrsCard(
                key: key,
                due: now,
                stability: stability,
                difficulty: difficulty,
                lastReview: now,
                reviews: 0,
                lapses: 0,
              ),
            )
            : _successInterval(
              FsrsCard(
                key: key,
                due: now,
                stability: stability,
                difficulty: difficulty,
                lastReview: now,
                reviews: 0,
                lapses: 0,
              ),
              rating,
            );
    final due = now.add(Duration(days: interval.ceil()));

    return FsrsCard(
      key: key,
      due: due,
      stability: stability,
      difficulty: difficulty,
      lastReview: now,
      reviews: 1,
      lapses: rating == 1 ? 1 : 0,
    );
  }
}
