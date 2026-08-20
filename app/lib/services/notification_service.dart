import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'com.rafaabou.eszero_hero/notification',
  );
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _channel.invokeMethod('init');
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  Future<void> scheduleDailyReviewReminder({int hour = 19}) async {
    try {
      await _channel.invokeMethod('scheduleDailyReviewReminder', {
        'hour': hour,
      });
    } catch (e) {
      debugPrint('scheduleDailyReviewReminder failed: $e');
    }
  }

  Future<void> scheduleStreakNudge({int hour = 20}) async {
    try {
      await _channel.invokeMethod('scheduleStreakNudge', {'hour': hour});
    } catch (e) {
      debugPrint('scheduleStreakNudge failed: $e');
    }
  }

  Future<void> updateReviewNotification(int dueCount) async {
    try {
      await _channel.invokeMethod('updateReviewNotification', {
        'dueCount': dueCount,
      });
    } catch (e) {
      debugPrint('updateReviewNotification failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelAll');
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }
}
