import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthRepository? _repo;
  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  final Future<Map<String, dynamic>> Function()? _profileFetcher;
  StreamSubscription<User?>? _authStateSubscription;

  User? _user;
  AuthState _state = AuthState.initial;
  bool _isRegistered = false;
  bool _isSuperAdmin = false;
  String? _businessStatus;
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;
  String?
      _profileLoadError; // tracks network/internal errors during profile fetch

  User? get user => _user;
  AuthState get state => _state;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isEmailVerified => _user?.emailVerified ?? false;
  bool get isRegistered => _isRegistered;
  bool get isSuperAdmin => _isSuperAdmin;
  String? get businessStatus => _businessStatus;
  bool get isLoading => _state == AuthState.loading;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get errorMessage => _errorMessage;
  String? get profileLoadError => _profileLoadError;
  String? get businessId => _userProfile?['businessId']?.toString();
  String? get userRole => _userProfile?['role']?.toString();
  String? get subscriptionStatus =>
      _userProfile?['subscriptionStatus']?.toString();
  String? get photoUrl =>
      _user?.photoURL ?? _userProfile?['photoUrl']?.toString();

  DateTime? get subscriptionEndsAt {
    final val = _userProfile?['subscriptionEndsAt'];
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is Map && val.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(val['_seconds'] * 1000);
    }
    return null;
  }

  /// AuthProvider constructor
  ///
  /// Optional parameters allow injecting test doubles for FirebaseAuth, FirebaseFunctions,
  /// AuthRepository or a custom profileFetcher for unit tests. Set attachAuthState=false to
  /// avoid registering the real authStateChanges listener during tests.
  AuthProvider({
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? functions,
    AuthRepository? repo,
    Future<Map<String, dynamic>> Function()? profileFetcher,
    bool attachAuthState = true,
  }) : _profileFetcher = profileFetcher {
    // Lazily initialize Firebase clients only when needed. This allows tests to
    // create the provider without requiring Firebase.initializeApp().
    _auth = firebaseAuth ?? (attachAuthState ? FirebaseAuth.instance : null);
    // If a profileFetcher is provided by tests, we don't need real FirebaseFunctions
    _functions = functions ??
        (profileFetcher == null ? FirebaseFunctions.instance : null);
    _repo = repo ?? (attachAuthState ? AuthRepository() : null);
    if (attachAuthState && _auth != null) {
      _authStateSubscription =
          _auth!.authStateChanges().listen(_onAuthStateChanged);
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
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
      try {
        await user.reload();
      } catch (e) {
        debugPrint('Error reloading user: $e');
      }
      _user = _auth?.currentUser;
      await _loadUserProfile();
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    _profileLoadError = null;
    try {
      Map<String, dynamic> data;
      if (_profileFetcher != null) {
        // Test injection path
        data = await _profileFetcher!();
      } else {
        final fn = _functions!.httpsCallable('getMyProfile');
        final result = await fn.call();
        data = Map<String, dynamic>.from(result.data as Map);
      }

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

        _state = AuthState.authenticated;
      } else {
        _userProfile = null;
        _businessStatus = null;
        _state = AuthState.authenticated; // Must remain authenticated so the router can direct to /register
      }
    } on FirebaseFunctionsException catch (e) {
      // On profile load errors, do NOT treat the user as authenticated.
      // Force unauthenticated state and surface the error so the UI can require re-login
      _isRegistered = false;
      _isSuperAdmin = false;
      _businessStatus = null;
      _state = AuthState.unauthenticated;
      _profileLoadError =
          e.message ?? 'An error occurred connecting to the server.';
      _errorMessage = 'Failed to load profile. Please sign in again.';
    } catch (e) {
      // Generic fallback - mark unauthenticated and surface message
      _isRegistered = false;
      _isSuperAdmin = false;
      _businessStatus = null;
      _state = AuthState.unauthenticated;
      _profileLoadError = 'An unexpected error occurred loading your profile.';
      _errorMessage = 'Failed to load profile. Please sign in again.';
    }
  }

  /// Test helper: allow tests to invoke profile load with a provided user context.
  Future<void> loadProfileForTest([User? user]) async {
    _user = user;
    await _loadUserProfile();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _errorMessage = null;
    final fn = FirebaseFunctions.instance.httpsCallable;

    try {
      // Check login abuse rate limit before attempting auth
      await fn('checkLoginLocked').call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted' || e.code == 'unauthenticated' || e.message?.toLowerCase().contains('too many') == true) {
        _errorMessage = 'Too many failed login attempts. Please try again later.';
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (_) {
      // Ignore other errors (e.g., function not deployed)
    }

    _state = AuthState.loading;
    notifyListeners();
    try {
      if (_repo == null) {
        _errorMessage = 'Auth repository not initialized.';
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
      await _repo!.signInWithEmail(email, password);
      try {
        await fn('reportSuccessfulLogin').call({'email': email});
      } catch (_) {}
      return true;
    } on FirebaseAuthException catch (e) {
      try {
        await fn('reportFailedLogin').call({'email': email});
      } catch (_) {}
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
      if (_repo == null) {
        _errorMessage = 'Auth repository not initialized.';
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
      final cred = await _repo!.registerWithEmail(email, password);
      await cred.user
          ?.sendEmailVerification(); // Automatically send verification email
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
      if (_repo == null) {
        _errorMessage = 'Auth repository not initialized.';
        _state = AuthState.unauthenticated;
        notifyListeners();
        return false;
      }
      final cred = await _repo!.signInWithGoogle();
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
      final fn =
          FirebaseFunctions.instance.httpsCallable('requestPasswordReset');
      await fn.call({'email': email});
    } catch (_) {}
    // Always return the same generic message to prevent account enumeration
    return true;
  }

  Future<bool> sendEmailVerification() async {
    try {
      if (_repo == null) {
        _errorMessage = 'Auth repository not initialized.';
        notifyListeners();
        return false;
      }
      await _repo!.sendEmailVerification();
      return true;
    } catch (e) {
      _errorMessage =
          'Failed to send verification email. Please try again later.';
      notifyListeners();
      return false;
    }
  }

  Future<void> reloadUser() async {
    await _user?.reload();
    _user = _auth?.currentUser;
    notifyListeners();
  }

  Future<bool> uploadProfilePicture() async {
    if (_user == null) return false;

    // Do NOT set _state = AuthState.loading here, as it triggers a global
    // router redirect out of the authenticated area.

    final url =
        _repo == null ? null : await _repo!.uploadProfilePicture(_user!.uid);
    if (url != null) {
      await reloadUser();
      // State remains AuthState.authenticated
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
    if (_repo != null) await _repo!.signOut();
    _user = null;
    _state = AuthState.unauthenticated;
    _isRegistered = false;
    _isSuperAdmin = false;
    _businessStatus = null;
    _userProfile = null;
    _errorMessage = null;
    _profileLoadError = null;
    notifyListeners();
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
    _profileLoadError = null;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 8 characters with a mix of letters and numbers.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again. (Code: $code)';
    }
  }
}
