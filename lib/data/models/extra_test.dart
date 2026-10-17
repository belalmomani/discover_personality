import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class ExtraDimension {
  const ExtraDimension({required this.id, required this.name, required this.high, required this.low});
  final String id;
  final String name;
  final String high;
  final String low;
}

class ExtraItem {
  const ExtraItem({required this.id, required this.dim, required this.text, required this.reverse});
  final int id;
  final String dim;
  final String text;
  final bool reverse;
}

class ExtraTest {
  const ExtraTest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.sensitive,
    required this.dimensions,
    required this.items,
  });
  final String id;
  final String title;
  final String subtitle;
  final String note;

  /// Sensitive tests (e.g. dark traits, attachment) are never synced to the cloud.
  final bool sensitive;
  final List<ExtraDimension> dimensions;
  final List<ExtraItem> items;

  factory ExtraTest.fromJson(Map<String, dynamic> j) => ExtraTest(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        note: j['note'] as String,
        sensitive: (j['sensitive'] as bool?) ?? false,
        dimensions: [
          for (final d in j['dimensions'] as List)
            ExtraDimension(
              id: d['id'] as String,
              name: d['name'] as String,
              high: d['high'] as String,
              low: d['low'] as String,
            ),
        ],
        items: [
          for (final i in j['items'] as List)
            ExtraItem(
              id: i['id'] as int,
              dim: i['dim'] as String,
              text: i['text'] as String,
              reverse: (i['reverse'] as bool?) ?? false,
            ),
        ],
      );
}

class ExtraTestRepository {
  static const String assetPath = 'assets/data/extra_tests.json';

  static List<ExtraTest> parse(String jsonText) {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;
    return [for (final t in map['tests'] as List) ExtraTest.fromJson(t as Map<String, dynamic>)];
  }

  static Future<List<ExtraTest>> loadFromAsset() async => parse(await rootBundle.loadString(assetPath));
}
