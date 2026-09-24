// lib/core/services/ad_service.dart

/// Outcome of a rewarded-ad request.
enum RewardedAdResult {
  /// The player watched the ad; grant the reward.
  rewarded,

  /// The ad opened but the player closed it early; no reward, no error.
  dismissed,

  /// No ad could be shown (offline, no fill, SDK not ready) — the caller
  /// shows the "Bağlantı yok · reklam yüklenemedi" toast and offers a retry.
  unavailable,
}

/// Network-agnostic ad gate (architecture.md §6.1). Every ad-paid action in
/// the game (sixth rack slot, "Şimdi değiştir", the hint) awaits
/// [showRewarded] and acts only on [RewardedAdResult.rewarded]. The MVP
/// implementation is [MockAdService]; the AdMob implementation plugs into the
/// same call so the gameplay code never changes.
abstract class AdService {
  Future<RewardedAdResult> showRewarded();
}
