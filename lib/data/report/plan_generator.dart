import '../../core/utils.dart';
import '../models/dev_plan.dart';
import '../scoring/scoring_result.dart';
import 'report_content.dart';

/// Deterministic local 30-day plan generator. Everything it creates is editable.
class PlanGenerator {
  PlanGenerator._();

  static const _week1 = [
    'اقرأ تقريرك كاملًا ودوّن ثلاث نقاط تشعر أنها تشبهك وواحدة لا تشبهك.',
    'اكتب موقفًا حديثًا ظهر فيه أحد تفضيلاتك بوضوح.',
    'اسأل شخصًا تثق به عن رأيه في نقاط القوة التي ظهرت لك.',
    'حدد عادة واحدة صغيرة تريد تحسينها خلال 30 يومًا.',
    'اكتب لماذا تهمك هذه العادة (سبب شخصي واحد).',
    'راقب نفسك اليوم وسجل متى ظهر التحدي الأبرز في نتائجك.',
    'راجع الأسبوع: ماذا لاحظت؟ دوّن الملخص في خانة المراجعة.',
  ];

  static const Map<String, List<String>> _axisTasks = {
    'A': [
      'قبل أي قرار اليوم، اكتب خيارين ومعيارًا واحدًا للمقارنة.',
      'حدد المعلومة الناقصة الوحيدة التي تحتاجها قبل البدء.',
      'ضع حدًا زمنيًا (15 دقيقة) للتحليل ثم اتخذ خطوة.',
      'اكتب قرارًا اتخذته مؤخرًا وما الذي ساعدك على حسمه.',
      'قارن بين خيارين صغيرين في حياتك اليوم بجدول بسيط.',
    ],
    'R': [
      'اختر فكرة وقرر أصغر تجربة آمنة لاختبارها.',
      'حدد أقصى خسارة مقبولة لتجربة محتملة واكتبها.',
      'نفذ تجربة صغيرة اليوم وسجل النتيجة.',
      'اكتب فرصة تجنبتها مؤخرًا وما أسوأ نتيجة واقعية لها.',
      'اطلب رأي شخص خبير قبل خطوة فيها مخاطرة محسوبة.',
    ],
    'F': [
      'حوّل هدفًا واحدًا إلى ثلاث مهام بمواعيد محددة.',
      'اعمل 25 دقيقة على مهمة مهمة دون مقاطعة.',
      'أكمل مهمة متأخرة واحدة اليوم.',
      'اكتب سبب انخفاض حماسك في مشروع وحدد خطوة صغيرة للاستمرار.',
      'حدد مشروعًا واحدًا فقط لإكماله قبل بدء أي مشروع جديد.',
    ],
    'D': [
      'اكتب ثلاث أولويات حقيقية لك بعيدًا عن توقعات الآخرين.',
      'اختر مهمة واحدة تمنحك استقلالية أكبر وابدأها.',
      'حوّل هدفًا إلى رقم قابل للقياس (كم؟ متى؟).',
      'اكتب قرارًا اتخذته لإرضاء الآخرين وما الذي كنت ستختاره لنفسك.',
      'راجع أهدافك: أيها يعبّر عنك فعلًا؟',
    ],
  };

  static const _generic = [
    'خصص 10 دقائق للتأمل وكتابة ما تعلمته اليوم.',
    'طبّق عادتك الصغيرة المختارة وسجل ذلك.',
    'اشكر شخصًا أو قدّم له دعمًا بسيطًا.',
    'نظّم مكان عملك أو دراستك لمدة 10 دقائق.',
  ];

  static const Map<String, List<String>> _mbtiBalance = {
    'E': ['مارس 15 دقيقة من الهدوء والتأمل الفردي دون شاشات.'],
    'I': ['شارك فكرة واحدة مع شخص أو مجموعة اليوم.'],
    'S': ['خصص 10 دقائق لتخيل احتمالات جديدة لمشكلة تواجهها.'],
    'N': ['اكتب قائمة بخطوات عملية ملموسة لفكرة تفكر فيها.'],
    'T': ['اسأل شخصًا عن شعوره تجاه قرار يخصه قبل رأيك المنطقي.'],
    'F': ['اتخذ قرارًا صغيرًا بمعيار موضوعي واضح واكتب المعيار.'],
    'J': ['اترك جزءًا من يومك بلا خطة وراقب شعورك.'],
    'P': ['ضع موعدًا نهائيًا لمهمة مفتوحة والتزم به.'],
  };

