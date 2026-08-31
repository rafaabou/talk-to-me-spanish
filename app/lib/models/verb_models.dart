class VerbInfo {
  final String inf;
  final String en;
  final String ar;
  final String conjType;
  final bool hasFullAudio;
  final Map<String, List<String>> tenses;
  VerbInfo(
    this.inf,
    this.en,
    this.ar,
    this.conjType,
    this.hasFullAudio,
    this.tenses,
  );

  factory VerbInfo.fromJson(Map<String, dynamic> json) => VerbInfo(
    json['inf'] ?? '',
    json['en'] ?? '',
    json['ar'] ?? '',
    json['conjType'] ?? 'irregular',
    json['hasFullAudio'] == true,
    (json.keys.where(
      (k) =>
          k != 'inf' &&
          k != 'en' &&
          k != 'ar' &&
          k != 'conjType' &&
          k != 'hasFullAudio' &&
          k != 'persons',
    )).fold(<String, List<String>>{}, (m, k) {
      m[k] = (json[k] as List? ?? []).cast<String>();
      return m;
    }),
  );

  List<String> conjugation(String tense) => tenses[tense] ?? const [];
}

class TenseInfo {
  final String id;
  final TriTextLabel label;
  TenseInfo(this.id, this.label);
}

class TriTextLabel {
  final String es;
  final String en;
  final String ar;
  TriTextLabel(this.es, this.en, this.ar);

  factory TriTextLabel.fromJson(Map<String, dynamic> json) =>
      TriTextLabel(json['es'] ?? '', json['en'] ?? '', json['ar'] ?? '');
}

class VerbData {
  final List<TenseInfo> tenses;
  final List<String> persons;
  final Map<String, List<String>> conjGroups;
  final List<VerbInfo> verbs;
  VerbData(this.tenses, this.persons, this.conjGroups, this.verbs);
}
