/// Generation classification + country context. All content is a broad generalisation:
/// individuals differ, and event summaries omit detail. Years follow the common
/// Pew-style boundaries (Gen Y/Millennials 1981-1996, Gen Z 1997-2012, Alpha 2013+).

class Generation {
  const Generation({
    required this.name,
    required this.start,
    required this.end,
    required this.formative,
    required this.tendencies,
    required this.concerns,
  });
  final String name;
  final int start;
  final int end;
  final String formative;
  final List<String> tendencies;
  final List<String> concerns;
}

const List<Generation> generations = [
  Generation(
    name: 'الجيل الصامت',
    start: 1928,
    end: 1945,
    formative: 'نشأ في ظل الكساد العظيم والحرب العالمية الثانية وما بعدها.',
    tendencies: ['يميل غالبًا إلى الانضباط والصبر والادخار', 'قليل الكلام كثير العمل في الصورة النمطية', 'يقدّر الاستقرار والالتزام'],
    concerns: ['الرعاية الصحية والتقاعد', 'الاعتماد على الأبناء والتقنية الجديدة', 'الحفاظ على الروابط الأسرية'],
  ),
  Generation(
    name: 'جيل الطفرة (Baby Boomers)',
    start: 1946,
    end: 1964,
    formative: 'ولد بعد الحرب العالمية الثانية في فترة نمو سكاني واقتصادي في عدة مناطق.',
    tendencies: ['يميل غالبًا إلى تقدير الوظيفة والمكانة والتسلسل الهرمي', 'يرتبط اسمه في كثير من الدول بشغل مواقع القيادة اليوم', 'يعتمد على الخبرة والعلاقات الشخصية'],
    concerns: ['التقاعد وتكاليف العلاج', 'دعم الأبناء والأحفاد', 'مواكبة التحول الرقمي'],
  ),
  Generation(
    name: 'جيل X',
    start: 1965,
    end: 1980,
    formative: 'عاصر أواخر الحرب الباردة وبدايات الحاسوب والتلفزيون الفضائي.',
    tendencies: ['يميل غالبًا إلى الاستقلالية والعملية', 'أقل ثقة بالمؤسسات في الصورة النمطية', 'يتحمل المسؤولية بهدوء'],
    concerns: ['ضغط رعاية الوالدين والأبناء معًا', 'الاستقرار الوظيفي قبل التقاعد', 'تكاليف التعليم والسكن'],
  ),
  Generation(
    name: 'جيل Y (الألفية — Millennials)',
    start: 1981,
    end: 1996,
    formative: 'نشأ مع انتشار الحاسوب ثم الإنترنت، وشهد التحول من العالم التناظري إلى الرقمي.',
    tendencies: ['يميل غالبًا إلى البحث عن المعنى في العمل إلى جانب الدخل', 'أكثر استعدادًا لتغيير الوظائف', 'اصطدم بواقع اقتصادي أصعب مما توقع في كثير من الدول'],
    concerns: ['تكاليف السكن والمعيشة', 'الأمان الوظيفي والمعنى في العمل', 'تربية الأطفال وتوازن الحياة', 'مواكبة الذكاء الاصطناعي والصحة النفسية'],
  ),
  Generation(
    name: 'جيل Z',
    start: 1997,
    end: 2012,
    formative: 'ولد مع الإنترنت والهاتف الذكي والمنصات الاجتماعية.',
    tendencies: ['يميل غالبًا إلى التواصل البصري السريع', 'وعي مرتفع بالقضايا الاجتماعية والسياسية', 'منفتح على الحديث عن الصحة النفسية'],
    concerns: ['أول وظيفة والبطالة', 'الصحة النفسية وضغط المنصات', 'تكاليف التعليم', 'مستقبل المهن مع الذكاء الاصطناعي'],
  ),
  Generation(
    name: 'جيل ألفا (Alpha)',
    start: 2013,
    end: 2100,
    formative: 'يولد في عالم الذكاء الاصطناعي والتعليم والترفيه الرقميين، ولم تتشكل ملامحه بعد.',
    tendencies: ['يتعامل مع الأجهزة منذ الطفولة', 'ما زالت سماته الجماعية قيد التشكل'],
    concerns: ['وقت الشاشة والتعليم الرقمي', 'التوازن بين الواقع والعالم الافتراضي'],
  ),
];

