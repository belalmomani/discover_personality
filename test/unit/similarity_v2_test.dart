import 'dart:io';

import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:discover_personality/data/social/share_vectors.dart';
import 'package:discover_personality/data/social/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final qs = loadBank().questions;
  final tests = loadExtraTests();
  final sql = File('supabase/migrations/20260103000000_similarity_v2.sql').readAsStringSync();
  // Catalog rows live in two migrations: v2 (original tests) and catalog_v2 (10 added later).
  final catalogSql = sql + File('supabase/migrations/20260106000000_catalog_v2.sql').readAsStringSync();

  Map<String, ({int dims, int items})> sqlCatalog() => {
        for (final m in RegExp(r"\('((?:main|x)_\w+)', (\d+), (\d+)\)").allMatches(catalogSql))
          m.group(1)!: (dims: int.parse(m.group(2)!), items: int.parse(m.group(3)!)),
      };

  test('server catalog (weights = number of questions) matches the app tests exactly', () {
    final app = expectedCatalog(tests);
    final server = sqlCatalog();
    expect(server.keys.toSet(), app.keys.toSet());
    for (final k in app.keys) {
      expect(server[k]!.dims, app[k]!.dims, reason: '$k dims');
      expect(server[k]!.items, app[k]!.items, reason: '$k items');
    }
  });

  test('main test weights are 24 + 36 + 12 and sensitive tests are not shareable', () {
    final c = expectedCatalog(tests);
    expect(c['main_mbti']!.items, 24);
    expect(c['main_enneagram']!.items, 36);
    expect(c['main_arfd']!.items, 12);
    expect(c.containsKey('x_darktriad'), isFalse);
    expect(c.containsKey('x_attachment'), isFalse);
    expect(c.length, 29);
    expect(c.values.map((e) => e.items).reduce((a, b) => a + b), 363);
  });

  test('main vectors have the catalog sizes and stay inside 0..1', () {
    final r = ScoringEngine.compute(qs, buildAnswers(qs, (q) => (q.id * 3) % 5 + 1));
    final v = mainVectors(r);
    expect(v.map((e) => e.testId).toList(), ['main_mbti', 'main_enneagram', 'main_arfd']);
    expect(v[0].dims.length, 4);
    expect(v[1].dims.length, 9);
    expect(v[2].dims.length, 4);
    for (final x in v) {
      expect(x.dims.every((d) => d >= 0 && d <= 1), isTrue, reason: x.testId);
    }
  });

  test('buildShareVectors includes completed non-sensitive tests and never the sensitive ones', () {
    final r = ScoringEngine.compute(qs, allSame(qs, 3));
    Map<int, int> all3(String id) => {for (final i in tests.firstWhere((t) => t.id == id).items) i.id: 3};
    final vectors = buildShareVectors(
      main: r,
      tests: tests,
      extraAnswers: {'bigfive': all3('bigfive'), 'darktriad': all3('darktriad'), 'attachment': all3('attachment'), 'eq': {1: 3}},
    );
    final ids = vectors.map((v) => v.testId).toSet();
    expect(ids, {'main_mbti', 'main_enneagram', 'main_arfd', 'x_bigfive'});
    final cat = expectedCatalog(tests);
    for (final v in vectors) {
      expect(v.dims.length, cat[v.testId]!.dims, reason: v.testId);
    }
  });

  test('weighted similarity: a test counts in proportion to its number of questions', () {
    const catalog = {'small': (dims: 1, items: 6), 'big': (dims: 1, items: 24)};
    final a = {'small': [0.0], 'big': [1.0]};
    final b = {'small': [1.0], 'big': [1.0]};
    final r = weightedSimilarity(a, b, catalog)!;
    expect(r.similarity, 80); // (6*0 + 24*100) / 30
    expect(r.testsUsed, 2);
    expect(r.questionsUsed, 30);
  });

  test('weighted similarity ignores tests only one side took and is symmetric', () {
    const catalog = {'t1': (dims: 2, items: 10), 't2': (dims: 2, items: 10), 't3': (dims: 2, items: 20)};
    final a = {'t1': [0.2, 0.8], 't2': [0.5, 0.5], 't3': [0.1, 0.9]};
    final b = {'t1': [0.3, 0.7], 't2': [0.9, 0.1]};
    final ab = weightedSimilarity(a, b, catalog)!;
    final ba = weightedSimilarity(b, a, catalog)!;
    expect(ab.testsUsed, 2);
    expect(ab.questionsUsed, 20);
    expect(ab.similarity, ba.similarity);
  });

  test('identical people are 100% and opposite people are 0%', () {
    const catalog = {'t': (dims: 4, items: 12)};
    expect(weightedSimilarity({'t': [0.2, 0.4, 0.6, 0.8]}, {'t': [0.2, 0.4, 0.6, 0.8]}, catalog)!.similarity, 100);
    expect(weightedSimilarity({'t': [0.0, 0.0, 0.0, 0.0]}, {'t': [1.0, 1.0, 1.0, 1.0]}, catalog)!.similarity, 0);
    expect(weightedSimilarity({'t': [0.5]}, {'u': [0.5]}, catalog), isNull);
  });

  test('migration: new tables are RLS-protected, pair_similarity is internal-only, chat guard exists', () {
    for (final t in ['assessment_catalog', 'shared_scores']) {
      expect(sql, contains('alter table public.$t enable row level security'));
    }
    expect(sql, contains('revoke insert, update, delete on public.shared_scores from authenticated, anon'));
    expect(sql, contains('revoke all on function public.pair_similarity(uuid, uuid) from public, anon, authenticated'));
    expect(sql, contains("raise exception 'chat_disabled'"));
    expect(sql, contains('create trigger trg_messages_chat_guard before insert on public.messages'));
    expect(sql, contains('p.visible'));
    expect(sql, contains('allow_chat'));
  });

  test('migration: every function is SECURITY DEFINER with a fixed search_path', () {
    final fns = RegExp(r'create or replace function public\.(\w+)\(([\s\S]*?)\n\$\$;').allMatches(sql).toList();
    expect(fns.length, greaterThanOrEqualTo(7));
    for (final m in fns) {
      final body = m.group(0)!;
      expect(body.contains('security definer'), isTrue, reason: m.group(1));
      expect(body.contains('set search_path = public'), isTrue, reason: m.group(1));
    }
  });

  test('similarity pipeline is server-validated: unknown tests, wrong sizes and out-of-range values are rejected', () {
    expect(sql, contains("raise exception 'unknown_test'"));
    expect(sql, contains("raise exception 'invalid_scores'"));
    expect(sql, contains('array_length(arr, 1) <> cat.dims'));
    expect(sql, contains('v < 0 or v > 1'));
  });

  test('model parsing of the new fields', () {
    final u = SimilarUser.fromJson({'user_id': 'u', 'username': 'a', 'avatar_emoji': '🐬', 'similarity': 77, 'tests_used': 7, 'questions_used': 150, 'can_chat': false});
    expect(u.testsUsed, 7);
    expect(u.questionsUsed, 150);
    expect(u.canChat, isFalse);
    final p = SocialProfile.fromJson({'username': 'a', 'share_results': true, 'age_confirmed': true, 'visible': false, 'allow_chat': false});
    expect(p.visible, isFalse);
    expect(p.allowChat, isFalse);
    expect(SocialProfile.fromJson({'username': 'a'}).visible, isTrue);
    expect(socialErrorMessage(Exception('chat_disabled')), contains('مغلقة'));
  });
}
