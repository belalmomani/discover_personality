/// Ratings given by OTHER people about the user (to compare "public image" with self-report).
/// Stored on the device only. Items mirror the five Big-Five dimensions (2 items each, one reversed).

class ObserverItem {
  const ObserverItem(this.id, this.dim, this.text, {this.reverse = false});
  final int id;
  final String dim; // O C E A N
  final String text;
  final bool reverse;
}

const List<ObserverItem> observerItems = [
  ObserverItem(1, 'O', 'يستمتع بتجربة أفكار وأشياء جديدة.'),
  ObserverItem(2, 'O', 'يفضّل الطرق المعتادة دائمًا.', reverse: true),
  ObserverItem(3, 'C', 'يرتب أموره ويلتزم بما يبدأ به.'),
  ObserverItem(4, 'C', 'يؤجل مهامه حتى اللحظة الأخيرة.', reverse: true),
  ObserverItem(5, 'E', 'يبادر بالحديث ويرتاح في التجمعات.'),
  ObserverItem(6, 'E', 'يميل إلى البقاء في الخلفية اجتماعيًا.', reverse: true),
  ObserverItem(7, 'A', 'يتعاطف مع مشكلات الآخرين ويتعاون معهم.'),
  ObserverItem(8, 'A', 'يجادل بسهولة للدفاع عن موقفه.', reverse: true),
  ObserverItem(9, 'N', 'يتأثر بالضغط ويقلق بسرعة.'),
  ObserverItem(10, 'N', 'يبقى هادئًا تحت الضغط.', reverse: true),
];

const Map<String, String> observerDimNames = {
  'O': 'الانفتاح على الخبرة',
  'C': 'يقظة الضمير',
  'E': 'الانبساط',
  'A': 'الوِد والتعاون',
  'N': 'الحساسية الانفعالية',
};

const List<String> observerRelations = ['صديق', 'زميل عمل', 'قريب', 'شريك/ة', 'آخر'];

class ObserverRating {
  const ObserverRating({required this.id, required this.createdAt, required this.relation, required this.answers});
  final String id;
  final DateTime createdAt;
  final String relation;
  final Map<int, int> answers;

  static bool isComplete(Map<int, int> a) =>
      observerItems.every((i) => a[i.id] != null && a[i.id]! >= 1 && a[i.id]! <= 5) && a.length == observerItems.length;

  /// Percentage (0..100) for one dimension from this observer: ((mean - 1) / 4) * 100.
  double dimPct(String dim) {
    final vals = observerItems.where((i) => i.dim == dim).map((i) => i.reverse ? 6 - answers[i.id]! : answers[i.id]!).toList();
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    return ((mean - 1) / 4) * 100;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'relation': relation,
        'answers': answers.map((k, v) => MapEntry('$k', v)),
      };

  factory ObserverRating.fromJson(Map<String, dynamic> j) => ObserverRating(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        relation: (j['relation'] as String?) ?? 'آخر',
        answers: (j['answers'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as int)),
      );
}
