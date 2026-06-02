// lib/core/errors/app_exception.dart

/// Base sealed exception type for all application-layer failures.
///
/// Prefer returning [Result<T, AppException>] from service / repository methods
/// so callers are forced to handle both outcomes at compile time
/// (coding-standards.md §3.3).
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a requested puzzle ID is not found in the manifest or assets.
class PuzzleNotFoundException extends AppException {
  const PuzzleNotFoundException(super.message);
}

/// Thrown when a network operation fails (reserved for future remote features).
class NetworkException extends AppException {
  const NetworkException(super.message);
}
