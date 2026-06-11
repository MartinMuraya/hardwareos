import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  AuthState _state = AuthState.initial;
  bool _isRegistered = false;
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;

  User?                  get user          => _user;
  AuthState              get state         => _state;
  bool                   get isAuthenticated => _state == AuthState.authenticated;
  bool                   get isRegistered  => _isRegistered;
  bool                   get isLoading     => _state == AuthState.loading;
  Map<String, dynamic>?  get userProfile   => _userProfile;
  String?                get errorMessage  => _errorMessage;
  String?                get businessId    => _userProfile?['businessId'] as String?;
  String?                get userRole      => _userProfile?['role'] as String?;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user == null) {
      _state = AuthState.unauthenticated;
      _isRegistered = false;
      _userProfile = null;
    } else {
      _state = AuthState.loading;
      notifyListeners();
      await _loadUserProfile();
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getMyProfile');
      final result = await fn.call();
      final data = Map<String, dynamic>.from(result.data as Map);
      _isRegistered = data['registered'] == true;
      _userProfile  = _isRegistered ? Map<String, dynamic>.from(data['user'] as Map) : null;
      _state        = AuthState.authenticated;
    } catch (e) {
      _isRegistered = false;
      _state        = AuthState.authenticated;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _errorMessage = null;
    _state = AuthState.loading;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createAccount(String email, String password) async {
    _errorMessage = null;
    _state = AuthState.loading;
    notifyListeners();
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createBusiness(String businessName) async {
    _errorMessage = null;
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('createBusiness');
      await fn.call({'businessName': businessName});
      await _loadUserProfile();
      notifyListeners();
      return true;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = e.message ?? 'Failed to create business.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':      return 'No account found with this email.';
      case 'wrong-password':      return 'Incorrect password.';
      case 'email-already-in-use':return 'An account with this email already exists.';
      case 'weak-password':       return 'Password must be at least 6 characters.';
      case 'invalid-email':       return 'Please enter a valid email address.';
      case 'too-many-requests':   return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'Network error. Check your connection.';
      default:                    return 'Authentication failed. Please try again.';
    }
  }
}
