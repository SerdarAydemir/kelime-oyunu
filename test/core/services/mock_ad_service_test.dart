// test/core/services/mock_ad_service_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/services/ad_service.dart';
import 'package:kelime_oyunu/core/services/mock_ad_service.dart';

void main() {
  test('rewards instantly by default', () async {
    expect(await const MockAdService().showRewarded(), RewardedAdResult.rewarded);
  });

  test('answers with the configured result', () async {
    const offline = MockAdService(result: RewardedAdResult.unavailable);
    expect(await offline.showRewarded(), RewardedAdResult.unavailable);
    const closed = MockAdService(result: RewardedAdResult.dismissed);
    expect(await closed.showRewarded(), RewardedAdResult.dismissed);
  });
}
