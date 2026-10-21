// Models for the social layer (similar people, chat, gifts). Pure Dart, no Flutter imports.

class SocialProfile {
  const SocialProfile({
    required this.username,
    required this.avatarEmoji,
    required this.shareResults,
    required this.showLastSeen,
    required this.ageConfirmed,
    required this.banned,
    this.visible = true,
    this.allowChat = true,
  });

  /// Shown to other people in "people like you" (false = hidden).
  final bool visible;

  /// Chat switched on (messages and gifts are refused when either side switches it off).
  final bool allowChat;
  final String? username;
  final String avatarEmoji;
  final bool shareResults;
  final bool showLastSeen;
  final bool ageConfirmed;
  final bool banned;

  /// Ready to appear in similarity search and chat.
  bool get isComplete => username != null && username!.isNotEmpty && shareResults && ageConfirmed && !banned;

  factory SocialProfile.fromJson(Map<String, dynamic> j) => SocialProfile(
        username: j['username'] as String?,
        avatarEmoji: (j['avatar_emoji'] as String?) ?? '🙂',
        shareResults: (j['share_results'] as bool?) ?? false,
        showLastSeen: (j['show_last_seen'] as bool?) ?? true,
        ageConfirmed: (j['age_confirmed'] as bool?) ?? false,
        banned: (j['banned'] as bool?) ?? false,
        visible: (j['visible'] as bool?) ?? true,
        allowChat: (j['allow_chat'] as bool?) ?? true,
      );
}

class SimilarUser {
  const SimilarUser({
    required this.userId,
    required this.username,
    required this.emoji,
    required this.similarity,
    this.testsUsed = 0,
    this.questionsUsed = 0,
    this.canChat = true,
  });

  /// How many shared tests (and how many questions in them) the similarity is based on.
  final int testsUsed;
  final int questionsUsed;

  /// False when either side switched chat off.
  final bool canChat;
  final String userId;
  final String username;
  final String emoji;
  final int similarity;

  factory SimilarUser.fromJson(Map<String, dynamic> j) => SimilarUser(
        userId: j['user_id'] as String,
        username: (j['username'] as String?) ?? 'مستخدم',
        emoji: (j['avatar_emoji'] as String?) ?? '🙂',
        similarity: (j['similarity'] as num).toInt(),
        testsUsed: ((j['tests_used'] as num?) ?? 0).toInt(),
        questionsUsed: ((j['questions_used'] as num?) ?? 0).toInt(),
        canChat: (j['can_chat'] as bool?) ?? true,
      );
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.otherId,
    required this.otherUsername,
    required this.otherEmoji,
    required this.lastSeen,
    required this.lastBody,
    required this.lastKind,
    required this.lastAt,
    required this.unread,
  });
  final String id;
  final String otherId;
  final String otherUsername;
  final String otherEmoji;

  /// null when the other user hides their last-seen time.
  final DateTime? lastSeen;
  final String? lastBody;
  final String? lastKind;
  final DateTime? lastAt;
  final int unread;

  factory ConversationSummary.fromJson(Map<String, dynamic> j) => ConversationSummary(
        id: j['conversation_id'] as String,
        otherId: j['other_id'] as String,
        otherUsername: (j['other_username'] as String?) ?? 'مستخدم',
        otherEmoji: (j['other_emoji'] as String?) ?? '🙂',
        lastSeen: j['other_last_seen'] == null ? null : DateTime.parse(j['other_last_seen'] as String),
        lastBody: j['last_body'] as String?,
        lastKind: j['last_kind'] as String?,
        lastAt: j['last_at'] == null ? null : DateTime.parse(j['last_at'] as String),
        unread: ((j['unread'] as num?) ?? 0).toInt(),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.giftId,
    required this.createdAt,
    required this.readAt,
  });
  final String id;
  final String conversationId;
  final String senderId;
  final String kind; // 'text' | 'gift'
  final String body;
  final String? giftId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isGift => kind == 'gift';
  bool get isImage => kind == 'image';
  bool get isRead => readAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        kind: (j['kind'] as String?) ?? 'text',
        body: (j['body'] as String?) ?? '',
        giftId: j['gift_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        readAt: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
      );
}

class GiftItem {
  const GiftItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.tier,
    required this.active,
    required this.startsAt,
    required this.endsAt,
    required this.sortOrder,
  });
  final String id;
  final String name;
  final String emoji;
  final int price;
  final String tier; // free | basic | mid | rare | seasonal
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int sortOrder;

  bool get isFree => price == 0;

  /// Mirrors the server-side rule (the server is the authority).
  bool isAvailableAt(DateTime now) =>
      active && (startsAt == null || !startsAt!.isAfter(now)) && (endsAt == null || endsAt!.isAfter(now));

  factory GiftItem.fromJson(Map<String, dynamic> j) => GiftItem(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        price: (j['price'] as num).toInt(),
        tier: (j['tier'] as String?) ?? 'basic',
        active: (j['active'] as bool?) ?? true,
        startsAt: j['starts_at'] == null ? null : DateTime.parse(j['starts_at'] as String),
        endsAt: j['ends_at'] == null ? null : DateTime.parse(j['ends_at'] as String),
        sortOrder: ((j['sort_order'] as num?) ?? 0).toInt(),
      );
}

