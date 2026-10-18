import 'dart:async';

import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/models/dev_plan.dart';
import 'package:discover_personality/data/models/saved_result.dart';
import 'package:discover_personality/data/social/social_api.dart';
import 'package:discover_personality/data/social/social_models.dart';
import 'package:discover_personality/data/supabase/cloud_api.dart';
import 'package:discover_personality/features/social/chat_list_screen.dart';
import 'package:discover_personality/features/social/chat_screen.dart';
import 'package:discover_personality/features/social/community_screen.dart';
import 'package:discover_personality/features/social/gift_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

class _ConfiguredCloud implements CloudApi {
  @override
  bool get isConfigured => true;
  @override
  String? get userId => 'me';
  @override
  String? get accessToken => 't';
  @override
  Future<void> upsertResult(SavedResult r) async {}
  @override
  Future<void> upsertPlan(DevPlan p) async {}
  @override
  Future<void> deleteAccount() async {}
}

class FakeSocial extends NoSocialApi {
  FakeSocial({this.profile, this.similar = const [], this.giftError});
  SocialProfile? profile;
  List<SimilarUser> similar;
  Object? giftError;
  final sentGifts = <String>[];
  final sentKeys = <String>[];
  final sentMessages = <String>[];
  int markReads = 0;
  final controller = StreamController<List<ChatMessage>>.broadcast();

  @override
  bool get available => true;
  @override
  String? get userId => 'me';
  @override
  Future<SocialProfile?> myProfile() async => profile;
  @override
  Future<bool> isAdmin() async => false;
  @override
  Future<List<SimilarUser>> findSimilar() async => similar;
  @override
  Future<void> publishFeatures(List<double> features) async {}
  @override
  Future<WalletInfo> wallet() async => const WalletInfo(coins: 120, rewards: 7, lastDailyClaim: null);
  @override
  Future<List<ConversationSummary>> conversations() async => [
        ConversationSummary(id: 'c1', otherId: 'u2', otherUsername: 'سارة', otherEmoji: '🐬', lastSeen: null, lastBody: 'مرحبا', lastKind: 'text', lastAt: DateTime.utc(2026), unread: 3),
      ];
  @override
  Future<List<GiftItem>> gifts() async => const [
        GiftItem(id: 'g1', name: 'فنجان قهوة', emoji: '☕', price: 5, tier: 'basic', active: true, startsAt: null, endsAt: null, sortOrder: 1),
        GiftItem(id: 'g2', name: 'ابتسامة', emoji: '😊', price: 0, tier: 'free', active: true, startsAt: null, endsAt: null, sortOrder: 0),
      ];
  @override
  Future<void> sendGift(String conversationId, String giftId, String idempotencyKey) async {
    if (giftError != null) throw giftError!;
    sentGifts.add(giftId);
    sentKeys.add(idempotencyKey);
  }

  @override
  Stream<List<ChatMessage>> messages(String conversationId) => controller.stream;
  @override
  Future<void> sendMessage(String conversationId, String text) async => sentMessages.add(text);
  @override
  Future<void> markRead(String conversationId) async => markReads++;
}

Future<ProviderScope> scope(Widget child, {SocialApi? social, bool configured = true, List<Override> extra = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(p),
      questionBankProvider.overrideWithValue(loadBank()),
      if (configured) cloudApiProvider.overrideWithValue(_ConfiguredCloud()),
      if (social != null) socialApiProvider.overrideWithValue(social),
      ...extra,
    ],
    child: child,
  );
}

