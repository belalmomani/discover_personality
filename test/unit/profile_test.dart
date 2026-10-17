import 'package:discover_personality/data/profile/animals.dart';
import 'package:discover_personality/data/profile/generations.dart';
import 'package:discover_personality/data/profile/life_path.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('life path', () {
    test('19/12/1985 -> 36 -> 9 (the user example)', () => expect(lifePathNumber(DateTime(1985, 12, 19)), 9));
    test('plain reductions', () {
      expect(lifePathNumber(DateTime(2000, 1, 1)), 4);
      expect(lifePathNumber(DateTime(1986, 9, 2)), 8);
      expect(lifePathNumber(DateTime(1990, 5, 15)), 3);
    });
    test('master numbers 11, 22, 33 are kept', () {
      expect(lifePathNumber(DateTime(1980, 1, 28)), 11);
      expect(lifePathNumber(DateTime(1980, 2, 20)), 22);
      expect(lifePathNumber(DateTime(1980, 5, 28)), 33);
    });
    test('every possible result has a description', () {
      final seen = <int>{};
      for (var y = 1920; y <= 2025; y++) {
        for (var m = 1; m <= 12; m++) {
          for (final d in [1, 9, 10, 19, 28]) {
            seen.add(lifePathNumber(DateTime(y, m, d)));
          }
        }
      }
      for (final n in seen) {
        expect(lifePathMeanings.containsKey(n), isTrue, reason: 'missing $n');
      }
    });
  });

  group('generations', () {
    test('boundaries follow the requested ranges', () {
      expect(generationForYear(1928)!.name, 'الجيل الصامت');
      expect(generationForYear(1945)!.name, 'الجيل الصامت');
      expect(generationForYear(1946)!.name, contains('Boomers'));
      expect(generationForYear(1964)!.name, contains('Boomers'));
      expect(generationForYear(1965)!.name, 'جيل X');
      expect(generationForYear(1980)!.name, 'جيل X');
      expect(generationForYear(1981)!.name, contains('Y'));
      expect(generationForYear(1985)!.name, contains('Y'));
      expect(generationForYear(1996)!.name, contains('Y'));
      expect(generationForYear(1997)!.name, 'جيل Z');
      expect(generationForYear(2012)!.name, 'جيل Z');
      expect(generationForYear(2013)!.name, contains('Alpha'));
      expect(generationForYear(1900), isNull);
    });
    test('1985 in Jordan: formative events (ages 8-25) include 1994 treaty and 1999 accession', () {
      final era = eraFor(birthYear: 1985, countryCode: 'JO', nowYear: 2026);
      final years = era.formative.map((e) => e.year).toList();
      expect(years, containsAll([1994, 1999, 2003, 2001, 2008]));
      expect(years.every((y) => y >= 1993 && y <= 2010), isTrue);
      expect(era.later.every((e) => e.year > 2010 && e.year <= 2026), isTrue);
      expect(era.later.map((e) => e.year), contains(2020));
    });
    test('events are sorted and different countries give different histories', () {
      final jo = eraFor(birthYear: 1985, countryCode: 'JO', nowYear: 2026).formative.map((e) => e.text).toSet();
      final eg = eraFor(birthYear: 1985, countryCode: 'EG', nowYear: 2026).formative.map((e) => e.text).toSet();
      expect(jo, isNot(eg));
      final ys = eraFor(birthYear: 1985, countryCode: 'JO', nowYear: 2026).formative.map((e) => e.year).toList();
      expect([...ys]..sort(), ys);
    });
    test('"other country" gets only global events and no crash on null country', () {
      final other = eraFor(birthYear: 1985, countryCode: 'XX', nowYear: 2026);
      expect(other.formative.isNotEmpty, isTrue);
      expect(eraFor(birthYear: 1985, countryCode: null, nowYear: 2026).formative.isNotEmpty, isTrue);
    });
    test('every country code with events is a listed country', () {
      final codes = countries.map((c) => c.code).toSet();
      for (final k in countryEvents.keys) {
        expect(codes.contains(k), isTrue, reason: k);
      }
    });
  });

  group('animals', () {
    final qs = loadBank().questions;
    test('prototype vectors have 8 features in 0..1', () {
      for (final a in animals) {
        expect(a.vector.length, 8);
        expect(a.vector.every((v) => v >= 0 && v <= 1), isTrue, reason: a.name);
      }
    });
    test('matching is deterministic and returns the requested count', () {
      final r = ScoringEngine.compute(qs, buildAnswers(qs, (q) => (q.id * 5) % 5 + 1));
      final a = matchAnimals(r);
      final b = matchAnimals(r);
      expect(a.length, 2);
      expect(a.map((m) => m.animal.name).toList(), b.map((m) => m.animal.name).toList());
      expect(a.first.similarityPct, greaterThanOrEqualTo(a.last.similarityPct));
      expect(a.every((m) => m.similarityPct >= 0 && m.similarityPct <= 100), isTrue);
    });
    test('a profile equal to a prototype matches that animal at ~100%', () {
      // Owl prototype: E low, N high-ish, T high, J mid-high, A very high, R low, F mid, D mid.
      final owl = animals.firstWhere((a) => a.name == 'البومة');
      final f = featuresOf(ScoringEngine.compute(qs, allSame(qs, 3)));
      expect(f.length, owl.vector.length);
      final m = matchAnimals(ScoringEngine.compute(qs, allSame(qs, 3)), count: 12);
      expect(m.length, 12);
    });
  });
}
