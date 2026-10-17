class ExtraResult {
  const ExtraResult({required this.testId, required this.createdAt, required this.answers});
  final String testId;
  final DateTime createdAt;
  final Map<int, int> answers;

  Map<String, dynamic> toJson() => {
        'testId': testId,
        'createdAt': createdAt.toIso8601String(),
        'answers': answers.map((k, v) => MapEntry('$k', v)),
      };

  factory ExtraResult.fromJson(Map<String, dynamic> j) => ExtraResult(
        testId: j['testId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        answers: (j['answers'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as int)),
      );
}

class UserProfile {
  const UserProfile({this.birthDate, this.countryCode});
  final DateTime? birthDate;
  final String? countryCode;

  UserProfile copyWith({DateTime? birthDate, String? countryCode}) =>
      UserProfile(birthDate: birthDate ?? this.birthDate, countryCode: countryCode ?? this.countryCode);

  Map<String, dynamic> toJson() => {
        'birthDate': birthDate == null
            ? null
            : '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
        'countryCode': countryCode,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        birthDate: j['birthDate'] == null ? null : DateTime.parse(j['birthDate'] as String),
        countryCode: j['countryCode'] as String?,
      );
}
