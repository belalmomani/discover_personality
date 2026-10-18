import 'package:discover_personality/data/social/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('similarity', () {
    test('identical vectors are 100%', () {
      final v = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
      expect(similarityPct(v, v), 100);
    });
    test('opposite extremes are 0%', () {
      expect(similarityPct(List.filled(8, 0.0), List.filled(8, 1.0)), 0);
    });
    test('one feature differs by 0.5: 100*(1-0.5/sqrt(8)) = 82%', () {
      final a = List.filled(8, 0.5);
      expect(similarityPct(a, [1.0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]), 82);
    });
    test('symmetric', () {
      final a = [0.1, 0.9, 0.3, 0.4, 0.5, 0.6, 0.2, 0.8];
      final b = [0.6, 0.4, 0.9, 0.1, 0.5, 0.3, 0.7, 0.2];
      expect(similarityPct(a, b), similarityPct(b, a));
    });
  });

  test('profile completeness requires username, sharing, 18+ confirmation and not banned', () {
    SocialProfile p({String? u = 'ali', bool share = true, bool age = true, bool banned = false}) => SocialProfile(
        username: u, avatarEmoji: '🙂', shareResults: share, showLastSeen: true, ageConfirmed: age, banned: banned);
    expect(p().isComplete, isTrue);
    expect(p(u: null).isComplete, isFalse);
    expect(p(share: false).isComplete, isFalse);
    expect(p(age: false).isComplete, isFalse);
    expect(p(banned: true).isComplete, isFalse);
  });

  test('gift availability window mirrors the server rule', () {
    GiftItem g({bool active = true, DateTime? s, DateTime? e}) =>
        GiftItem(id: '1', name: 'x', emoji: '🎁', price: 5, tier: 'basic', active: active, startsAt: s, endsAt: e, sortOrder: 1);
    final now = DateTime.utc(2026, 6, 1);
    expect(g().isAvailableAt(now), isTrue);
    expect(g(active: false).isAvailableAt(now), isFalse);
    expect(g(s: now.add(const Duration(days: 1))).isAvailableAt(now), isFalse);
    expect(g(e: now.subtract(const Duration(days: 1))).isAvailableAt(now), isFalse);
    expect(g(s: now.subtract(const Duration(days: 1)), e: now.add(const Duration(days: 1))).isAvailableAt(now), isTrue);
  });

  test('wallet daily claim availability', () {
    final now = DateTime.utc(2026, 6, 1, 15);
    expect(WalletInfo(coins: 0, rewards: 0, lastDailyClaim: null).canClaimDaily(now), isTrue);
    expect(WalletInfo(coins: 0, rewards: 0, lastDailyClaim: DateTime.utc(2026, 6, 1)).canClaimDaily(now), isFalse);
    expect(WalletInfo(coins: 0, rewards: 0, lastDailyClaim: DateTime.utc(2026, 5, 31)).canClaimDaily(now), isTrue);
  });

  test('json parsing of messages, conversations, similar users and wallet', () {
    final m = ChatMessage.fromJson({
      'id': 'm1', 'conversation_id': 'c1', 'sender_id': 'u1', 'kind': 'gift', 'body': '', 'gift_id': 'g1',
      'created_at': '2026-01-01T10:00:00Z', 'read_at': null,
    });
    expect(m.isGift, isTrue);
    expect(m.isRead, isFalse);
    final c = ConversationSummary.fromJson({
      'conversation_id': 'c1', 'other_id': 'u2', 'other_username': null, 'other_emoji': '🦅', 'other_last_seen': null,
      'last_body': 'hi', 'last_kind': 'text', 'last_at': '2026-01-01T10:00:00Z', 'unread': 3,
    });
    expect(c.otherUsername, 'مستخدم');
    expect(c.lastSeen, isNull);
    expect(c.unread, 3);
    final s = SimilarUser.fromJson({'user_id': 'u3', 'username': 'sara', 'avatar_emoji': '🐬', 'similarity': 82});
    expect(s.similarity, 82);
    final w = WalletInfo.fromJson({'coins': 10, 'rewards': 4, 'last_daily_claim': null});
    expect(w.coins, 10);
  });

  test('server error codes map to friendly Arabic messages without leaking details', () {
    expect(socialErrorMessage(Exception('PostgrestException(message: insufficient_coins)')), contains('رصيدك'));
    expect(socialErrorMessage(Exception('already_claimed')), contains('عد غدًا'));
    expect(socialErrorMessage(Exception('free_limit_reached')), contains('الهدايا المجانية'));
    final unknown = socialErrorMessage(Exception('relation "x" does not exist at SELECT secret'));
    expect(unknown.contains('secret'), isFalse);
    expect(unknown, contains('تعذر'));
  });
}
