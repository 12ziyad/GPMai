import 'dart:async';
import 'dart:math' as math;

/// Runs [action], retrying up to 3 total attempts on error.
///
/// Waits [initialDelay] before retrying, doubling the delay each attempt.
/// Set [retryOn] to return false for errors that should not be retried.
Future<T> retry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 300),
  bool Function(Object error)? retryOn,
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (e) {
      if (attempt >= maxAttempts || (retryOn != null && !retryOn(e))) {
        rethrow;
      }
      final backoff = initialDelay * math.pow(2, attempt - 1).toInt();
      await Future<void>.delayed(backoff);
    }
  }
}
