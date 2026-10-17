import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/utils.dart';
import '../../data/models/saved_result.dart';
import '../../data/profile/animals.dart';
import '../../data/profile/generations.dart';
import '../../data/profile/life_path.dart';
import '../assessment/intro_screen.dart';
import 'extra_result_screen.dart';
import 'extra_test_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    final history = ref.watch(historyProvider);
    final extraResults = ref.watch(extraResultsProvider);
    final tests = ref.watch(extraTestsProvider);
    final latest = history.isEmpty ? null : history.first;
    final birth = profile.birthDate;

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'بياناتي',
            icon: Icons.badge_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تُحفظ على جهازك فقط ولا تُرسل لأي خدمة.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.cake_outlined),
                label: Text(birth == null ? 'اختر تاريخ الميلاد' : 'تاريخ الميلاد: ${birth.day}/${birth.month}/${birth.year}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: birth ?? DateTime(now.year - 30, 1, 1),
                    firstDate: DateTime(1920),
                    lastDate: now,
                  );
                  if (d != null) await notifier.setBirthDate(d);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: profile.countryCode,
                decoration: const InputDecoration(labelText: 'الدولة التي نشأت فيها', border: OutlineInputBorder()),
                items: [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name))],
                onChanged: (v) {
                  if (v != null) notifier.setCountry(v);
                },
              ),
            ]),
          ),
          if (birth == null)
            const SectionCard(
              title: 'مسار الحياة والجيل',
              icon: Icons.timeline,
              child: Text('أدخل تاريخ ميلادك لعرض مسار حياتك وجيلك وما شكّل جيلك.'),
            )
          else ...[
            _LifePathCard(birth: birth),
            _GenerationCard(birthYear: birth.year, countryCode: profile.countryCode),
          ],
          _AnimalCard(hasResult: latest != null, resultOf: latest),
          SectionCard(
            title: 'الاختبار الرئيسي (MBTI + Enneagram + A-R-F-D)',
            icon: Icons.psychology_alt_outlined,
            child: latest == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('لم تُكمل الاختبار الرئيسي بعد. MBTI وEnneagram جزء منه.'),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: () => pushScreen(context, const IntroScreen()), child: const Text('ابدأ الاختبار')),
                  ])
                : Text('MBTI: ${latest.result.mbtiType}${latest.result.mbtiAnyClose ? " (أبعاد متقاربة)" : ""} • Enneagram: ${latest.result.enneagramConclusive ? "النمط ${latest.result.enneagramTop.type}" : "أنماط متقاربة"} • ${latest.result.arfdCode}'),
          ),
          SectionCard(
            title: 'اختبارات شخصية إضافية',
            icon: Icons.library_books_outlined,
            child: tests.isEmpty
                ? const Text('تعذر تحميل الاختبارات الإضافية.')
                : Column(children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('كلها استبيانات تقدير ذاتي أصلية مستوحاة من النماذج المعروفة، وليست نسخًا رسمية.', style: TextStyle(fontSize: 12)),
                    ),
                    for (final t in tests)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.title),
                        subtitle: Text(extraResults[t.id] == null
                            ? '${t.items.length} سؤالًا • ${t.subtitle}'
                            : 'مكتمل • ${arabicDate(extraResults[t.id]!.createdAt)} • اضغط لعرض النتيجة'),
                        leading: Icon(extraResults[t.id] == null ? Icons.radio_button_unchecked : Icons.check_circle, color: extraResults[t.id] == null ? null : Colors.green),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => extraResults[t.id] == null ? pushScreen(context, ExtraTestScreen(test: t)) : pushScreen(context, ExtraResultScreen(test: t)),
                      ),
                  ]),
          ),
          const DisclaimerBanner(),
        ]),
      ),
    );
  }
}

