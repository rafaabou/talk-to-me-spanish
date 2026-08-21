String uiText(
  String lang, {
  String? ar,
  String? pt,
  String? es,
  String? en,
  required String other,
}) {
  switch (lang) {
    case 'ar':
      return (ar != null && ar.isNotEmpty) ? ar : other;
    case 'pt':
      return (pt != null && pt.isNotEmpty) ? pt : other;
    case 'es':
      return (es != null && es.isNotEmpty) ? es : other;
    default:
      return (en != null && en.isNotEmpty) ? en : other;
  }
}
