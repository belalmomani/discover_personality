import 'dart:typed_data';

/// Client-side checks for chat images (the server re-checks type and size).
/// Only JPEG, PNG and WebP up to 2 MB are accepted, judged by the REAL file signature, not the extension.
enum ChatImageType { jpeg, png, webp }

const int chatImageMaxBytes = 2 * 1024 * 1024;

class ChatImageCheck {
  const ChatImageCheck.ok(this.type)
      : ok = true,
        error = null;
  const ChatImageCheck.fail(this.error)
      : ok = false,
        type = null;
  final bool ok;
  final ChatImageType? type;
  final String? error;

  String get mime => type == ChatImageType.jpeg ? 'image/jpeg' : (type == ChatImageType.png ? 'image/png' : 'image/webp');
  String get ext => type == ChatImageType.jpeg ? 'jpg' : (type == ChatImageType.png ? 'png' : 'webp');
}

bool _starts(Uint8List b, List<int> sig, [int offset = 0]) {
  if (b.length < offset + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[offset + i] != sig[i]) return false;
  }
  return true;
}

ChatImageCheck validateChatImage(Uint8List bytes, {int maxBytes = chatImageMaxBytes}) {
  if (bytes.isEmpty) return const ChatImageCheck.fail('empty');
  if (bytes.length > maxBytes) return const ChatImageCheck.fail('too_large');
  if (_starts(bytes, [0xFF, 0xD8, 0xFF])) return const ChatImageCheck.ok(ChatImageType.jpeg);
  if (_starts(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return const ChatImageCheck.ok(ChatImageType.png);
  if (_starts(bytes, [0x52, 0x49, 0x46, 0x46]) && _starts(bytes, [0x57, 0x45, 0x42, 0x50], 8)) {
    return const ChatImageCheck.ok(ChatImageType.webp);
  }
  return const ChatImageCheck.fail('unsupported_type');
}

/// `<sender>/<conversation>/<uuid>.<ext>` (same format the server policies require).
String chatImagePath(String senderId, String conversationId, String fileUuid, ChatImageType type) {
  final ext = type == ChatImageType.jpeg ? 'jpg' : (type == ChatImageType.png ? 'png' : 'webp');
  return '$senderId/$conversationId/$fileUuid.$ext';
}
