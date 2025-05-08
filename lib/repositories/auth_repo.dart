/// Auth controller that handles user authentication and profile data with caching to improve performance
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

class AuthRepo extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached user data
  String _userName = 'User';
  bool _isLoading = false;
  String? _error;

  // Getters
  String get userName => _userName;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Singleton instance
  static final AuthRepo _instance = AuthRepo._internal();

  // Factory constructor
  factory AuthRepo() => _instance;

  // Private constructor
  AuthRepo._internal();

  /// Loads user name from Firestore with caching
  Future<String> loadUserName() async {
    // Add synchronization to prevent multiple concurrent Firestore calls
    final lock = Lock();

    return await lock.synchronized(() async {
      // If we already have the username and not in error state, return cached value
      if (_userName != 'User' && _error == null) {
        return _userName;
      }

      _isLoading = true;
      _error = null;

      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Get user data from Firestore
          final userDoc =
              await _firestore.collection('users').doc(user.uid).get();

          if (userDoc.exists && userDoc.data()?['name'] != null) {
            _userName = userDoc.data()!['name'];
          } else {
            _userName = 'User';
          }
        }

        _isLoading = false;
        return _userName;
      } catch (e) {
        // Handle any errors during user data fetch
        _isLoading = false;
        _error = e.toString();
        _userName = 'User';

        if (kDebugMode) {
          print('Error loading user name: $e');
        }
        return _userName;
      }
    });
  }

  /// Clears cached user data
  void clearCache() {
    _userName = 'User';
    _error = null;
  }
}
