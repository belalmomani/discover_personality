import 'dart:convert';

import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/models/question.dart';
import 'package:discover_personality/data/models/saved_result.dart';
import 'package:discover_personality/data/scoring/scoring_engine.dart';
import 'package:discover_personality/features/integrated/integrated_report_screen.dart';
import 'package:discover_personality/features/integrated/observer_screen.dart';
import 'package:discover_personality/features/results/results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Future<(ProviderScope, String)> scopeWithResult(Widget Function(String id) child) async {
  final qs = loadBank().questions;
  final answers = buildAnswers(qs, (q) => q.system == AssessmentSystem.arfd ? (q.reverse ? 2 : 4) : (q.id * 7) % 5 + 1);
  final saved = SavedResult(id: 'res-1', createdAt: DateTime.utc(2026, 1, 1), answers: answers, result: ScoringEngine.compute(qs, answers));
  SharedPreferences.setMockInitialValues({'history.v1': jsonEncode([saved.toJson()])});
  final p = await SharedPreferences.getInstance();
  return (
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        questionBankProvider.overrideWithValue(loadBank()),
        extraTestsProvider.overrideWithValue(loadExtraTests()),
      ],
      child: child(saved.id),
    ),
    saved.id,
  );
}

void main() {
  testWidgets('integrated report shows all requested sections', (tester) async {
    tester.view.physicalSize = const Size(800, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (scope, _) = await scopeWithResult((id) => MaterialApp(home: IntegratedReportScreen(resultId: id)));
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    for (final h in ['كيف تتكامل النتائج', 'نقاط القوة', 'مصادر التعثر', 'طريقة اتخاذ القرار', 'التعامل مع الضغط', 'صورتك لدى الآخرين مقابل وصفك لنفسك', 'درجة الثقة في كل نتيجة']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(find.textContaining('لم يُقَس'), findsWidgets); // stress + self/others are honest about missing data
    expect(find.textContaining('ثقة'), findsWidgets);
  });

  testWidgets('results screen leads with the integrated analysis and keeps raw codes in a collapsible', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (scope, _) = await scopeWithResult((id) => MaterialApp(home: ResultsScreen(resultId: id)));
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    expect(find.text('افتح التحليل المتكامل'), findsOneWidget);
    expect(find.textContaining('الرموز والدرجات التفصيلية'), findsOneWidget);
  });

  testWidgets('observer screen: intro first, save stays disabled until all 10 statements are rated', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (scope, _) = await scopeWithResult((id) => const MaterialApp(home: ObserverScreen()));
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    expect(find.text('ابدأ التقييم'), findsOneWidget);
    await tester.tap(find.text('ابدأ التقييم'));
    await tester.pumpAndSettle();
    final b = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(b.onPressed, isNull);
    expect(find.text('أجبت عن 0 من 10'), findsOneWidget);
  });
}
