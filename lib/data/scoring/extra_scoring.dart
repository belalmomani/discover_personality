import '../models/extra_test.dart';
import 'scoring_engine.dart' show ScoringException;

class DimScore {
  const DimScore({required this.dim, required this.avg, required this.pct});
  final ExtraDimension dim;

  /// Mean of the dimension's (reverse-adjusted) answers, 1..5.
  final double avg;

  /// ((avg - 1) / 4) * 100 — descriptive, not a population percentile.
  final double pct;

  /// 'low' (< 35), 'high' (> 65), otherwise 'mid'.
  String get level => pct < 35 ? 'low' : (pct > 65 ? 'high' : 'mid');
}

class ExtraScore {
  const ExtraScore({required this.test, required this.dims, required this.topDims, this.headline});
  final ExtraTest test;
  final List<DimScore> dims;

  /// Dimensions within 5 points of the highest score (max 3). Empty for single-dimension tests.
  final List<DimScore> topDims;

  /// Special derived label (e.g. attachment style).
  final String? headline;

  String interpret(DimScore d) {
    switch (d.level) {
      case 'high':
        return 'درجة مرتفعة: ${d.dim.high}.';
      case 'low':
        return 'درجة منخفضة: ${d.dim.low}.';
      default:
        return 'درجة متوسطة: تتراوح بين «${d.dim.low}» و«${d.dim.high}» بحسب الموقف.';
    }
  }
}

/// Deterministic scoring shared by all additional tests.
class ExtraScoring {
  ExtraScoring._();

  static void validate(ExtraTest t, Map<int, int> answers) {
    final ids = t.items.map((i) => i.id).toSet();
    for (final k in answers.keys) {
      if (!ids.contains(k)) throw ScoringException('Unknown item $k in ${t.id}.');
    }
    for (final i in t.items) {
      final v = answers[i.id];
      if (v == null) throw ScoringException('Missing answer ${i.id} in ${t.id}.');
      if (v < 1 || v > 5) throw ScoringException('Answer ${i.id} out of range: $v.');
    }
  }

  static bool isComplete(ExtraTest t, Map<int, int> answers) {
    try {
      validate(t, answers);
      return true;
    } on ScoringException {
      return false;
    }
  }

  static ExtraScore compute(ExtraTest t, Map<int, int> answers) {
    validate(t, answers);
    final dims = <DimScore>[];
    for (final d in t.dimensions) {
      final vals = t.items.where((i) => i.dim == d.id).map((i) => i.reverse ? 6 - answers[i.id]! : answers[i.id]!).toList();
      if (vals.isEmpty) throw ScoringException('Dimension ${d.id} in ${t.id} has no items.');
      final avg = vals.reduce((a, b) => a + b) / vals.length;
      dims.add(DimScore(dim: d, avg: avg, pct: ((avg - 1) / 4) * 100));
    }
    var top = <DimScore>[];
    if (dims.length > 1) {
      final sorted = [...dims]; // List.sort is not guaranteed stable; sort with index tie-break.
      sorted.sort((a, b) {
        final c = b.pct.compareTo(a.pct);
        return c != 0 ? c : dims.indexOf(a).compareTo(dims.indexOf(b));
      });
      final best = sorted.first.pct;
      top = sorted.where((d) => d.pct >= best - 5).take(3).toList();
    }
    String? headline;
    if (t.id == 'attachment') {
      final anx = dims.firstWhere((d) => d.dim.id == 'X');
      final avo = dims.firstWhere((d) => d.dim.id == 'V');
      headline = attachmentStyle(anx.pct, avo.pct);
    }
    return ExtraScore(test: t, dims: dims, topDims: top, headline: headline);
  }

  /// Quadrant label from anxiety/avoidance (threshold 50 on the 0..100 scale).
  static String attachmentStyle(double anxietyPct, double avoidancePct) {
    final highAnx = anxietyPct > 50;
    final highAvo = avoidancePct > 50;
    if (!highAnx && !highAvo) return 'تعلّق آمن (قلق منخفض وتجنب منخفض)';
    if (highAnx && !highAvo) return 'تعلّق قلق (قلق مرتفع وتجنب منخفض)';
    if (!highAnx && highAvo) return 'تعلّق تجنبي (قلق منخفض وتجنب مرتفع)';
    return 'تعلّق قلق-تجنبي (قلق مرتفع وتجنب مرتفع)';
  }
}
