import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../privacy/privacy_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة وإخلاء المسؤولية')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const DisclaimerBanner(),
          const SectionCard(
            title: 'إخلاء المسؤولية',
            icon: Icons.gavel_outlined,
            child: BulletList([
              'التطبيق للتأمل الذاتي والتعلم فقط، ولا يقدّم تشخيصًا نفسيًا ولا علاجًا ولا استشارة مهنية.',
              'لا تتخذ قرارات مصيرية (وظيفية أو طبية أو قانونية) اعتمادًا على هذه النتائج وحدها.',
              'إذا كنت تعاني من ضيق نفسي مستمر فاستشر مختصًا مؤهلًا.',
              'رمز A-R-F-D نظام أصلي خاص بالتطبيق وليس مقياسًا معتمدًا، وMBTI وEnneagram من الأطر الشائعة ذات الأدلة العلمية المتفاوتة.',
              'أسئلة هذا الاختبار نسخة أولية تحتاج إلى تحقق علمي (ثبات وصدق) قبل أي استخدام جاد.',
            ]),
          ),
          const SectionCard(
            title: 'أسئلة شائعة',
            icon: Icons.help_outline,
            child: BulletList([
              'هل أحتاج إلى حساب؟ لا. الاختبار والنتائج والخطة تعمل دون حساب ودون إنترنت.',
              'هل يُحفظ تقدمي إذا أغلقت التطبيق؟ نعم، يُحفظ تلقائيًا ويمكنك المتابعة.',
              'لماذا تظهر بعض الأبعاد «متقاربة»؟ لأن الفارق بين القطبين صغير ولا يمكن الجزم بتفضيل.',
              'هل يمكنني إعادة الاختبار؟ نعم، ويمكنك مقارنة النتائج من سجل التقدم.',
              'كيف أحذف بياناتي؟ من الإعدادات.',
            ]),
          ),
          OutlinedButton(onPressed: () => pushScreen(context, const PrivacyScreen()), child: const Text('سياسة الخصوصية')),
        ]),
      ),
    );
  }
}
