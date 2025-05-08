import 'package:flutter/foundation.dart';

abstract class BaseProvider with ChangeNotifier {
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;

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

  @protected
  Future<void> initialize();
}
