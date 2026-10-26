import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../social/social_api.dart';
import 'push_service.dart';

/// Firebase Cloud Messaging implementation. Everything is guarded: if the build has no
/// google-services.json (no Firebase project configured) every call degrades to "unsupported".
class FirebasePushService implements PushService {
  final StreamController<String> _open = StreamController<String>.broadcast();
  bool _ready = false;
  bool _listening = false;
  StreamSubscription<String>? _refresh;

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _ready = true;
      return true;
    } catch (e) {
      debugPrint('Firebase not available in this build: $e');
      return false;
    }
  }

  @override
  Stream<String> get openConversation => _open.stream;

  @override
  Future<PushResult> enable(SocialApi api) async {
    if (!await _init()) return PushResult.unsupported;
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return PushResult.denied;
      final token = await m.getToken();
      if (token == null || token.isEmpty) return PushResult.failed;
      await api.registerPushToken(token);
      _refresh ??= m.onTokenRefresh.listen((t) {
        api.registerPushToken(t).catchError((Object _) {});
      });
      await startListening(api);
      return PushResult.enabled;
    } catch (e) {
      debugPrint('Push enable failed: $e');
      return PushResult.failed;
    }
  }

  @override
  Future<void> disable(SocialApi api) async {
    if (!await _init()) {
      await api.disablePush();
      return;
    }
    try {
      final m = FirebaseMessaging.instance;
      final token = await m.getToken();
      if (token != null) await api.unregisterPushToken(token);
      await m.deleteToken();
    } catch (_) {
      await api.disablePush();
    }
  }

  @override
  Future<void> startListening(SocialApi api) async {
    if (_listening || !await _init()) return;
    _listening = true;
    try {
      FirebaseMessaging.onMessage.listen((_) {
        // A message reached this device while the app is open: mark it delivered.
        api.markDelivered().catchError((Object _) {});
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['conversation_id'];
        if (id is String) _open.add(id);
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      final id = initial?.data['conversation_id'];
      if (id is String) _open.add(id);
    } catch (e) {
      debugPrint('Push listeners failed: $e');
    }
  }
}
