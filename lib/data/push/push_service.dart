import '../social/social_api.dart';

enum PushResult { enabled, denied, unsupported, failed }

/// Push notifications. Notification text never contains the message itself (privacy):
/// only "new message from <name>" / "sent you a gift" / "sent you a photo".
abstract class PushService {
  /// Asks for permission, obtains the device token and registers it on the server.
  Future<PushResult> enable(SocialApi api);

  /// Unregisters this device (and stops notifications for it).
  Future<void> disable(SocialApi api);

  /// Starts foreground / tap listeners (no-op if not supported).
  Future<void> startListening(SocialApi api);

  /// Conversation ids the user opened by tapping a notification.
  Stream<String> get openConversation;
}

/// Used when Firebase is not configured in this build.
class DisabledPushService implements PushService {
  @override
  Future<PushResult> enable(SocialApi api) async => PushResult.unsupported;
  @override
  Future<void> disable(SocialApi api) async => api.disablePush();
  @override
  Future<void> startListening(SocialApi api) async {}
  @override
  Stream<String> get openConversation => const Stream.empty();
}
