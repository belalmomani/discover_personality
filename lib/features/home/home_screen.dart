import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/utils.dart';
import '../../data/ads/ad_service.dart';
import '../../l10n/strings_ar.dart';
import '../assessment/intro_screen.dart';
import '../assessment/question_screen.dart';
import '../development_plan/plan_screen.dart';
import '../help/help_screen.dart';
import '../history/history_screen.dart';
import '../results/results_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final assessment = ref.watch(assessmentProvider);
    final notifier = ref.read(assessmentProvider.notifier);
    final total = ref.watch(questionBankProvider).questions.length;
    final inProgress = assessment.answers.isNotEmpty;
    final latest = history.isEmpty ? null : history.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
        actions: [
          IconButton(
            tooltip: 'المساعدة',
            icon: const Icon(Icons.help_outline),
            onPressed: () => pushScreen(context, const HelpScreen()),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => pushScreen(context, const SettingsScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              SectionCard(
                title: inProgress ? 'لديك اختبار غير مكتمل' : 'ابدأ رحلتك',
                icon: Icons.play_circle_outline,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (inProgress) ...[
                    Text('أجبت عن ${assessment.answers.length} من $total سؤالًا.'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: assessment.answers.length / total),
                  ] else
                    const Text('اختبار من 72 سؤالًا، يستغرق نحو 10–15 دقيقة. لا يتطلب حسابًا ولا اتصالًا بالإنترنت.'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => inProgress
                            ? pushScreen(context, const QuestionScreen())
                            : pushScreen(context, const IntroScreen()),
                        child: Text(inProgress ? S.cont : S.start),
                      ),
                    ),
                    if (inProgress) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('بدء اختبار جديد؟'),
                              content: const Text('ستُحذف الإجابات الحالية غير المكتملة.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
                                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text(S.confirm)),
                              ],
                            ),
                          );
                          if (ok == true) await notifier.restart();
                        },
                        child: const Text('من جديد'),
                      ),
                    ],
                  ]),
                ]),
              ),
              if (latest != null)
                SectionCard(
                  title: 'آخر تقرير • ${arabicDate(latest.createdAt)}',
                  icon: Icons.assessment_outlined,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MBTI: ${latest.result.mbtiType}${latest.result.mbtiAnyClose ? " (أبعاد متقاربة)" : ""}'),
                    Text('A-R-F-D: ${latest.result.arfdCode}'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      FilledButton.tonal(
                        onPressed: () => pushScreen(context, ResultsScreen(resultId: latest.id)),
                        child: const Text('عرض التقرير'),
                      ),
                      OutlinedButton(
                        onPressed: () => pushScreen(context, PlanScreen(resultId: latest.id)),
                        child: const Text('خطة 30 يومًا'),
                      ),
                    ]),
                  ]),
                )
              else
                const SectionCard(
                  title: 'التقارير السابقة',
                  icon: Icons.assessment_outlined,
                  child: Text('لا توجد تقارير بعد. ستظهر نتائجك هنا بعد إكمال الاختبار.'),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timeline),
                  title: const Text('سجل التقدم والمقارنة'),
                  subtitle: Text(history.isEmpty ? 'لا توجد نتائج محفوظة' : '${history.length} نتيجة محفوظة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => pushScreen(context, const HistoryScreen()),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('طريقة الاختبار والخصوصية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => pushScreen(context, const IntroScreen(showStartButton: false)),
                ),
              ),
              const SizedBox(height: 8),
              const DisclaimerBanner(),
            ]),
          ),
          const AdBanner(placement: AdPlacement.homeBanner),
        ]),
      ),
    );
  }
}
