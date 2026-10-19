import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/utils.dart';
import '../../data/ads/ad_service.dart';
import '../../data/ai/ai_explainer.dart';
import '../../data/report/report_builder.dart';
import '../../data/report/report_content.dart';
import '../assessment/intro_screen.dart';
import '../development_plan/plan_screen.dart';
import '../integrated/integrated_report_screen.dart';
import 'arfd_detail_screen.dart';
import 'enneagram_detail_screen.dart';
import 'mbti_detail_screen.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.resultId});
  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final matches = history.where((r) => r.id == resultId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('النتائج')),
        body: const EmptyView(icon: Icons.search_off, message: 'لم يتم العثور على هذا التقرير.'),
      );
    }
    final saved = matches.first;
    final r = saved.result;
    final report = ReportBuilder.build(r);

    // Captured now so the pop callback never touches `ref` after disposal.
    final ads = ref.read(adServiceProvider);
    final consent = ref.watch(settingsProvider).adsConsent;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Natural transition point; fire-and-forget, never blocks navigation.
          ads.maybeShowInterstitial(AdPlacement.resultsExitInterstitial, consent: consent);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text('تقرير ${arabicDate(saved.createdAt)}')),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                SectionCard(title: 'ملخص الشخصية المرشحة', icon: Icons.auto_awesome_outlined, child: Text(report.summary)),
                const DisclaimerBanner(),
                SectionCard(
                  title: 'التحليل المتكامل',
                  icon: Icons.hub_outlined,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('بدل قراءة ثلاثة رموز منفصلة: كيف تتكامل نتائجك، نقاط القوة ومصادر التعثر، القرار والضغط، وصورتك لدى الآخرين، ودرجة الثقة في كل نتيجة.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => pushScreen(context, IntegratedReportScreen(resultId: resultId)),
                      icon: const Icon(Icons.auto_graph),
                      label: const Text('افتح التحليل المتكامل'),
                    ),
                  ]),
                ),
                Card(
                  child: ExpansionTile(
                    shape: const Border(),
                    title: const Text('الرموز والدرجات التفصيلية (MBTI • Enneagram • A-R-F-D)'),
                    childrenPadding: const EdgeInsets.all(8),
                    children: [
                    SectionCard(
                      title: 'MBTI: ${r.mbtiType}',
                      icon: Icons.groups_2_outlined,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final p in r.mbti)
                          ScoreBar(
                            label: '${p.poleA} / ${p.poleB}',
                            fraction: p.pctA / (p.pctA + p.pctB == 0 ? 1 : p.pctA + p.pctB),
                            valueText: p.isClose ? 'متقارب' : p.preferred,
                            highlight: !p.isClose,
                          ),
                        if (r.mbtiAnyClose) const Padding(padding: EdgeInsets.only(top: 6), child: Text('بعض الأبعاد متقاربة؛ النتيجة غير حاسمة فيها.')),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(onPressed: () => pushScreen(context, MbtiDetailScreen(result: r)), child: const Text('التفاصيل')),
                        ),
                      ]),
                    ),
                    SectionCard(
                      title: r.enneagramConclusive ? 'Enneagram: النمط ${r.enneagramTop.type}' : 'Enneagram: أنماط متقاربة',
                      icon: Icons.hub_outlined,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(report.enneagramLines.first),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(onPressed: () => pushScreen(context, EnneagramDetailScreen(result: r)), child: const Text('التفاصيل')),
                        ),
                      ]),
                    ),
                    SectionCard(
                      title: 'الرمز السلوكي ${r.arfdCode}',
                      icon: Icons.tune,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final a in r.arfd)
                          ScoreBar(label: arfdAxes[a.axis]!.name, fraction: (a.avg - 1) / 4, valueText: a.avg.toStringAsFixed(2)),
                        const Text('نظام أصلي خاص بالتطبيق وليس مقياسًا نفسيًا معتمدًا.'),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(onPressed: () => pushScreen(context, ArfdDetailScreen(result: r)), child: const Text('التفاصيل')),
                        ),
                      ]),
                    ),
                    ],
                  ),
                ),
                if (report.strengths.isNotEmpty) SectionCard(title: 'نقاط قوة محتملة', icon: Icons.thumb_up_alt_outlined, child: BulletList(report.strengths)),
                if (report.challenges.isNotEmpty) SectionCard(title: 'تحديات قد تعيق التقدم', icon: Icons.flag_outlined, child: BulletList(report.challenges)),
                SectionCard(
                  title: 'تناقضات محتملة',
                  icon: Icons.compare_arrows,
                  child: report.contradictions.isEmpty
                      ? const Text('لم تُظهر الدرجات تناقضات واضحة تستحق الإشارة.')
                      : BulletList(report.contradictions),
                ),
                SectionCard(title: 'أسئلة للتأمل الذاتي', icon: Icons.edit_note, child: BulletList(report.reflectionQuestions)),
                _AiCard(resultId: resultId),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => pushScreen(context, PlanScreen(resultId: resultId)),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('خطة التطوير لمدة 30 يومًا'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => pushScreen(context, const IntroScreen()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة الاختبار ومقارنة النتائج لاحقًا'),
                ),
                const SizedBox(height: 16),
              ]),
            ),
            const AdBanner(placement: AdPlacement.resultsBanner),
          ]),
        ),
      ),
    );
  }
}

class _AiCard extends ConsumerStatefulWidget {
  const _AiCard({required this.resultId});
  final String resultId;
  @override
  ConsumerState<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends ConsumerState<_AiCard> {
  bool _loading = false;
  String? _text;
  String? _error;

  Future<void> _ask() async {
    final settings = ref.read(settingsProvider);
    if (!settings.aiConsent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('إرسال الدرجات لخدمة ذكاء اصطناعي؟'),
          content: const Text(
              'سيُرسل إلى الخادم الوسيط ملخص درجاتك فقط (النسب والدرجات والرمز)، دون إجاباتك الخام ودون أي بيانات شخصية. '
              'التفسير نص إضافي ولا يغيّر درجاتك. يمكنك سحب الموافقة من الإعدادات.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أوافق')),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(settingsProvider.notifier).setAiConsent(true);
    }
    final matches = ref.read(historyProvider).where((r) => r.id == widget.resultId);
    if (matches.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = await ref.read(aiExplainerProvider).explain(ReportBuilder.aiPayload(matches.first.result));
      if (mounted) setState(() => _text = text);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بالخدمة. التفسير المحلي أعلاه يبقى متاحًا.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(aiExplainerProvider).isAvailable;
    if (!available) return const SizedBox.shrink(); // feature is optional and off by default
    return SectionCard(
      title: 'تفسير إضافي بالذكاء الاصطناعي (اختياري)',
      icon: Icons.smart_toy_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_text != null) ...[
          Text(_text!),
          const SizedBox(height: 8),
          const Text('نص مولّد آليًا للتأمل فقط؛ لا يغيّر الدرجات المحسوبة ولا يُعد تشخيصًا.', style: TextStyle(fontSize: 12)),
        ] else if (_loading)
          const LinearProgressIndicator()
        else ...[
          if (_error != null) Text(_error!),
          OutlinedButton(onPressed: _ask, child: const Text('اطلب تفسيرًا إضافيًا')),
        ],
      ]),
    );
  }
}
