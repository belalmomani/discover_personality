import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/features/profile/extra_test_screen.dart';
import 'package:discover_personality/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Future<ProviderScope> scope(Widget child, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(p),
      questionBankProvider.overrideWithValue(loadBank()),
      extraTestsProvider.overrideWithValue(loadExtraTests()),
    ],
    child: child,
  );
}

void main() {
  testWidgets('profile without birth date asks for it and lists the additional tests', (tester) async {
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await scope(const MaterialApp(home: ProfileScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('أدخل تاريخ ميلادك'), findsOneWidget);
    expect(find.text('Big Five — العوامل الخمسة الكبرى'), findsOneWidget);
  });

  testWidgets('profile with 19/12/1985 shows life path 9 and the Y generation', (tester) async {
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await scope(
      const MaterialApp(home: ProfileScreen()),
      prefs: {'profile.v1': '{"birthDate":"1985-12-19","countryCode":"JO"}'},
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('رقم مسار الحياة: 9'), findsOneWidget);
    expect(find.textContaining('جيل Y'), findsWidgets);
    expect(find.textContaining('الأردن'), findsWidgets);
  });

  testWidgets('additional test: calculate stays disabled until every item is answered', (tester) async {
    final test = loadExtraTests().firstWhere((t) => t.id == 'nfc');
    await tester.pumpWidget(await scope(MaterialApp(home: ExtraTestScreen(test: test))));
    await tester.pumpAndSettle();
    final b = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(b.onPressed, isNull);
  });

  testWidgets('additional test restores the answers of an unfinished attempt', (tester) async {
    final test = loadExtraTests().firstWhere((t) => t.id == 'nfc');
    await tester.pumpWidget(await scope(
      MaterialApp(home: ExtraTestScreen(test: test)),
      prefs: {'extra_progress.v1': '{"nfc":{"1":4,"2":5,"3":2}}'},
    ));
    await tester.pumpAndSettle();
    expect(find.text('أجبت عن 3 من 6'), findsOneWidget);
  });
}