void main() {
  testWidgets('without cloud configuration the social tabs explain why they are off', (tester) async {
    await tester.pumpWidget(await scope(const MaterialApp(home: CommunityScreen()), configured: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('تحتاج تفعيل الحساب السحابي'), findsOneWidget);
    await tester.pumpWidget(await scope(const MaterialApp(home: ChatListScreen()), configured: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('تحتاج تفعيل الحساب السحابي'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('new social user sees the consent form first (nothing is shared by default)', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await scope(const MaterialApp(home: CommunityScreen()), social: FakeSocial()));
    await tester.pumpAndSettle();
    expect(find.text('قبل أن يظهر ملفك للآخرين'), findsOneWidget);
    final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(boxes.first.value, isFalse); // 18+ not pre-checked
    expect(boxes[1].value, isFalse); // sharing not pre-checked
  });

  testWidgets('complete profile lists similar people with percentage and a chat button', (tester) async {
    final api = FakeSocial(
      profile: const SocialProfile(username: 'ali', avatarEmoji: '🦅', shareResults: true, showLastSeen: true, ageConfirmed: true, banned: false),
      similar: const [SimilarUser(userId: 'u2', username: 'سارة', emoji: '🐬', similarity: 82)],
    );
    await tester.pumpWidget(await scope(const MaterialApp(home: CommunityScreen()), social: api));
    await tester.pumpAndSettle();
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('تشابه في الصفات: 82٪'), findsOneWidget);
    expect(find.text('دردشة'), findsOneWidget);
    expect(find.textContaining('رصيدك: 120'), findsOneWidget);
  });

  testWidgets('chat list shows newest conversations with unread counters and search', (tester) async {
    await tester.pumpWidget(await scope(const MaterialApp(home: ChatListScreen()), social: FakeSocial()));
    await tester.pumpAndSettle();
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('سارة'), findsNothing);
    await tester.pumpWidget(const SizedBox()); // dispose: cancels the refresh timer
  });

  testWidgets('chat screen shows messages, time and read state, sends text and marks incoming as read', (tester) async {
    final api = FakeSocial();
    await tester.pumpWidget(await scope(
      const MaterialApp(home: ChatScreen(conversationId: 'c1', otherId: 'u2', otherName: 'سارة', otherEmoji: '🐬')),
      social: api,
    ));
    await tester.pump();
    api.controller.add([
      ChatMessage(id: 'a', conversationId: 'c1', senderId: 'u2', kind: 'text', body: 'أهلًا بك', giftId: null, createdAt: DateTime.utc(2026, 1, 1, 10), readAt: null),
      ChatMessage(id: 'b', conversationId: 'c1', senderId: 'me', kind: 'text', body: 'مرحبًا', giftId: null, createdAt: DateTime.utc(2026, 1, 1, 10, 1), readAt: DateTime.utc(2026, 1, 1, 10, 2)),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('أهلًا بك'), findsOneWidget);
    expect(find.text('مرحبًا'), findsOneWidget);
    expect(find.textContaining('قُرئت'), findsOneWidget);
    expect(api.markReads, greaterThanOrEqualTo(1));
    await tester.enterText(find.byType(TextField), 'كيف حالك؟');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(api.sentMessages, ['كيف حالك؟']);
  });

  testWidgets('gift sheet: confirm dialog, one request with a unique idempotency key', (tester) async {
    final api = FakeSocial();
    await tester.pumpWidget(await scope(
      MaterialApp(home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showGiftSheet(c, conversationId: 'c1', otherName: 'سارة'), child: const Text('open')))))),
      social: api,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('رصيدك: 120'), findsOneWidget);
    expect(find.text('فنجان قهوة'), findsOneWidget);
    await tester.tap(find.text('فنجان قهوة'));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد إرسال الهدية'), findsOneWidget);
    expect(api.sentGifts, isEmpty, reason: 'nothing is sent before confirmation');
    await tester.tap(find.text('إرسال'));
    await tester.pumpAndSettle();
    expect(api.sentGifts, ['g1']);
    expect(api.sentKeys.single.length, 36);
  });

  testWidgets('gift sheet: server refusal (insufficient coins) is shown as a friendly message', (tester) async {
    final api = FakeSocial(giftError: Exception('insufficient_coins'));
    await tester.pumpWidget(await scope(
      MaterialApp(home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showGiftSheet(c, conversationId: 'c1', otherName: 'سارة'), child: const Text('open')))))),
      social: api,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فنجان قهوة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال'));
    await tester.pumpAndSettle();
    expect(find.textContaining('رصيدك من العملات لا يكفي'), findsOneWidget);
  });
}