class _LifePathCard extends StatelessWidget {
  const _LifePathCard({required this.birth});
  final DateTime birth;
  @override
  Widget build(BuildContext context) {
    final n = lifePathNumber(birth);
    final info = lifePathMeanings[n]!;
    return SectionCard(
      title: '1️⃣ رقم مسار الحياة: $n',
      icon: Icons.numbers,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(info.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(info.text),
        const SizedBox(height: 6),
        Text(lifePathDisclaimer, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _GenerationCard extends StatelessWidget {
  const _GenerationCard({required this.birthYear, required this.countryCode});
  final int birthYear;
  final String? countryCode;
  @override
  Widget build(BuildContext context) {
    final g = generationForYear(birthYear);
    if (g == null) {
      return const SectionCard(title: 'الجيل', icon: Icons.groups_outlined, child: Text('وُلدت قبل 1928، وهو خارج التصنيفات الشائعة المعروضة هنا.'));
    }
    final country = countries.where((c) => c.code == countryCode);
    final era = eraFor(birthYear: birthYear, countryCode: countryCode, nowYear: DateTime.now().year);
    return Column(children: [
      SectionCard(
        title: '2️⃣ جيلك: ${g.name} (${g.start}–${g.end > 2090 ? "الآن" : g.end})',
        icon: Icons.groups_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.formative),
          const SizedBox(height: 8),
          const Text('ميول عامة:'),
          BulletList(g.tendencies),
          const SizedBox(height: 4),
          const Text('اهتمامات ومشكلات شائعة لهذا الجيل اليوم:'),
          BulletList(g.concerns),
          const SizedBox(height: 4),
          Text('هذه تعميمات إحصائية وصورة نمطية، والأفراد يختلفون كثيرًا داخل كل جيل.', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      SectionCard(
        title: country.isEmpty ? 'ما شكّل جيلك (عالميًا)' : 'ما شكّل جيلك في ${country.first.name}',
        icon: Icons.history_edu_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (countryCode == null) const Text('اختر الدولة لعرض أحداث بلدك أيضًا.'),
          if (era.formative.isEmpty)
            const Text('لا أحداث مسجلة ضمن سنوات التشكّل (8–25 سنة).')
          else ...[
            const Text('خلال سنوات التشكّل (من عمر 8 إلى 25):'),
            BulletList([for (final e in era.formative) '${e.year}: ${e.text}']),
          ],
          if (era.later.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('بعد ذلك:'),
            BulletList([for (final e in era.later) '${e.year}: ${e.text}']),
          ],
          const SizedBox(height: 6),
          Text('ملخصات عامة قد تُغفل تفاصيل وسياقات، وهي للتأمل لا للتأريخ الدقيق.', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ]);
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.hasResult, required this.resultOf});
  final bool hasResult;
  final SavedResult? resultOf;
  @override
  Widget build(BuildContext context) {
    if (!hasResult) {
      return const SectionCard(
        title: 'الحيوان أو الطائر الأقرب لصفاتك',
        icon: Icons.pets_outlined,
        child: Text('أكمل الاختبار الرئيسي ليُحسب أقرب حيوان لصفاتك.'),
      );
    }
    final matches = matchAnimals(resultOf!.result);
    return SectionCard(
      title: 'الحيوان أو الطائر الأقرب لصفاتك',
      icon: Icons.pets_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < matches.length; i++) ...[
          Text('${matches[i].animal.emoji} ${i == 0 ? "الأقرب" : "ثانيًا"}: ${matches[i].animal.name} (تشابه ${matches[i].similarityPct}٪)', style: Theme.of(context).textTheme.titleSmall),
          Text(matches[i].animal.description),
          if (matches[i].reasons.isNotEmpty) Text('لماذا؟ ${matches[i].reasons.join("، ")}.'),
          const SizedBox(height: 8),
        ],
        Text('تشبيه ترفيهي مبني على درجاتك في MBTI وA-R-F-D بقواعد ثابتة؛ ليس تحليلًا علميًا.', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
