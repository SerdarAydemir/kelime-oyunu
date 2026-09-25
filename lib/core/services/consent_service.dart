// lib/core/services/consent_service.dart

/// Outcome of a consent request (UMP-shaped, SDK-agnostic).
enum ConsentStatus {
  /// The player accepted personalised ads.
  personalized,

  /// The player declined personalisation — generic ads only.
  nonPersonalized,
}

/// Consent gate (CLAUDE.md "Monetizasyon": UMP runs before the ad SDK is
/// initialised). The MVP is [MockConsentService]; the UMP implementation
/// plugs into the same three calls in FAZ 6.
abstract class ConsentService {
  /// First-run flow behind "Kabul et ve başla".
  Future<ConsentStatus> requestConsent();

  /// "Seçenekleri yönet" / "Reklam tercihleri": re-opens the options form.
  Future<ConsentStatus> showPrivacyOptions();

  /// iOS App Tracking Transparency prompt (the system dialog). Returns true
  /// when tracking was authorised. No-op false on other platforms.
  Future<bool> requestTracking();
}

/// Stand-in until UMP / ATT are wired: answers with [status] and [tracking].
class MockConsentService implements ConsentService {
  const MockConsentService({this.status = ConsentStatus.personalized, this.tracking = false});

  final ConsentStatus status;
  final bool tracking;

  @override
  Future<ConsentStatus> requestConsent() async => status;

  @override
  Future<ConsentStatus> showPrivacyOptions() async => status;

  @override
  Future<bool> requestTracking() async => tracking;
}
