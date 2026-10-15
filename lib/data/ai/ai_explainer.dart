import 'dart:convert';

import 'package:http/http.dart' as http;

/// Optional AI explanation. It can only ADD text; it can never change scores.
abstract class AiExplainer {
  bool get isAvailable;
  Future<String> explain(Map<String, dynamic> payload);
}

class DisabledAiExplainer implements AiExplainer {
  @override
  bool get isAvailable => false;
  @override
  Future<String> explain(Map<String, dynamic> payload) =>
      Future.error(StateError('AI is not configured'));
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Calls YOUR secure proxy (e.g. supabase/functions/ai-explain). No provider key lives in the app.
/// Expected response: {"text": "..."}.
class ProxyAiExplainer implements AiExplainer {
  ProxyAiExplainer({required this.url, this.tokenProvider, http.Client? client})
      : _client = client ?? http.Client();

  final String url;
  final String? Function()? tokenProvider;
  final http.Client _client;

  @override
  bool get isAvailable => url.isNotEmpty;

  @override
  Future<String> explain(Map<String, dynamic> payload) async {
    final token = tokenProvider?.call();
    final res = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'scores': payload}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw AiException('تعذر الحصول على التفسير (${res.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final text = body['text'];
    if (text is! String || text.trim().isEmpty) {
      throw AiException('رد غير صالح من الخادم الوسيط.');
    }
    return text;
  }
}
