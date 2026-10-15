import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/strings_ar.dart';
import '../privacy/privacy_screen.dart';
import 'question_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, this.showStartButton = true});
  final bool showStartButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طريقة الاختبار والخصوصية')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SectionCard(
            title: 'كيف يعمل الاختبار؟',
            icon: Icons.fact_check_outlined,
            child: BulletList([
              '72 سؤالًا ثابتًا: 24 لـ MBTI، و36 لـ Enneagram، و12 لرمز A-R-F-D.',
              'أجب بحسب مدى انطباق العبارة عليك من 1 (لا ينطبق إطلاقًا) إلى 5 (ينطبق تمامًا).',
              'لا توجد إجابة صحيحة أو خاطئة؛ أجب بصدق عمّا تفعله عادةً لا عمّا تتمنى.',
              'يُحفظ تقدمك تلقائيًا ويمكنك المتابعة لاحقًا.',
              'لن تظهر النتيجة إلا بعد الإجابة عن جميع الأسئلة، ويمكنك مراجعة إجاباتك قبل الإنهاء.',
              'الحساب يتم داخل جهازك بقواعد ثابتة، دون ذكاء اصطناعي.',
            ]),
          ),
          const SectionCard(
            title: 'الخصوصية',
            icon: Icons.lock_outline,
            child: BulletList([
              'يعمل الاختبار دون حساب ودون إنترنت، وتبقى إجاباتك على جهازك.',
              'لا يجمع التطبيق الموقع ولا جهات الاتصال ولا الرسائل.',
              'المزامنة السحابية اختيارية وتتم فقط إن سجّلت الدخول.',
              'يمكنك حذف بياناتك في أي وقت من الإعدادات.',
            ]),
          ),
          const DisclaimerBanner(),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => pushScreen(context, const PrivacyScreen()),
            child: const Text('قراءة سياسة الخصوصية كاملة'),
          ),
          if (showStartButton)
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacement(MaterialPageRoute<void>(builder: (_) => const QuestionScreen())),
              child: const Text(S.start),
            ),
        ]),
      ),
    );
  }
}
