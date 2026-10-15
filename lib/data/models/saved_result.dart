import '../scoring/scoring_result.dart';

/// A completed assessment stored on the device (and optionally synced).
class SavedResult {
  const SavedResult({
    required this.id,
    required this.createdAt,
    required this.answers,
    required this.result,
    this.synced = false,
  });

  final String id;
  final DateTime createdAt;
  final Map<int, int> answers;
  final ScoringResult result;
  final bool synced;

  SavedResult copyWith({bool? synced}) => SavedResult(
        id: id,
        createdAt: createdAt,
        answers: answers,
        result: result,
        synced: synced ?? this.synced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'answers': answers.map((k, v) => MapEntry('$k', v)),
        'result': result.toJson(),
        'synced': synced,
      };

  factory SavedResult.fromJson(Map<String, dynamic> j) => SavedResult(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        answers: (j['answers'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
        result: ScoringResult.fromJson(j['result'] as Map<String, dynamic>),
        synced: (j['synced'] as bool?) ?? false,
      );
}

/// In-progress (unfinished) assessment, restored after app restarts.
class AssessmentProgress {
  const AssessmentProgress({
    required this.sessionId,
    required this.startedAt,
    required this.answers,
    required this.index,
  });

  final String sessionId;
  final DateTime startedAt;
  final Map<int, int> answers;
  final int index;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'startedAt': startedAt.toIso8601String(),
        'answers': answers.map((k, v) => MapEntry('$k', v)),
        'index': index,
      };

  factory AssessmentProgress.fromJson(Map<String, dynamic> j) =>
      AssessmentProgress(
        sessionId: j['sessionId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        answers: (j['answers'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
        index: j['index'] as int,
      );
}
