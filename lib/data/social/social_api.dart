import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils.dart';
import 'image_validator.dart';

import 'share_vectors.dart';
import 'social_models.dart';

/// Gateway to the social backend. Every rule is enforced by Supabase (RLS + SECURITY DEFINER
/// functions); the app only calls these methods and never computes balances itself.
abstract class SocialApi {
  /// Supabase is configured AND a user is signed in.
  bool get available;
  String? get userId;

  Future<SocialProfile?> myProfile();
  Future<void> saveProfile({
    required String username,
    required String emoji,
    required bool shareResults,
    required bool showLastSeen,
    required bool ageConfirmed,
    bool visible = true,
    bool allowChat = true,
  });

  /// Publishes the per-test score vectors used for the weighted similarity.
  Future<void> publishScores(List<TestVector> vectors);
  Future<List<SimilarUser>> findSimilar();
  Future<String> startConversation(String otherId);
  Future<List<ConversationSummary>> conversations();
  Stream<List<ChatMessage>> messages(String conversationId);
  Future<void> sendMessage(String conversationId, String text);

  /// Validates (real signature, <= 2 MB), uploads to the private bucket and creates the message.
  Future<void> sendImage(String conversationId, Uint8List bytes);

  /// Short-lived signed URL for an image message path.
  Future<String> imageUrl(String path);
  Future<void> markRead(String conversationId);
  Future<void> touchPresence();
  Future<void> block(String userId);
  Future<void> unblock(String userId);
  Future<List<BlockedUser>> blocked();
  Future<void> report(String userId, String? messageId, String reason);

  Future<WalletInfo> wallet();
  Future<int> claimDaily();
  Future<List<GiftItem>> gifts();
  Future<void> sendGift(String conversationId, String giftId, String idempotencyKey);

  // Admin (server re-checks admin rights on every call)
  Future<bool> isAdmin();
  Future<List<GiftItem>> adminGifts();
  Future<void> saveGift(GiftItem gift, {bool isNew = false});
  Future<List<ReportRow>> adminReports(String? status);
  Future<void> resolveReport(String id, String status);
  Future<void> setBan(String userId, bool banned);
  Future<Map<String, String>> settings();
  Future<void> setSetting(String key, String value);
  Future<Map<String, dynamic>> stats();
}

class NoSocialApi implements SocialApi {
  Never _off() => throw StateError('social_unavailable');
  @override
  bool get available => false;
  @override
  String? get userId => null;
  @override
  Future<SocialProfile?> myProfile() async => _off();
  @override
  Future<void> saveProfile({required String username, required String emoji, required bool shareResults, required bool showLastSeen, required bool ageConfirmed, bool visible = true, bool allowChat = true}) async => _off();
  @override
  Future<void> publishScores(List<TestVector> vectors) async => _off();
  @override
  Future<List<SimilarUser>> findSimilar() async => _off();
  @override
  Future<String> startConversation(String otherId) async => _off();
  @override
  Future<List<ConversationSummary>> conversations() async => _off();
  @override
  Stream<List<ChatMessage>> messages(String conversationId) => Stream.error(StateError('social_unavailable'));
  @override
  Future<void> sendMessage(String conversationId, String text) async => _off();
  @override
  Future<void> sendImage(String conversationId, Uint8List bytes) async => _off();
  @override
  Future<String> imageUrl(String path) async => _off();
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<void> touchPresence() async {}
  @override
  Future<void> block(String userId) async => _off();
  @override
  Future<void> unblock(String userId) async => _off();
  @override
  Future<List<BlockedUser>> blocked() async => [];
  @override
  Future<void> report(String userId, String? messageId, String reason) async => _off();
  @override
  Future<WalletInfo> wallet() async => _off();
  @override
  Future<int> claimDaily() async => _off();
  @override
  Future<List<GiftItem>> gifts() async => _off();
  @override
  Future<void> sendGift(String conversationId, String giftId, String idempotencyKey) async => _off();
  @override
  Future<bool> isAdmin() async => false;
  @override
  Future<List<GiftItem>> adminGifts() async => _off();
  @override
  Future<void> saveGift(GiftItem gift, {bool isNew = false}) async => _off();
  @override
  Future<List<ReportRow>> adminReports(String? status) async => _off();
  @override
  Future<void> resolveReport(String id, String status) async => _off();
  @override
  Future<void> setBan(String userId, bool banned) async => _off();
  @override
  Future<Map<String, String>> settings() async => _off();
  @override
  Future<void> setSetting(String key, String value) async => _off();
  @override
  Future<Map<String, dynamic>> stats() async => _off();
}

class SupabaseSocialApi implements SocialApi {
  SupabaseClient get _c => Supabase.instance.client;

  List<Map<String, dynamic>> _rows(dynamic data) =>
      [for (final e in (data as List)) Map<String, dynamic>.from(e as Map)];

  @override
  bool get available => _c.auth.currentUser != null;
  @override
  String? get userId => _c.auth.currentUser?.id;

  @override
  Future<SocialProfile?> myProfile() async {
    final rows = _rows(await _c.rpc('my_profile'));
    return rows.isEmpty ? null : SocialProfile.fromJson(rows.first);
  }

  @override
  Future<void> saveProfile({required String username, required String emoji, required bool shareResults, required bool showLastSeen, required bool ageConfirmed, bool visible = true, bool allowChat = true}) async {
    await _c.rpc('save_my_profile', params: {
      'p_username': username,
      'p_emoji': emoji,
      'p_share': shareResults,
      'p_show_last_seen': showLastSeen,
      'p_age_confirmed': ageConfirmed,
      'p_visible': visible,
      'p_allow_chat': allowChat,
    });
  }

