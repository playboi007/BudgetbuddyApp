import 'package:flutter/foundation.dart';
import 'cache_manager.dart';

abstract class BaseProvider with ChangeNotifier {
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  final CacheManager _cache = CacheManager();

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  Future<void> initializeWithDelay(Duration delay) async {
    if (_isInitialized) return;

    try {
      await Future.delayed(delay);
      await initialize();
      _isLoading = false;
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  T? getCached<T>(String section, String key) {
    return _cache.get<T>(section, key);
  }

  void cache<T>(String section, String key, T value, {Duration? ttl}) {
    _cache.put<T>(section, key, value, ttl: ttl);
  }

  void clearCache(String section) {
    _cache.clear(section);
  }

  bool isCached(String section, String key) {
    return _cache.containsKey(section, key);
  }

  @protected
  Future<void> initialize();
}
