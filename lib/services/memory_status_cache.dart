import '../services/memory_session.dart';

/// Lightweight in-memory cache for memory debug-status payloads.
///
/// Quota rule: reading this cache must NOT hit the backend by default.
/// Admin monitor writes into it after a manual/light refresh. Graph page can read
/// [latest] or call [get(allowBackendFetch: false)] without burning Firestore.
class MemoryStatusCache {
  static Map<String, dynamic>? _lastStatus;
  static int _fetchedAt = 0;
  static const Duration _ttl = Duration(seconds: 60);

  /// Most recent cached status without triggering a fetch. Nullable.
  static Map<String, dynamic>? get latest => _lastStatus;

  static bool get hasFreshValue {
    if (_lastStatus == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - _fetchedAt) < _ttl.inMilliseconds;
  }

  /// Overwrites the cache. Called by the admin monitor on successful light loads.
  static void set(Map<String, dynamic> status) {
    _lastStatus = Map<String, dynamic>.from(status);
    _fetchedAt = DateTime.now().millisecondsSinceEpoch;
  }

  /// Returns cached data. Backend fetch is opt-in only to protect Firestore quota.
  static Future<Map<String, dynamic>?> get({bool allowBackendFetch = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastStatus != null && (now - _fetchedAt) < _ttl.inMilliseconds) {
      return _lastStatus;
    }
    if (!allowBackendFetch) return _lastStatus;
    try {
      await MemorySession.ensureInitialized();
      final status = await MemorySession.debugStatus();
      set(status);
      return _lastStatus;
    } catch (_) {
      return _lastStatus; // best-effort — return stale if fetch fails
    }
  }
}
