import 'package:flutter/foundation.dart';
import 'dart:async';

/// Represents a cached value with metadata
class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final DateTime expiresAt;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  }) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get ageInSeconds => DateTime.now().difference(createdAt).inSeconds;
}

/// Manages caching of data with configurable TTL (Time-To-Live)
class CacheService {
  final Map<String, _CacheEntry> _cache = {};
  final Duration _defaultTTL;
  Timer? _cleanupTimer;

  static const String _logTag = '[CacheService]';

  CacheService({
    Duration defaultTTL = const Duration(minutes: 5),
  }) : _defaultTTL = defaultTTL {
    _startCleanupTimer();
  }

  /// Get a cached value
  T? get<T>(String key) {
    final entry = _cache[key] as _CacheEntry?;

    if (entry == null) {
      if (kDebugMode) {
        debugPrint('$_logTag Cache MISS: $key');
      }
      return null;
    }

    if (entry.isExpired) {
      _cache.remove(key);
      if (kDebugMode) {
        debugPrint('$_logTag Cache EXPIRED: $key (${entry.ageInSeconds}s old)');
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint('$_logTag Cache HIT: $key (${entry.ageInSeconds}s old)');
    }

    return entry.value as T;
  }

  /// Set a cached value with optional custom TTL
  void set<T>(
    String key,
    T value, {
    Duration? ttl,
  }) {
    final expiresAt = DateTime.now().add(ttl ?? _defaultTTL);
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: expiresAt,
    );

    if (kDebugMode) {
      final ttlSeconds = (ttl ?? _defaultTTL).inSeconds;
      debugPrint('$_logTag Cache SET: $key (TTL: ${ttlSeconds}s)');
    }
  }

  /// Check if a key exists and is not expired
  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Get all cached keys
  List<String> getAllKeys() {
    return _cache.keys.toList();
  }

  /// Invalidate cache entries matching a pattern
  int invalidate(String pattern) {
    int count = 0;
    final keysToRemove = <String>[];

    for (final key in _cache.keys) {
      if (key.contains(pattern)) {
        keysToRemove.add(key);
        count++;
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (kDebugMode) {
      debugPrint('$_logTag Cache INVALIDATED: $count entries matching "$pattern"');
    }

    return count;
  }

  /// Remove a specific cache entry
  bool remove(String key) {
    final removed = _cache.remove(key) != null;
    if (removed && kDebugMode) {
      debugPrint('$_logTag Cache REMOVED: $key');
    }
    return removed;
  }

  /// Clear all cache entries
  void clear() {
    final count = _cache.length;
    _cache.clear();

    if (kDebugMode) {
      debugPrint('$_logTag Cache CLEARED: $count entries removed');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    int expiredCount = 0;
    int validCount = 0;

    for (final entry in _cache.values) {
      if (entry.isExpired) {
        expiredCount++;
      } else {
        validCount++;
      }
    }

    return {
      'total': _cache.length,
      'valid': validCount,
      'expired': expiredCount,
      'keys': _cache.keys.toList(),
    };
  }

  /// Clear expired entries
  int clearExpired() {
    int count = 0;
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
        count++;
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (kDebugMode) {
      debugPrint('$_logTag Cache CLEANUP: $count expired entries removed');
    }

    return count;
  }

  /// Start automatic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    // Run cleanup every 5 minutes
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        clearExpired();
      },
    );

    if (kDebugMode) {
      debugPrint('$_logTag Cache cleanup timer started');
    }
  }

  /// Stop cleanup timer and clear cache
  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();

    if (kDebugMode) {
      debugPrint('$_logTag Cache service disposed');
    }
  }
}

/// Specialized cache for Firestore documents
class DocumentCache extends CacheService {
  DocumentCache({
    Duration defaultTTL = const Duration(minutes: 5),
  }) : super(defaultTTL: defaultTTL);

  /// Cache a document
  void setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) {
    final key = '$collection/$documentId';
    set(key, data, ttl: ttl);
  }

  /// Get a cached document
  Map<String, dynamic>? getDocument(
    String collection,
    String documentId,
  ) {
    final key = '$collection/$documentId';
    return get<Map<String, dynamic>>(key);
  }

  /// Invalidate all documents in a collection
  int invalidateCollection(String collection) {
    return invalidate('$collection/');
  }
}

/// Specialized cache for query results
class QueryCache extends CacheService {
  QueryCache({
    Duration defaultTTL = const Duration(minutes: 10),
  }) : super(defaultTTL: defaultTTL);

  /// Cache query results
  void setQueryResult(
    String queryId,
    List<Map<String, dynamic>> results, {
    Duration? ttl,
  }) {
    set(queryId, results, ttl: ttl);
  }

  /// Get cached query results
  List<Map<String, dynamic>>? getQueryResult(String queryId) {
    return get<List<Map<String, dynamic>>>(queryId);
  }

  /// Generate consistent query ID
  static String generateQueryId(
    String collection, {
    Map<String, dynamic>? filters,
    String? orderBy,
    bool descending = false,
  }) {
    final filterStr = filters?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
    final orderStr = orderBy != null ? '$orderBy:${descending ? 'desc' : 'asc'}' : '';
    final combined = [collection, filterStr, orderStr].where((s) => s.isNotEmpty).join('|');
    return combined;
  }
}
