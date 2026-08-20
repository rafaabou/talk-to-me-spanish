import 'package:flutter/material.dart';
import '../models/course_models.dart';

class TrText extends StatelessWidget {
  final TriText text;
  final String lang;

  const TrText(this.text, this.lang, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.tr(lang));
  }
}