  @override
  Future<void> publishScores(List<TestVector> vectors) async {
    if (vectors.isEmpty) return;
    await _c.rpc('publish_scores_batch', params: {'payload': [for (final v in vectors) v.toJson()]});
  }

  @override
  Future<List<SimilarUser>> findSimilar() async =>
      _rows(await _c.rpc('find_similar')).map(SimilarUser.fromJson).toList();

  @override
  Future<String> startConversation(String otherId) async =>
      (await _c.rpc('start_conversation', params: {'other': otherId})) as String;

  @override
  Future<List<ConversationSummary>> conversations() async =>
      _rows(await _c.rpc('my_conversations')).map(ConversationSummary.fromJson).toList();

  @override
  Stream<List<ChatMessage>> messages(String conversationId) => _c
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) => rows.map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r))).toList());

  @override
  Future<void> sendMessage(String conversationId, String text) async {
    await _c.rpc('send_message', params: {'conv': conversationId, 'text_body': text});
  }

  @override
  Future<void> sendImage(String conversationId, Uint8List bytes) async {
    final uid = userId;
    if (uid == null) throw StateError('not_authenticated');
    final check = validateChatImage(bytes);
    if (!check.ok) throw StateError('invalid_image');
    final path = chatImagePath(uid, conversationId, newUuid(), check.type!);
    final bucket = _c.storage.from('chat-images');
    await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: check.mime, upsert: false));
    try {
      await _c.rpc('send_image_message', params: {'conv': conversationId, 'p_path': path});
    } catch (e) {
      try {
        await bucket.remove([path]); // do not leave an orphan file behind
      } catch (_) {}
      rethrow;
    }
  }

  final Map<String, ({String url, DateTime at})> _urlCache = {};

  @override
  Future<String> imageUrl(String path) async {
    final cached = _urlCache[path];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 40)) return cached.url;
    final url = await _c.storage.from('chat-images').createSignedUrl(path, 3600);
    _urlCache[path] = (url: url, at: DateTime.now());
    return url;
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _c.rpc('mark_read', params: {'conv': conversationId});
  }

  @override
  Future<void> touchPresence() async {
    await _c.rpc('touch_presence');
  }

  @override
  Future<void> block(String userId) async {
    await _c.rpc('block_user', params: {'target': userId});
  }

  @override
  Future<void> unblock(String userId) async {
    await _c.rpc('unblock_user', params: {'target': userId});
  }

  @override
  Future<List<BlockedUser>> blocked() async => [
        for (final r in _rows(await _c.rpc('blocked_users'))) BlockedUser(r['user_id'] as String, (r['username'] as String?) ?? 'مستخدم'),
      ];

  @override
  Future<void> report(String userId, String? messageId, String reason) async {
    await _c.rpc('report_user', params: {'target': userId, 'msg': messageId, 'p_reason': reason});
  }

  @override
  Future<WalletInfo> wallet() async => WalletInfo.fromJson(_rows(await _c.rpc('my_wallet')).first);

  @override
  Future<int> claimDaily() async => ((await _c.rpc('claim_daily_coins')) as num).toInt();

  @override
  Future<List<GiftItem>> gifts() async {
    final rows = _rows(await _c.from('gifts').select().order('sort_order'));
    final now = DateTime.now().toUtc();
    return rows.map(GiftItem.fromJson).where((g) => g.isAvailableAt(now)).toList();
  }

  @override
  Future<void> sendGift(String conversationId, String giftId, String idempotencyKey) async {
    await _c.rpc('send_gift', params: {'conv': conversationId, 'p_gift': giftId, 'idem': idempotencyKey});
  }

  @override
  Future<bool> isAdmin() async => ((await _c.rpc('am_i_admin')) as bool?) ?? false;

  @override
  Future<List<GiftItem>> adminGifts() async =>
      _rows(await _c.from('gifts').select().order('sort_order')).map(GiftItem.fromJson).toList();

  @override
  Future<void> saveGift(GiftItem g, {bool isNew = false}) async {
    final data = {
      'name': g.name,
      'emoji': g.emoji,
      'price': g.price,
      'tier': g.tier,
      'active': g.active,
      'sort_order': g.sortOrder,
      'starts_at': g.startsAt?.toUtc().toIso8601String(),
      'ends_at': g.endsAt?.toUtc().toIso8601String(),
    };
    if (isNew) {
      await _c.from('gifts').insert(data);
    } else {
      await _c.from('gifts').update(data).eq('id', g.id);
    }
  }

  @override
  Future<List<ReportRow>> adminReports(String? status) async =>
      _rows(await _c.rpc('admin_list_reports', params: {'p_status': status})).map(ReportRow.fromJson).toList();

  @override
  Future<void> resolveReport(String id, String status) async {
    await _c.rpc('admin_resolve_report', params: {'p_id': id, 'p_status': status});
  }

  @override
  Future<void> setBan(String userId, bool banned) async {
    await _c.rpc('admin_set_ban', params: {'target': userId, 'p_banned': banned});
  }

  @override
  Future<Map<String, String>> settings() async => {
        for (final r in _rows(await _c.from('app_settings').select())) r['key'] as String: r['value'] as String,
      };

  @override
  Future<void> setSetting(String key, String value) async {
    await _c.rpc('admin_set_setting', params: {'k': key, 'v': value});
  }

  @override
  Future<Map<String, dynamic>> stats() async => Map<String, dynamic>.from((await _c.rpc('admin_stats')) as Map);
}
