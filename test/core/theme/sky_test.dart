// test/core/theme/sky_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/theme/sky.dart';

void main() {
  test('sky off: the theme gradient, whatever the progress', () {
    for (final p in [0.0, 0.5, 1.0]) {
      expect(homeSky(AppTokens.dark, progress: p, enabled: false), AppTokens.dark.bgHome);
      expect(mapSky(AppTokens.light, progress: p, enabled: false), AppTokens.light.bgMap);
    }
  });

  test('sky on: night at the start, dawn halfway, day at the summit', () {
    expect(homeSky(AppTokens.dark, progress: 0, enabled: true), AppTokens.dark.bgHome);
    expect(homeSky(AppTokens.dark, progress: 0.5, enabled: true), AppTokens.dark.bgWon);
    expect(homeSky(AppTokens.dark, progress: 1, enabled: true), AppTokens.light.bgHome);
    // In between it is a blend, not a snap.
    final quarter = homeSky(AppTokens.dark, progress: 0.25, enabled: true);
    expect(quarter, isNot(AppTokens.dark.bgHome));
    expect(quarter, isNot(AppTokens.dark.bgWon));
  });
}
