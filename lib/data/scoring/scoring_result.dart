// Immutable, JSON-serialisable results produced by [ScoringEngine].

class MbtiPairResult {
  const MbtiPairResult({
    required this.poleA,
    required this.poleB,
    required this.avgA,
    required this.avgB,
    required this.pctA,
    required this.pctB,
    required this.isClose,
    required this.isTie,
  });

  final String poleA;
  final String poleB;
  final double avgA;
  final double avgB;
  final double pctA;
  final double pctB;
  final bool isClose;
  final bool isTie;

  /// Higher pole; on an exact tie the first pole (E, S, T, J) is used and [isTie] is true.
  String get preferred => pctA >= pctB ? poleA : poleB;
  double get preferredPct => pctA >= pctB ? pctA : pctB;
  double get diff => (pctA - pctB).abs();

  double pctOf(String pole) => pole == poleA ? pctA : pctB;

  Map<String, dynamic> toJson() => {
        'poleA': poleA,
        'poleB': poleB,
        'avgA': avgA,
        'avgB': avgB,
        'pctA': pctA,
        'pctB': pctB,
        'isClose': isClose,
        'isTie': isTie,
      };

  factory MbtiPairResult.fromJson(Map<String, dynamic> j) => MbtiPairResult(
        poleA: j['poleA'] as String,
        poleB: j['poleB'] as String,
        avgA: (j['avgA'] as num).toDouble(),
        avgB: (j['avgB'] as num).toDouble(),
        pctA: (j['pctA'] as num).toDouble(),
        pctB: (j['pctB'] as num).toDouble(),
        isClose: j['isClose'] as bool,
        isTie: j['isTie'] as bool,
      );
}

class EnneagramScore {
  const EnneagramScore(this.type, this.score);
  final int type;

  /// Sum of four answers: 4..20.
  final int score;

  Map<String, dynamic> toJson() => {'type': type, 'score': score};
  factory EnneagramScore.fromJson(Map<String, dynamic> j) =>
      EnneagramScore(j['type'] as int, j['score'] as int);
}

class ArfdAxisResult {
  const ArfdAxisResult({
    required this.axis,
    required this.avg,
    required this.rounded,
  });

  final String axis;

  /// Mean of three (reverse-adjusted) answers, 1..5.
  final double avg;

  /// Standard rounding (half away from zero) used in the code, 1..5.
  final int rounded;

  Map<String, dynamic> toJson() =>
      {'axis': axis, 'avg': avg, 'rounded': rounded};
  factory ArfdAxisResult.fromJson(Map<String, dynamic> j) => ArfdAxisResult(
        axis: j['axis'] as String,
        avg: (j['avg'] as num).toDouble(),
        rounded: j['rounded'] as int,
      );
}

class ScoringResult {
  const ScoringResult({
    required this.mbti,
    required this.enneagramRanking,
    required this.enneagramCandidates,
    required this.enneagramConclusive,
    required this.arfd,
    required this.scoringVersion,
  });

  /// Order: E/I, S/N, T/F, J/P.
  final List<MbtiPairResult> mbti;

  /// All nine types, sorted by score desc then type asc.
  final List<EnneagramScore> enneagramRanking;

  /// Types within the closeness threshold of the top score (max 3, top first).
  final List<EnneagramScore> enneagramCandidates;
  final bool enneagramConclusive;

  /// Order: A, R, F, D.
  final List<ArfdAxisResult> arfd;
  final int scoringVersion;

  String get mbtiType => mbti.map((p) => p.preferred).join();
  bool get mbtiAnyClose => mbti.any((p) => p.isClose);
  EnneagramScore get enneagramTop => enneagramRanking.first;
  String get arfdCode => arfd.map((a) => '${a.axis}${a.rounded}').join('-');

  ArfdAxisResult axis(String a) => arfd.firstWhere((x) => x.axis == a);

  Map<String, dynamic> toJson() => {
        'mbti': mbti.map((e) => e.toJson()).toList(),
        'enneagramRanking': enneagramRanking.map((e) => e.toJson()).toList(),
        'enneagramCandidates':
            enneagramCandidates.map((e) => e.toJson()).toList(),
        'enneagramConclusive': enneagramConclusive,
        'arfd': arfd.map((e) => e.toJson()).toList(),
        'scoringVersion': scoringVersion,
      };

  factory ScoringResult.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List).map((e) => f(e as Map<String, dynamic>)).toList();
    return ScoringResult(
      mbti: list('mbti', MbtiPairResult.fromJson),
      enneagramRanking: list('enneagramRanking', EnneagramScore.fromJson),
      enneagramCandidates:
          list('enneagramCandidates', EnneagramScore.fromJson),
      enneagramConclusive: j['enneagramConclusive'] as bool,
      arfd: list('arfd', ArfdAxisResult.fromJson),
      scoringVersion: j['scoringVersion'] as int,
    );
  }
}
