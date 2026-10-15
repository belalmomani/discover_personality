import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings_ar.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <(IconData, String, String)>[
    (Icons.psychology_alt_outlined, 'اكتشف شخصيتك', 'تطبيق يساعدك على فهم تفضيلاتك ودوافعك وطريقة اتخاذك للقرارات ونقاط قوتك وما يمكنك تطويره.'),
    (Icons.fact_check_outlined, '72 سؤالًا وثلاثة أنظمة', 'MBTI للتفضيلات، وEnneagram للدوافع، ورمز A-R-F-D الخاص بالتطبيق لأسلوب التحليل والمخاطرة والتنفيذ والدوافع.'),
    (Icons.shield_outlined, 'ليست تشخيصًا', 'النتائج وصف أولي للتأمل الذاتي وليست تشخيصًا نفسيًا ولا حقيقة علمية قطعية. الاختبار نسخة أولية لم يُتحقق من صلاحيتها علميًا. بياناتك تبقى على جهازك، ولا تحتاج إلى حساب.'),
  ];

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: _finish, child: const Text('تخطي')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(p.$1, size: 96, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(p.$2, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(p.$3, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              Container(
                margin: const EdgeInsets.all(4),
                width: i == _page ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(last ? 'ابدأ' : 'التالي'),
              ),
            ),
          ),
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text(S.prototypeNote, style: TextStyle(fontSize: 12))),
        ]),
      ),
    );
  }
}
