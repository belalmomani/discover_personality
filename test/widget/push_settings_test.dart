import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/push/push_service.dart';
import 'package:discover_personality/data/social/social_api.dart';
import 'package:discover_personality/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

class _Api extends NoSocialApi {
  bool pushOn = false;
  @override
  bool get available => true;
  @override
  Future<bool> myPushEnabled() async => pushOn;
}

class _Push implements PushService {
  _Push(this.result);
  PushResult result;
  int enables = 0, disables = 0;
  @override
  Future<PushResult> enable(SocialApi api) async {
    enables++;
    return result;
  }

  @override
  Future<void> disable(SocialApi api) async => disables++;
  @override
  Future<void> startListening(SocialApi api) async {}
  @override
  Stream<String> get openConversation => const Stream.empty();
}

Future<ProviderScope> scope(_Api api, _Push push) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(p),
      questionBankProvider.overrideWithValue(loadBank()),
      socialApiProvider.overrideWithValue(api),
      pushServiceProvider.overrideWithValue(push),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  final tile = find.widgetWithText(SwitchListTile, 'تنبيهي عند وصول رسالة جديدة');

  testWidgets('notifications are off by default and the tile explains that text is never shown', (tester) async {
    await tester.pumpWidget(await scope(_Api(), _Push(PushResult.enabled)));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(find.textContaining('لا يظهر نص الرسالة'), findsOneWidget);
  });

  testWidgets('switching on registers the device and shows the switch as on', (tester) async {
    final push = _Push(PushResult.enabled);
    await tester.pumpWidget(await scope(_Api(), push));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(push.enables, 1);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });

  testWidgets('unsupported build (no Firebase) keeps the switch off and explains why', (tester) async {
    final push = _Push(PushResult.unsupported);
    await tester.pumpWidget(await scope(_Api(), push));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(find.textContaining('تحتاج إعداد Firebase'), findsOneWidget);
  });

  testWidgets('denied permission keeps the switch off and points to the phone settings', (tester) async {
    await tester.pumpWidget(await scope(_Api(), _Push(PushResult.denied)));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(find.textContaining('رفضتَ إذن الإشعارات'), findsOneWidget);
  });

  testWidgets('switching off unregisters the device', (tester) async {
    final api = _Api()..pushOn = true;
    final push = _Push(PushResult.enabled);
    await tester.pumpWidget(await scope(api, push));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(push.disables, 1);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
  });
}