Generation? generationForYear(int year) {
  for (final g in generations) {
    if (year >= g.start && year <= g.end) return g;
  }
  return null;
}

class EraEvent {
  const EraEvent(this.year, this.text);
  final int year;
  final String text;
}

class Country {
  const Country(this.code, this.name, this.arab);
  final String code;
  final String name;
  final bool arab;
}

const List<Country> countries = [
  Country('JO', 'الأردن', true),
  Country('SA', 'السعودية', true),
  Country('EG', 'مصر', true),
  Country('PS', 'فلسطين', true),
  Country('IQ', 'العراق', true),
  Country('SY', 'سوريا', true),
  Country('LB', 'لبنان', true),
  Country('AE', 'الإمارات', true),
  Country('KW', 'الكويت', true),
  Country('QA', 'قطر', true),
  Country('BH', 'البحرين', true),
  Country('OM', 'عُمان', true),
  Country('YE', 'اليمن', true),
  Country('SD', 'السودان', true),
  Country('LY', 'ليبيا', true),
  Country('TN', 'تونس', true),
  Country('DZ', 'الجزائر', true),
  Country('MA', 'المغرب', true),
  Country('XX', 'دولة أخرى', false),
];

/// Events shared by the whole region (shown for Arab countries).
const List<EraEvent> arabCommonEvents = [
  EraEvent(1967, 'حرب يونيو وتغير الخريطة السياسية في المنطقة'),
  EraEvent(1973, 'حرب أكتوبر وحظر النفط وما تبعه من طفرة نفطية'),
  EraEvent(1990, 'غزو الكويت ثم حرب الخليج (1991) وتداعياتها الاقتصادية والسياسية'),
  EraEvent(2003, 'غزو العراق وتداعياته الإقليمية'),
  EraEvent(2011, 'احتجاجات «الربيع العربي» وتحولاتها'),
];

/// Global events relevant to everyone.
const List<EraEvent> globalEvents = [
  EraEvent(1989, 'سقوط جدار برلين وبداية نهاية الحرب الباردة'),
  EraEvent(1995, 'انتشار الإنترنت للجمهور'),
  EraEvent(2001, 'هجمات 11 سبتمبر وتغير الأجواء السياسية عالميًا'),
  EraEvent(2007, 'ظهور الهواتف الذكية'),
  EraEvent(2008, 'الأزمة المالية العالمية'),
  EraEvent(2020, 'جائحة كوفيد-19 والتحول للعمل والتعلم عن بُعد'),
  EraEvent(2022, 'انتشار الذكاء الاصطناعي التوليدي'),
];