  static ArfdAxisResult weakestAxis(ScoringResult r) {
    var w = r.arfd.first;
    for (final a in r.arfd) {
      if (a.avg < w.avg) w = a; // strict '<' keeps the first axis on ties
    }
    return w;
  }

  static DevPlan generate(String resultId, ScoringResult r, {DateTime? now}) {
    final weak = weakestAxis(r);
    final axisInfo = arfdAxes[weak.axis]!;
    final top = r.enneagramTop.type;
    final typeInfo = enneagramTypes[top]!;
    final less = r.mbti.map((p) => p.preferred == p.poleA ? p.poleB : p.poleA).toList();

    final tasks = <String>[..._week1];
    final axisList = _axisTasks[weak.axis]!;
    tasks.addAll(axisList);
    tasks.addAll([_generic[0], _generic[1]]); // days 13-14
    tasks.addAll([
      typeInfo.practice,
      'تأمل: ${typeInfo.reflection}',
      typeInfo.practice,
      _generic[2],
      'اكتب كيف ظهر نمطك (${typeInfo.name}) في موقف اليوم.',
      _generic[1],
      'راجع الأسبوع الثالث: ما الذي نجح؟ دوّن في خانة المراجعة.',
    ]);
    tasks.addAll([
      _mbtiBalance[less[0]]!.first,
      _mbtiBalance[less[2]]!.first,
      _generic[3],
      _mbtiBalance[less[3]]!.first,
      _generic[1],
      _generic[0],
      'راجع الأسبوع الرابع وحدد ما ستواصله بعد الخطة.',
    ]);
    tasks.add('راجع تقدمك: ما الذي تغيّر؟ اكتب الملخص النهائي (اليوم 29).');
    tasks.add('اليوم الثلاثون: اكتب ملخصًا نهائيًا وقرر خطتك القادمة.');
    assert(tasks.length == 30);

    final days = <DayTask>[
      for (var i = 0; i < 30; i++) DayTask(day: i + 1, text: tasks[i]),
    ];

    final weeks = <WeekGoal>[
      WeekGoal(week: 1, title: 'الوعي', goal: 'فهم النتائج والتحقق من مدى انطباقها عليك.', metric: 'إكمال 6 من 7 مهام.'),
      WeekGoal(week: 2, title: axisInfo.name, goal: 'تحسين محور ${axisInfo.name} (الأقل درجة لديك حاليًا).', metric: 'إكمال 6 من 7 مهام وتطبيق تجربة واحدة على الأقل.'),
      WeekGoal(week: 3, title: 'ممارسة نمطية', goal: 'ممارسة تمرين نمو مرتبط بالنمط ${typeInfo.name}.', metric: 'إكمال 6 من 7 مهام وكتابة 3 تأملات.'),
      WeekGoal(week: 4, title: 'التوازن والتثبيت', goal: 'تجربة القطب الأقل تفضيلًا بخفة وتثبيت العادة المختارة.', metric: 'إكمال 6 من 7 مهام وتحديد ما ستواصله.'),
    ];

    final goals = <MeasurableGoal>[
      MeasurableGoal(title: 'إكمال مهام الخطة', unit: 'مهمة', target: 24),
      MeasurableGoal(title: 'تطبيق العادة المختارة', unit: 'يوم', target: 15),
      MeasurableGoal(title: 'كتابة تأملات أو مراجعات', unit: 'تأمل', target: 8),
    ];

    return DevPlan(
      id: newUuid(),
      resultId: resultId,
      createdAt: now ?? DateTime.now(),
      weeks: weeks,
      days: days,
      goals: goals,
    );
  }
}
