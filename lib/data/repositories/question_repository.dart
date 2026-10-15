import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

class QuestionRepository {
  static const String assetPath = 'assets/data/questions_ar.json';

  static QuestionBank parse(String jsonText) {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    final qs = (map['questions'] as List)
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
    final scale = (map['scale'] as List)
        .map((e) => ScaleOption(e['value'] as int, e['label'] as String))
        .toList();
    return QuestionBank(questions: qs, scale: scale);
  }

  static Future<QuestionBank> loadFromAsset() async =>
      parse(await rootBundle.loadString(assetPath));
}
