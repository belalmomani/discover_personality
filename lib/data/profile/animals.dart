import '../scoring/scoring_result.dart';

/// Playful, rule-based "closest animal" match from the main assessment (no randomness, no AI).
class AnimalProfile {
  const AnimalProfile(this.emoji, this.name, this.description, this.vector);
  final String emoji;
  final String name;
  final String description;

  /// Prototype on 0..1 for [animalFeatures] (E, N, T, J, A, R, F, D).
  final List<double> vector;
}

const List<String> animalFeatures = ['E', 'N', 'T', 'J', 'A', 'R', 'F', 'D'];

const Map<String, List<String>> _featurePhrases = {
  'E': ['اجتماعي ومنطلق', 'هادئ ويميل للخصوصية'],
  'N': ['ترى الصورة الكبيرة والاحتمالات', 'واقعي وعملي'],
  'T': ['منطقي في قراراتك', 'تراعي القيم والمشاعر في قراراتك'],
  'J': ['منظّم وحاسم', 'مرن ومنفتح على التغيير'],
  'A': ['تحليلي', 'سريع القرار بتحليل أقل'],
  'R': ['جريء في المخاطرة المحسوبة', 'حذر في المخاطرة'],
  'F': ['مثابر ومنفّذ', 'يتأثر استمرارك بالحماس'],
  'D': ['مدفوع بالاستقلال والإنجاز', 'دوافعك هادئة نسبيًا'],
};

const List<AnimalProfile> animals = [
  AnimalProfile('🦅', 'النسر', 'رؤية بعيدة واستقلال وجرأة محسوبة.', [0.4, 0.85, 0.7, 0.6, 0.7, 0.7, 0.6, 0.85]),
  AnimalProfile('🦉', 'البومة', 'هدوء وتحليل عميق وتأنٍّ قبل الحركة.', [0.2, 0.7, 0.8, 0.6, 0.9, 0.3, 0.5, 0.5]),
  AnimalProfile('🐬', 'الدلفين', 'اجتماعي ودافئ ومرن ويحب التعاون.', [0.85, 0.6, 0.3, 0.3, 0.4, 0.6, 0.4, 0.5]),
  AnimalProfile('🦁', 'الأسد', 'قيادة وحسم وحضور قوي.', [0.8, 0.5, 0.7, 0.8, 0.5, 0.7, 0.7, 0.8]),
  AnimalProfile('🐺', 'الذئب', 'ولاء للفريق وانضباط وتنفيذ مشترك.', [0.55, 0.4, 0.55, 0.8, 0.6, 0.5, 0.85, 0.6]),
  AnimalProfile('🐘', 'الفيل', 'رعاية وثبات وذاكرة وصبر.', [0.35, 0.4, 0.3, 0.7, 0.6, 0.2, 0.8, 0.4]),
  AnimalProfile('🦊', 'الثعلب', 'ذكاء مرن وقدرة على اقتناص الفرص.', [0.55, 0.7, 0.65, 0.3, 0.7, 0.8, 0.4, 0.6]),
  AnimalProfile('🐎', 'الحصان', 'طاقة وحرية واندفاع نحو الهدف.', [0.7, 0.4, 0.4, 0.4, 0.3, 0.6, 0.7, 0.7]),
  AnimalProfile('🐈', 'القطة', 'استقلال وفضول وانتقائية في العلاقات.', [0.25, 0.6, 0.5, 0.3, 0.6, 0.5, 0.4, 0.6]),
  AnimalProfile('🐜', 'النملة', 'اجتهاد ونظام واستمرارية.', [0.4, 0.2, 0.5, 0.9, 0.5, 0.2, 0.95, 0.5]),
  AnimalProfile('🦜', 'الببغاء', 'تعبير وحيوية وحب للتواصل.', [0.9, 0.5, 0.35, 0.3, 0.3, 0.5, 0.35, 0.4]),
  AnimalProfile('🐢', 'السلحفاة', 'صبر وحذر وتقدّم ثابت.', [0.2, 0.3, 0.5, 0.7, 0.8, 0.1, 0.8, 0.3]),
];

List<double> featuresOf(ScoringResult r) => [
      r.mbti[0].pctA / 100, // E
      r.mbti[1].pctB / 100, // N
      r.mbti[2].pctA / 100, // T
      r.mbti[3].pctA / 100, // J
      (r.axis('A').avg - 1) / 4,
      (r.axis('R').avg - 1) / 4,
      (r.axis('F').avg - 1) / 4,
      (r.axis('D').avg - 1) / 4,
    ];

class AnimalMatch {
  const AnimalMatch(this.animal, this.similarityPct, this.reasons);
  final AnimalProfile animal;
  final int similarityPct;
  final List<String> reasons;
}

double _dist(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    s += d * d;
  }
  return s;
}

/// Returns the [count] closest animals (ties resolved by list order).
List<AnimalMatch> matchAnimals(ScoringResult r, {int count = 2}) {
  final f = featuresOf(r);
  final scored = <MapEntry<int, double>>[
    for (var i = 0; i < animals.length; i++) MapEntry(i, _dist(f, animals[i].vector)),
  ]..sort((a, b) {
      final c = a.value.compareTo(b.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  const maxDist = 2.8284271247461903; // sqrt(8)
  final out = <AnimalMatch>[];
  for (final e in scored.take(count)) {
    final a = animals[e.key];
    final reasons = <String>[];
    for (var i = 0; i < animalFeatures.length && reasons.length < 3; i++) {
      final proto = a.vector[i];
      final close = (f[i] - proto).abs() <= 0.2;
      if (close && proto >= 0.7) reasons.add(_featurePhrases[animalFeatures[i]]![0]);
      if (close && proto <= 0.3) reasons.add(_featurePhrases[animalFeatures[i]]![1]);
    }
    final sim = (100 * (1 - (e.value > 0 ? (e.value < 8 ? _sqrt(e.value) : maxDist) : 0) / maxDist)).round();
    out.add(AnimalMatch(a, sim, reasons));
  }
  return out;
}

double _sqrt(double x) {
  // Newton iteration keeps this file free of dart:math imports (deterministic, 20 steps).
  if (x <= 0) return 0;
  var g = x > 1 ? x / 2 : 1.0;
  for (var i = 0; i < 20; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}
