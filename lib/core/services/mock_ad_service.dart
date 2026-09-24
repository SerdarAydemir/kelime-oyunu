// lib/core/services/mock_ad_service.dart

import 'package:kelime_oyunu/core/services/ad_service.dart';

/// Stand-in until the AdMob SDK is wired: answers every request with
/// [result] after [delay]. `const MockAdService()` rewards instantly (the
/// default for the app); `MockAdService(result: RewardedAdResult.unavailable)`
/// exercises the offline toast.
class MockAdService implements AdService {
  const MockAdService({this.result = RewardedAdResult.rewarded, this.delay = Duration.zero});

  final RewardedAdResult result;
  final Duration delay;

  @override
  Future<RewardedAdResult> showRewarded() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}
