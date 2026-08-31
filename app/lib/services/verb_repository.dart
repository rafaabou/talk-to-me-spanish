import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/verb_models.dart';

class VerbRepository {
  static final VerbRepository instance = VerbRepository._();
  VerbRepository._();

  VerbData? _cache;

  Future<VerbData> loadVerbs() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/course/verbs.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final tenses =
        (json['tenses'] as Map<String, dynamic>).entries
            .map((e) => TenseInfo(e.key, TriTextLabel.fromJson(e.value)))
            .toList();
    final persons = (json['persons'] as List? ?? []).cast<String>();
    final conjGroups = <String, List<String>>{};
    if (json['conjGroups'] is Map) {
      (json['conjGroups'] as Map<String, dynamic>).forEach((k, v) {
        conjGroups[k] = (v as List? ?? []).cast<String>();
      });
    }
    final verbs =
        (json['verbs'] as List? ?? [])
            .map((e) => VerbInfo.fromJson(e as Map<String, dynamic>))
            .toList();
    _cache = VerbData(tenses, persons, conjGroups, verbs);
    return _cache!;
  }
}
