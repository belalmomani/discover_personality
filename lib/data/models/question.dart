enum AssessmentSystem { mbti, enneagram, arfd }

class Question {
  const Question({
    required this.id,
    required this.system,
    required this.dimension,
    required this.text,
    this.topic = '',
    this.reverse = false,
  });

  final int id;
  final AssessmentSystem system;

  /// MBTI: E I S N T F J P. Enneagram: '1'..'9'. A-R-F-D: A R F D.
  final String dimension;
  final String topic;
  final bool reverse;
  final String text;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as int,
        system: AssessmentSystem.values.firstWhere((s) => s.name == j['system']),
        dimension: j['dimension'] as String,
        topic: (j['topic'] as String?) ?? '',
        reverse: (j['reverse'] as bool?) ?? false,
        text: j['text'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'system': system.name,
        'dimension': dimension,
        'topic': topic,
        'reverse': reverse,
        'text': text,
      };
}

class ScaleOption {
  const ScaleOption(this.value, this.label);
  final int value;
  final String label;
}

class QuestionBank {
  const QuestionBank({required this.questions, required this.scale});
  final List<Question> questions;
  final List<ScaleOption> scale;
}
