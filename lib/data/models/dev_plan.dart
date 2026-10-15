class DayTask {
  DayTask({required this.day, required this.text, this.done = false, this.note = ''});
  final int day;
  String text;
  bool done;
  String note;

  Map<String, dynamic> toJson() =>
      {'day': day, 'text': text, 'done': done, 'note': note};
  factory DayTask.fromJson(Map<String, dynamic> j) => DayTask(
        day: j['day'] as int,
        text: j['text'] as String,
        done: (j['done'] as bool?) ?? false,
        note: (j['note'] as String?) ?? '',
      );
}

class WeekGoal {
  WeekGoal({
    required this.week,
    required this.title,
    required this.goal,
    required this.metric,
    this.review = '',
  });
  final int week;
  String title;
  String goal;
  String metric;

  /// Weekly review written by the user.
  String review;

  Map<String, dynamic> toJson() => {
        'week': week,
        'title': title,
        'goal': goal,
        'metric': metric,
        'review': review,
      };
  factory WeekGoal.fromJson(Map<String, dynamic> j) => WeekGoal(
        week: j['week'] as int,
        title: j['title'] as String,
        goal: j['goal'] as String,
        metric: j['metric'] as String,
        review: (j['review'] as String?) ?? '',
      );
}

class MeasurableGoal {
  MeasurableGoal({
    required this.title,
    required this.unit,
    required this.target,
    this.current = 0,
  });
  String title;
  String unit;
  int target;

  /// Updated by the user.
  int current;

  Map<String, dynamic> toJson() =>
      {'title': title, 'unit': unit, 'target': target, 'current': current};
  factory MeasurableGoal.fromJson(Map<String, dynamic> j) => MeasurableGoal(
        title: j['title'] as String,
        unit: j['unit'] as String,
        target: j['target'] as int,
        current: (j['current'] as int?) ?? 0,
      );
}

class DevPlan {
  DevPlan({
    required this.id,
    required this.resultId,
    required this.createdAt,
    required this.weeks,
    required this.days,
    required this.goals,
    this.finalSummary = '',
  });

  final String id;
  final String resultId;
  final DateTime createdAt;
  final List<WeekGoal> weeks;
  final List<DayTask> days;
  final List<MeasurableGoal> goals;

  /// Day-30 summary written by the user.
  String finalSummary;

  int get doneCount => days.where((d) => d.done).length;
  double get completion => days.isEmpty ? 0 : doneCount / days.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'resultId': resultId,
        'createdAt': createdAt.toIso8601String(),
        'weeks': weeks.map((e) => e.toJson()).toList(),
        'days': days.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'finalSummary': finalSummary,
      };

  factory DevPlan.fromJson(Map<String, dynamic> j) => DevPlan(
        id: j['id'] as String,
        resultId: j['resultId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        weeks: (j['weeks'] as List)
            .map((e) => WeekGoal.fromJson(e as Map<String, dynamic>))
            .toList(),
        days: (j['days'] as List)
            .map((e) => DayTask.fromJson(e as Map<String, dynamic>))
            .toList(),
        goals: (j['goals'] as List)
            .map((e) => MeasurableGoal.fromJson(e as Map<String, dynamic>))
            .toList(),
        finalSummary: (j['finalSummary'] as String?) ?? '',
      );
}
