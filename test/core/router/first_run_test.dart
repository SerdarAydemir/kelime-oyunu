// test/core/router/first_run_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/router/first_run.dart';
import 'package:kelime_oyunu/data/models/app_settings.dart';

void main() {
  test('a fresh install goes to consent on every platform', () {
    expect(firstRoute(const AppSettings(), isIOS: false), '/consent');
    expect(firstRoute(const AppSettings(), isIOS: true), '/consent');
  });

  test('after consent, iOS sees the ATT pre-prompt once; Android skips it', () {
    const consented = AppSettings(consentDone: true, onboardingDone: true);
    expect(firstRoute(consented, isIOS: true), '/consent/att');
    expect(firstRoute(consented, isIOS: false), '/');
    expect(
      firstRoute(
        const AppSettings(consentDone: true, attAsked: true, onboardingDone: true),
        isIOS: true,
      ),
      '/',
    );
  });

  test('the tutorial follows consent (and ATT) until it was seen once', () {
    expect(firstRoute(const AppSettings(consentDone: true), isIOS: false), '/onboarding?first=1');
    expect(
      firstRoute(const AppSettings(consentDone: true, attAsked: true), isIOS: true),
      '/onboarding?first=1',
    );
    expect(
      firstRoute(const AppSettings(consentDone: true, onboardingDone: true), isIOS: false),
      '/',
    );
  });
}