const Map<String, List<EraEvent>> countryEvents = {
  'JO': [
    EraEvent(1970, 'أحداث أيلول 1970'),
    EraEvent(1988, 'قرار فك الارتباط مع الضفة الغربية'),
    EraEvent(1989, 'أزمة اقتصادية واحتجاجات وعودة الانتخابات النيابية'),
    EraEvent(1991, 'عودة مئات الآلاف من الأردنيين من الخليج بعد حرب الخليج'),
    EraEvent(1994, 'توقيع معاهدة وادي عربة'),
    EraEvent(1999, 'تولي الملك عبدالله الثاني الحكم'),
    EraEvent(2003, 'بدء تدفق اللاجئين العراقيين إلى الأردن'),
    EraEvent(2012, 'تدفق اللاجئين السوريين وضغطه على الخدمات'),
    EraEvent(2018, 'احتجاجات اقتصادية وتغيير الحكومة'),
  ],
  'SA': [
    EraEvent(1974, 'الطفرة النفطية والتحول العمراني السريع'),
    EraEvent(1979, 'حادثة الحرم المكي وبروز تيار «الصحوة»'),
    EraEvent(2003, 'موجة هجمات إرهابية داخلية'),
    EraEvent(2005, 'انطلاق برنامج خادم الحرمين للابتعاث الخارجي'),
    EraEvent(2016, 'إطلاق رؤية 2030'),
    EraEvent(2018, 'السماح بقيادة المرأة للسيارة وافتتاح دور السينما'),
  ],
  'EG': [
    EraEvent(1952, 'ثورة يوليو'),
    EraEvent(1974, 'سياسة الانفتاح الاقتصادي'),
    EraEvent(1979, 'معاهدة السلام مع إسرائيل'),
    EraEvent(1981, 'تولي حسني مبارك الحكم'),
    EraEvent(1992, 'مواجهات مع جماعات مسلحة خلال التسعينيات'),
    EraEvent(2011, 'ثورة 25 يناير'),
    EraEvent(2013, 'أحداث 30 يونيو وتغير السلطة'),
    EraEvent(2016, 'تحرير سعر صرف الجنيه وارتفاع الأسعار'),
  ],
  'PS': [
    EraEvent(1948, 'النكبة'),
    EraEvent(1967, 'الاحتلال الإسرائيلي للضفة الغربية وقطاع غزة'),
    EraEvent(1987, 'الانتفاضة الأولى'),
    EraEvent(1993, 'اتفاق أوسلو وقيام السلطة الفلسطينية'),
    EraEvent(2000, 'الانتفاضة الثانية'),
    EraEvent(2007, 'الانقسام الفلسطيني بين الضفة وغزة'),
    EraEvent(2023, 'الحرب على غزة وتداعياتها الإنسانية'),
  ],
  'IQ': [
    EraEvent(1968, 'وصول حزب البعث إلى الحكم'),
    EraEvent(1980, 'الحرب العراقية الإيرانية (1980–1988)'),
    EraEvent(1990, 'غزو الكويت ثم الحصار الاقتصادي حتى 2003'),
    EraEvent(2003, 'الغزو الأمريكي وسقوط النظام'),
    EraEvent(2006, 'موجة العنف الطائفي (2006–2008)'),
    EraEvent(2014, 'سيطرة تنظيم داعش على الموصل ومناطق أخرى'),
    EraEvent(2019, 'احتجاجات تشرين'),
  ],
  'SY': [
    EraEvent(1970, 'وصول حافظ الأسد إلى الحكم'),
    EraEvent(1982, 'أحداث حماة'),
    EraEvent(2000, 'تولي بشار الأسد الحكم'),
    EraEvent(2011, 'اندلاع الاحتجاجات ثم الحرب'),
    EraEvent(2015, 'موجات نزوح ولجوء واسعة داخل البلاد وخارجها'),
    EraEvent(2024, 'تغيّر السلطة في سوريا بنهاية العام'),
  ],
  'LB': [
    EraEvent(1975, 'اندلاع الحرب الأهلية (1975–1990)'),
    EraEvent(1990, 'نهاية الحرب الأهلية وبدء إعادة الإعمار'),
    EraEvent(2005, 'اغتيال رفيق الحريري وخروج القوات السورية'),
    EraEvent(2006, 'حرب تموز'),
    EraEvent(2019, 'الانهيار الاقتصادي وانهيار سعر الليرة والاحتجاجات'),
    EraEvent(2020, 'انفجار مرفأ بيروت'),
  ],
  'AE': [
    EraEvent(1971, 'قيام دولة الاتحاد'),
    EraEvent(1995, 'طفرة عمرانية واقتصادية وسياحية متسارعة في التسعينيات والألفية'),
    EraEvent(2008, 'تأثر دبي بالأزمة المالية العالمية'),
    EraEvent(2021, 'استضافة معرض إكسبو دبي (2021–2022)'),
  ],
  'KW': [
    EraEvent(1962, 'صدور الدستور'),
    EraEvent(1990, 'الغزو العراقي للكويت'),
    EraEvent(1991, 'تحرير الكويت'),
    EraEvent(2020, 'كورونا وانخفاض أسعار النفط'),
  ],
  'QA': [
    EraEvent(1995, 'تولي الشيخ حمد بن خليفة الحكم'),
    EraEvent(1996, 'انطلاق قناة الجزيرة'),
    EraEvent(2017, 'حصار قطر (2017–2021)'),
    EraEvent(2022, 'استضافة كأس العالم'),
  ],
  'BH': [
    EraEvent(1971, 'الاستقلال'),
    EraEvent(2011, 'أحداث فبراير'),
  ],
  'OM': [
    EraEvent(1970, 'تولي السلطان قابوس الحكم'),
    EraEvent(2011, 'احتجاجات مطالبة بالإصلاح والوظائف'),
    EraEvent(2020, 'تولي السلطان هيثم الحكم'),
  ],
  'YE': [
    EraEvent(1990, 'الوحدة اليمنية'),
    EraEvent(1994, 'حرب 1994'),
    EraEvent(2011, 'احتجاجات 2011'),
    EraEvent(2015, 'الحرب وتدهور الأوضاع الإنسانية'),
  ],
  'SD': [
    EraEvent(1989, 'انقلاب 1989'),
    EraEvent(2011, 'انفصال جنوب السودان'),
    EraEvent(2019, 'ثورة ديسمبر وسقوط النظام'),
    EraEvent(2023, 'اندلاع الحرب'),
  ],
  'LY': [
    EraEvent(1969, 'ثورة الفاتح من سبتمبر'),
    EraEvent(2011, 'الثورة وسقوط القذافي'),
    EraEvent(2014, 'الانقسام والصراع بين السلطات'),
  ],
  'TN': [
    EraEvent(1987, 'تولي زين العابدين بن علي الحكم'),
    EraEvent(2011, 'الثورة التونسية'),
    EraEvent(2014, 'إقرار دستور جديد'),
    EraEvent(2021, 'إجراءات 25 جويلية'),
  ],
  'DZ': [
    EraEvent(1962, 'الاستقلال'),
    EraEvent(1988, 'أحداث أكتوبر'),
    EraEvent(1991, 'العشرية السوداء (1991–2002)'),
    EraEvent(1999, 'وصول بوتفليقة إلى الحكم'),
    EraEvent(2019, 'الحراك الشعبي'),
  ],
  'MA': [
    EraEvent(1975, 'المسيرة الخضراء'),
    EraEvent(1999, 'تولي الملك محمد السادس الحكم'),
    EraEvent(2003, 'هجمات الدار البيضاء'),
    EraEvent(2011, 'حراك 20 فبراير ودستور جديد'),
    EraEvent(2023, 'زلزال الحوز'),
  ],
};

class EraSummary {
  const EraSummary({required this.formative, required this.later});

  /// Events during roughly ages 8–25 (when worldview forms).
  final List<EraEvent> formative;

  /// Events after age 25 up to [now].
  final List<EraEvent> later;
}

/// Picks events (country + region + world) for a person born in [birthYear].
EraSummary eraFor({required int birthYear, required String? countryCode, required int nowYear}) {
  final all = <EraEvent>[
    ...globalEvents,
    if (countries.any((c) => c.code == countryCode && c.arab)) ...arabCommonEvents,
    ...(countryEvents[countryCode] ?? const <EraEvent>[]),
  ]..sort((a, b) => a.year.compareTo(b.year));
  final formative = all.where((e) => e.year >= birthYear + 8 && e.year <= birthYear + 25).toList();
  final later = all.where((e) => e.year > birthYear + 25 && e.year <= nowYear).toList();
  return EraSummary(formative: formative, later: later);
}
