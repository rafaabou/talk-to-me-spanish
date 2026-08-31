import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'com.rafaabou.eszero_hero/widget',
  );

  static Future<void> updateWidget({
    required int dueCount,
    required int streak,
    required int lessonsCompleted,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'dueCount': dueCount,
        'streak': streak,
        'lessonsCompleted': lessonsCompleted,
      });
    } catch (e) {
      debugPrint('Home widget update failed: $e');
    }
  }
}
