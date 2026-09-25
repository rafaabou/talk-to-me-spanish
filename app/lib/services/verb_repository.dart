import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/verb_models.dart';

class VerbRepository {
  static final VerbRepository instance = VerbRepository._();
  VerbRepository._();

  Future<VerbData>? _inflight;

  /// Caches the in-flight future, not only the finished value: two callers that
  /// arrive while the 2.5 MB file is being parsed used to each start their own
  /// parse and their own build.
  Future<VerbData> loadVerbs() {
    return _inflight ??= _parse();
  }

  Future<VerbData> _parse() async {
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
    final data = VerbData(tenses, persons, conjGroups, verbs);
    // Keep the result cached for the rest of the session, and let a failed
    // parse be retried instead of caching the exception forever.
    _inflight = Future.value(data);
    return data;
  }
}
