import 'entitlement_store.dart';
import 'play_channel.dart';

/// An explicit no-network boundary for the independent local-feature fork.
class DisabledEntitlementApi implements EntitlementApi {
  const DisabledEntitlementApi();

  Future<T> _disabled<T>() =>
      Future.error(EntitlementApiException(403, 'local_edition'));

  @override
  Future<String> refresh(String token, String deviceId) => _disabled();

  @override
  Future<String> verifyPlay({
    required String idToken,
    required String purchaseToken,
    required String deviceId,
    required String deviceClass,
  }) => _disabled();

  @override
  Future<String> redeemAfdian({
    required String orderNo,
    required String deviceId,
    required String deviceClass,
  }) => _disabled();

  @override
  Future<String> redeemBeta({
    required String code,
    required String deviceId,
    required String deviceClass,
  }) => _disabled();

  @override
  Future<String> claimVip({
    required String deviceId,
    required String deviceClass,
  }) => _disabled();

  @override
  Future<EntitlementStatus> status(String token) => _disabled();
}

/// Even an accidentally mounted legacy screen cannot start native purchases,
/// Google account selection, advertising, or ad-consent prompts in this fork.
class DisabledPlayChannel extends PlayChannel {
  const DisabledPlayChannel();

  @override
  bool get available => false;

  @override
  bool get signInConfigured => false;
}
