import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/course_models.dart';

class CourseRepository {
  static final CourseRepository instance = CourseRepository._();
  CourseRepository._();

  Map<String, LevelInfo>? _levels;
  Map<String, Lesson>? _lessons;

  Future<Map<String, LevelInfo>> loadLevels() async {
    if (_levels != null) return _levels!;
    final raw = await rootBundle.loadString('assets/course/levels/index.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final levelsJson = json['levels'] as Map<String, dynamic>;
    final result = <String, LevelInfo>{};
    levelsJson.forEach((id, v) {
      result[id] = LevelInfo.fromJson(id, v as Map<String, dynamic>);
    });
    _levels = result;
    return result;
  }

  Future<Lesson> loadLesson(String id) async {
    if (_lessons != null && _lessons!.containsKey(id)) return _lessons![id]!;
    final raw = await rootBundle.loadString('assets/course/levels/$id.json');
    final lesson = Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _lessons ??= {};
    _lessons![id] = lesson;
    return lesson;
  }

  Future<Lesson?> tryLoadLesson(String id) async {
    try {
      return await loadLesson(id);
    } catch (e) {
      debugPrint('Failed to load lesson $id: $e');
      return null;
    }
  }
}
