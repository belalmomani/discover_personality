import 'package:discover_personality/data/models/extra_test.dart';
import 'package:discover_personality/data/scoring/extra_scoring.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart' show ScoringException;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final tests = loadExtraTests();
  ExtraTest byId(String id) => tests.firstWhere((t) => t.id == id);
  Map<int, int> all(ExtraTest t, int v) => {for (final i in t.items) i.id: v};

  test('the 28 additional tests all exist', () {
    expect(tests.map((t) => t.id).toSet(), {
      'bigfive', 'hexaco', 'disc', 'strengths', 'workstyle', 'darktriad', 'attachment', 'eq', 'resilience',
      'locus', 'cognitive', 'values', 'moral', 'risk', 'decision', 'nfc', 'via', 'psycap',
      'riasec', 'grit', 'lifesat', 'selfesteem', 'optimism', 'emoreg', 'empathy', 'hsp', 'procrast', 'growth'
    });
  });

  test('data integrity: unique ids, dimension references, enough items per dimension', () {
    for (final t in tests) {
      expect(t.items.map((i) => i.id).toSet().length, t.items.length, reason: '${t.id} duplicate item ids');
      expect(t.dimensions.map((d) => d.id).toSet().length, t.dimensions.length, reason: '${t.id} duplicate dims');
      final dimIds = t.dimensions.map((d) => d.id).toSet();
      for (final i in t.items) {
        expect(dimIds.contains(i.dim), isTrue, reason: '${t.id}/${i.id}');
        expect(i.text.trim(), isNotEmpty);
      }
      for (final d in t.dimensions) {
        expect(t.items.where((i) => i.dim == d.id).length, greaterThanOrEqualTo(3), reason: '${t.id}/${d.id}');
        expect(d.name.trim(), isNotEmpty);
      }
    }
  });

  test('item counts of the key models', () {
    expect(byId('bigfive').items.length, 20);
    expect(byId('bigfive').dimensions.length, 5);
    expect(byId('hexaco').dimensions.length, 6);
    expect(byId('disc').dimensions.length, 4);
    expect(byId('attachment').dimensions.length, 2);
  });

  test('sensitive tests are flagged', () {
    expect(byId('darktriad').sensitive, isTrue);
    expect(byId('attachment').sensitive, isTrue);
    expect(byId('bigfive').sensitive, isFalse);
  });

  test('scoring formula: all 5s on forward items => 100%, reverse items flip', () {
    final t = byId('bigfive');
    final r = ExtraScoring.compute(t, {for (final i in t.items) i.id: i.reverse ? 1 : 5});
    expect(r.dims.every((d) => d.pct == 100 && d.level == 'high'), isTrue);
    final low = ExtraScoring.compute(t, {for (final i in t.items) i.id: i.reverse ? 5 : 1});
    expect(low.dims.every((d) => d.pct == 0 && d.level == 'low'), isTrue);
  });

  test('all 3s => 50% / mid everywhere (reverse items neutral)', () {
    for (final t in tests) {
      final r = ExtraScoring.compute(t, all(t, 3));
      expect(r.dims.every((d) => d.pct == 50 && d.level == 'mid'), isTrue, reason: t.id);
    }
  });

  test('top dimensions: ties keep order, capped at 3, none for single-dimension tests', () {
    final disc = byId('disc');
    final neutral = ExtraScoring.compute(disc, all(disc, 3));
    expect(neutral.topDims.length, 3);
    expect(neutral.topDims.map((d) => d.dim.id).toList(), ['D', 'I', 'S']);
    final nfc = byId('nfc');
    expect(ExtraScoring.compute(nfc, all(nfc, 4)).topDims, isEmpty);
    final dTop = ExtraScoring.compute(disc, {for (final i in disc.items) i.id: i.dim == 'C' ? (i.reverse ? 1 : 5) : (i.reverse ? 5 : 1)});
    expect(dTop.topDims.first.dim.id, 'C');
    expect(dTop.topDims.length, 1);
  });

  test('attachment style quadrants', () {
    expect(ExtraScoring.attachmentStyle(20, 20), contains('آمن'));
    expect(ExtraScoring.attachmentStyle(80, 20), contains('قلق (قلق مرتفع'));
    expect(ExtraScoring.attachmentStyle(20, 80), contains('تجنبي (قلق منخفض'));
    expect(ExtraScoring.attachmentStyle(80, 80), contains('قلق-تجنبي'));
    final t = byId('attachment');
    final r = ExtraScoring.compute(t, {for (final i in t.items) i.id: i.dim == 'X' ? (i.reverse ? 1 : 5) : (i.reverse ? 5 : 1)});
    expect(r.headline, contains('قلق (قلق مرتفع'));
  });

  group('validation', () {
    test('missing, out-of-range and unknown answers are rejected', () {
      final t = byId('eq');
      expect(() => ExtraScoring.compute(t, {}), throwsA(isA<ScoringException>()));
      expect(() => ExtraScoring.compute(t, all(t, 3)..[1] = 0), throwsA(isA<ScoringException>()));
      expect(() => ExtraScoring.compute(t, all(t, 3)..[1] = 6), throwsA(isA<ScoringException>()));
      expect(() => ExtraScoring.compute(t, all(t, 3)..[999] = 3), throwsA(isA<ScoringException>()));
      expect(ExtraScoring.isComplete(t, all(t, 3)), isTrue);
      expect(ExtraScoring.isComplete(t, {1: 3}), isFalse);
    });
  });

  test('deterministic: same input gives same output', () {
    final t = byId('hexaco');
    final a = {for (final i in t.items) i.id: (i.id * 3) % 5 + 1};
    final r1 = ExtraScoring.compute(t, a).dims.map((d) => d.pct).toList();
    final r2 = ExtraScoring.compute(t, Map<int, int>.from(a)).dims.map((d) => d.pct).toList();
    expect(r1, r2);
  });
}
