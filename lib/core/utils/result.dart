// lib/core/utils/result.dart

/// A discriminated union for operations that may succeed with [T] or fail
/// with an error value [E].
///
/// Prefer this over throwing exceptions in service and repository layers so
/// callers are forced to handle both outcomes at compile time
/// (coding-standards.md §1.8).
///
/// ```dart
/// final Result<Level, AppException> result = await levelRepo.load(id);
/// switch (result) {
///   case Ok(:final value):
///     // use value
///   case Err(:final error):
///     // handle error
/// }
/// ```
sealed class Result<T, E> {
  const Result();

  /// Returns `true` when this result is [Ok].
  bool get isOk => this is Ok<T, E>;

  /// Returns `true` when this result is [Err].
  bool get isErr => this is Err<T, E>;

  /// Returns the success value or throws [StateError] if this is [Err].
  ///
  /// Prefer a `switch` expression over calling this directly; it makes the
  /// error branch explicit.
  T get valueOrThrow => switch (this) {
    Ok(:final value) => value,
    Err() => throw StateError('Called valueOrThrow on an Err result.'),
  };

  /// Transforms the success value with [fn], leaving [Err] unchanged.
  Result<U, E> map<U>(U Function(T value) fn) => switch (this) {
    Ok(:final value) => Ok(fn(value)),
    Err(:final error) => Err(error),
  };

  /// Chains a fallible operation; short-circuits on [Err].
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) fn) => switch (this) {
    Ok(:final value) => fn(value),
    Err(:final error) => Err(error),
  };
}

/// Represents a successful outcome carrying [value].
final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Represents a failed outcome carrying [error].
final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;

  @override
  String toString() => 'Err($error)';
}
