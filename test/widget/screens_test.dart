import 'package:discover_personality/app/app.dart';
import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/ads/ad_backend.dart';
import 'package:discover_personality/data/ads/ad_service.dart';
import 'package:discover_personality/features/assessment/question_screen.dart';
import 'package:discover_personality/features/assessment/review_screen.dart';
import 'package:discover_personality/features/home/home_screen.dart';
import 'package:discover_personality/features/results/results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

class _NeverBackend implements AdBackend {
  static int created = 0;
  _NeverBackend() {
    created++;
  }
  @override
  Future<void> initialize({required bool testMode}) async {}
  @override
  Future<Widget?> createBanner() async => null;
  @override
  Future<void> preloadInterstitial() async {}
  @override
  Future<bool> showInterstitialIfReady() async => false;
}

Future<ProviderScope> scope(Widget child, {Map<String, Object> prefs = const {}, List<Override> extra = const []}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(p),
      questionBankProvider.overrideWithValue(loadBank()),
      ...extra,
    ],
    child: child,
  );
}

void main() {
  testWidgets('app starts in Arabic with RTL direction (onboarding first)', (tester) async {
    await tester.pumpWidget(await scope(const App()));
    await tester.pumpAndSettle();
    expect(find.text('اكتشف شخصيتك'), findsWidgets);
    final dir = Directionality.of(tester.element(find.text('تخطي')));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('home screen shows empty state and the start button; no ad is requested when ads are off', (tester) async {
    _NeverBackend.created = 0;
    await tester.pumpWidget(await scope(
      const MaterialApp(locale: Locale('ar'), home: HomeScreen()),
      extra: [
        adServiceProvider.overrideWithValue(AdService(enabled: false, testMode: true, backendFactory: () => _NeverBackend())),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ الاختبار'), findsOneWidget);
    expect(find.textContaining('لا توجد تقارير بعد'), findsOneWidget);
    expect(_NeverBackend.created, 0);
  });

  testWidgets('review screen: calculate button is disabled until every question is answered', (tester) async {
    await tester.pumpWidget(await scope(const MaterialApp(home: ReviewScreen())));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'احسب النتيجة'));
    expect(button.onPressed, isNull);
    expect(find.textContaining('تمت الإجابة عن 0 من 72'), findsOneWidget);
  });

  testWidgets('question screen shows five scale options and records the answer', (tester) async {
    await tester.pumpWidget(await scope(const MaterialApp(home: QuestionScreen(fromReview: true))));
    await tester.pumpAndSettle();
    expect(find.text('ينطبق علي تمامًا'), findsOneWidget);
    expect(find.text('لا ينطبق علي إطلاقًا'), findsOneWidget);
    expect(find.textContaining('السؤال 1 من 72'), findsOneWidget);
  });

  testWidgets('results screen handles an unknown report id gracefully', (tester) async {
    await tester.pumpWidget(await scope(const MaterialApp(home: ResultsScreen(resultId: 'missing'))));
    await tester.pumpAndSettle();
    expect(find.text('لم يتم العثور على هذا التقرير.'), findsOneWidget);
  });
}
