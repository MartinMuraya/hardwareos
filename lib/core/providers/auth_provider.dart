import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  AuthState _state = AuthState.initial;
  bool _isRegistered = false;
  bool _isSuperAdmin = false;
  String? _businessStatus;
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;

  User?                  get user          => _user;
  AuthState              get state         => _state;
  bool                   get isAuthenticated => _state == AuthState.authenticated;
  bool                   get isEmailVerified => _user?.emailVerified ?? false;
  bool                   get isRegistered  => _isRegistered;
  bool                   get isSuperAdmin  => _isSuperAdmin;
  String?                get businessStatus => _businessStatus;
  bool                   get isLoading     => _state == AuthState.loading;
  Map<String, dynamic>?  get userProfile   => _userProfile;
  String?                get errorMessage  => _errorMessage;
  String?                get businessId    => _userProfile?['businessId'] as String?;
  String?                get userRole      => _userProfile?['role'] as String?;
  String?                get subscriptionStatus => _userProfile?['subscriptionStatus'] as String?;
  String?                get photoUrl      => _user?.photoURL ?? _userProfile?['photoUrl'] as String?;
  
  DateTime?              get subscriptionEndsAt {
    final val = _userProfile?['subscriptionEndsAt'];
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is Map && val.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(val['_seconds'] * 1000);
    }
    return null;
  }

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
      // Ensure we have the latest emailVerified status
      await user.reload();
      _user = _auth.currentUser; 
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
      _isSuperAdmin = data['isSuperAdmin'] == true;
      
      if (_isRegistered) {
        _userProfile = Map<String, dynamic>.from(data['user'] as Map);
        final biz = Map<String, dynamic>.from(data['business'] as Map);
        _businessStatus = biz['status'] as String?;
        
        // Ensure subscription info is available in the profile for the router/getters
        _userProfile!['subscriptionStatus'] = biz['subscriptionStatus'];
        _userProfile!['subscriptionEndsAt'] = biz['subscriptionEndsAt'];
        _userProfile!['plan'] = biz['plan'];
      } else {
        _userProfile = null;
        _businessStatus = null;
      }
      _state = AuthState.authenticated;
    } catch (e) {
      _isRegistered = false;
      _isSuperAdmin = false;
      _businessStatus = null;
      _state = AuthState.authenticated;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _errorMessage = null;
    _state = AuthState.loading;
    notifyListeners();
    try {
      await _repo.signInWithEmail(email, password);
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
      final cred = await _repo.registerWithEmail(email, password);
      await cred.user?.sendEmailVerification(); // Automatically send verification email
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _errorMessage = null;
    _state = AuthState.loading;
    notifyListeners();
    try {
      final cred = await _repo.signInWithGoogle();
      if (cred == null) {
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An error occurred during Google Sign In.';
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _repo.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send password reset email. Check if the email is correct.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendEmailVerification() async {
    try {
      await _repo.sendEmailVerification();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send verification email. Please try again later.';
      notifyListeners();
      return false;
    }
  }

  Future<void> reloadUser() async {
    await _user?.reload();
    _user = _auth.currentUser;
    notifyListeners();
  }

  Future<bool> uploadProfilePicture() async {
    if (_user == null) return false;
    _state = AuthState.loading;
    notifyListeners();
    
    final url = await _repo.uploadProfilePicture(_user!.uid);
    if (url != null) {
      await reloadUser();
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Failed to upload profile picture.';
      _state = AuthState.authenticated;
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
    await _repo.signOut();
  }

  Future<void> refreshProfile() async {
    if (_user != null) {
      await _loadUserProfile();
    }
  }

  Future<void> refreshUserProfile() async {
    await _loadUserProfile();
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
