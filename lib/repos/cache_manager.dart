import 'dart:collection';

class CacheEntry<T> {
  T value;
  final DateTime expiryTime;
  DateTime lastAccessed;

  CacheEntry({
    required this.value,
    required Duration ttl,
  })  : expiryTime = DateTime.now().add(ttl),
        lastAccessed = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiryTime);
}

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, LinkedHashMap<String, CacheEntry<dynamic>>> _caches = {};

  final int _maxEntriesPerSection = 100;
  final Duration _defaultTTL = const Duration(minutes: 30);

  T? get<T>(String section, String key) {
    final cache = _caches[section];
    if (cache == null) return null;

    final entry = cache[key];
    if (entry == null || entry.isExpired) {
      cache.remove(key);
      return null;
    }

    entry.lastAccessed = DateTime.now();
    return entry.value as T;
  }

  void put<T>(String section, String key, T value, {Duration? ttl}) {
    var cache = _caches[section];
    if (cache == null) {
      cache = LinkedHashMap<String, CacheEntry<dynamic>>();
      _caches[section] = cache;
    }

    /// Implement LRU eviction
    if (cache.length >= _maxEntriesPerSection) {
      final oldestKey = cache.keys.first;
      cache.remove(oldestKey);
    }

    cache[key] = CacheEntry<T>(
      value: value,
      ttl: ttl ?? _defaultTTL,
    );
  }

  void clear(String section) => _caches.remove(section);

  void clearAll() => _caches.clear();

  bool containsKey(String section, String key) {
    final cache = _caches[section];
    if (cache == null) return false;
    final entry = cache[key];
    if (entry == null || entry.isExpired) return false;
    return true;
  }
}