class WalletInfo {
  const WalletInfo({required this.coins, required this.rewards, required this.lastDailyClaim});
  final int coins;
  final int rewards;
  final DateTime? lastDailyClaim;

  bool canClaimDaily(DateTime nowUtc) {
    final c = lastDailyClaim;
    if (c == null) return true;
    return !(c.year == nowUtc.year && c.month == nowUtc.month && c.day == nowUtc.day);
  }

  factory WalletInfo.fromJson(Map<String, dynamic> j) => WalletInfo(
        coins: (j['coins'] as num).toInt(),
        rewards: (j['rewards'] as num).toInt(),
        lastDailyClaim: j['last_daily_claim'] == null ? null : DateTime.parse(j['last_daily_claim'] as String),
      );
}

class BlockedUser {
  const BlockedUser(this.userId, this.username);
  final String userId;
  final String username;
}

class ReportRow {
  const ReportRow({
    required this.id,
    required this.reporter,
    required this.reportedId,
    required this.reported,
    required this.messageBody,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String reporter;
  final String reportedId;
  final String reported;
  final String? messageBody;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory ReportRow.fromJson(Map<String, dynamic> j) => ReportRow(
        id: j['id'] as String,
        reporter: (j['reporter'] as String?) ?? 'مستخدم',
        reportedId: j['reported_id'] as String,
        reported: (j['reported'] as String?) ?? 'مستخدم',
        messageBody: j['message_body'] as String?,
        reason: j['reason'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Same rule as the SQL function feature_similarity: 100 * (1 - euclidean / sqrt(8)), rounded.
int similarityPct(List<double> a, List<double> b) {
  assert(a.length == 8 && b.length == 8);
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    s += d * d;
  }
  var g = s > 1 ? s / 2 : 1.0;
  if (s <= 0) return 100;
  for (var i = 0; i < 30; i++) {
    g = 0.5 * (g + s / g);
  }
  const maxDist = 2.8284271247461903;
  return (100 * (1 - g / maxDist)).round();
}

/// Maps server error codes (RAISE EXCEPTION messages) to friendly Arabic text.
String socialErrorMessage(Object e) {
  final t = e.toString();
  const map = <String, String>{
    'insufficient_coins': 'رصيدك من العملات لا يكفي لهذه الهدية.',
    'free_limit_reached': 'وصلت إلى حد الهدايا المجانية لليوم.',
    'already_claimed': 'حصلت على عملات اليوم بالفعل. عد غدًا.',
    'daily_coins_disabled': 'العملات اليومية غير مفعّلة حاليًا.',
    'gift_unavailable': 'هذه الهدية غير متاحة حاليًا.',
    'blocked': 'لا يمكن التواصل مع هذا المستخدم.',
    'banned': 'حسابك موقوف.',
    'rate_limited': 'أرسلت عددًا كبيرًا من الطلبات. انتظر قليلًا.',
    'not_similar_enough': 'نسبة التشابه أقل من الحد المطلوب للدردشة.',
    'not_eligible': 'يجب إكمال ملفك الاجتماعي وتأكيد العمر أولًا.',
    'username_taken': 'اسم المستخدم محجوز، اختر اسمًا آخر.',
    'invalid_username': 'اسم المستخدم 3 إلى 20 حرفًا (حروف وأرقام وشرطة سفلية).',
    'age_required': 'يجب تأكيد أن عمرك 18 سنة أو أكثر.',
    'invalid_message': 'الرسالة فارغة أو أطول من 1000 حرف.',
    'forbidden': 'غير مسموح لك بهذا الإجراء.',
    'chat_disabled': 'الدردشة مغلقة عند أحد الطرفين.',
    'invalid_image': 'الصورة غير مدعومة أو أكبر من 2 ميجابايت (JPEG أو PNG أو WebP فقط).',
    'image_limit': 'وصلت إلى الحد الأقصى للصور في الساعة. حاول لاحقًا.',
    'not_authenticated': 'سجّل الدخول أولًا.',
  };
  for (final entry in map.entries) {
    if (t.contains(entry.key)) return entry.value;
  }
  // Unknown error: show only a short technical hint (code + brief message) to help diagnose,
  // never a stack trace, URL or key.
  final code = RegExp(r'code:\s*([A-Za-z0-9_]{2,12})').firstMatch(t)?.group(1);
  final msg = RegExp(r'message:\s*(.{1,80}?)(?=,\s*(?:code|details|hint):|\)?\s*$)').firstMatch(t)?.group(1)?.trim();
  final safe = msg != null && !RegExp(r'(sb_|eyJ|https?://)').hasMatch(msg);
  final hint = [if (code != null) code, if (safe) msg].join(' • ');
  return 'تعذر تنفيذ العملية. تحقق من اتصالك وحاول مجددًا.${hint.isEmpty ? "" : "\n(رمز تقني: $hint)"}';
}
