
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'cloud_sync_service.dart';
import 'app_lock_service.dart';
import 'clean_storage_service.dart';
import '../config/env_config.dart';
import '../utils/validators.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        photoUrl: json['photoUrl'],
      );

  factory UserModel.fromFirebaseUser(firebase_auth.User user) => UserModel(
        id: user.uid,
        // An account with no display name (email sign-up before the
        // updateDisplayName write lands, or an account created outside the
        // app) gets an EMPTY name, not the placeholder literal 'User'. 'User'
        // is not a name — it rendered as the Home screen's title. Call sites
        // decide their own honest fallback for an empty name.
        name: user.isAnonymous ? 'Guest' : (user.displayName ?? ''),
        email: user.isAnonymous ? '' : (user.email ?? ''),
        photoUrl: user.photoURL,
      );
}



class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  firebase_auth.FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: EnvConfig.googleServerClientId,
  );

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isGuestMode = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isGuest => _isGuestMode;
  
  /// Returns true only if user is authenticated with a real account (Google, email, etc.)
  /// Returns false for offline guests and anonymous Firebase users
  bool get isAuthenticated => _currentUser != null && !_isGuestMode && _currentUser!.email.isNotEmpty;

  static const String _userPrefKey = 'current_user_data';


  Future<void> init() async {
    try {
      _firebaseAuth = firebase_auth.FirebaseAuth.instance;
      
      // Wait for Firebase Auth to restore the persisted auth state
      // This is crucial - currentUser may be null immediately but restored shortly after
      debugPrint('AuthService Init: Waiting for auth state to be restored...');
      final restoredUser = await _firebaseAuth!.authStateChanges().first;
      debugPrint('AuthService Init: Auth state restored - user: ${restoredUser?.uid ?? "null"}');
      
      if (restoredUser != null) {
        // Update state based on restored Firebase user
        _isGuestMode = restoredUser.isAnonymous;
        _currentUser = UserModel.fromFirebaseUser(restoredUser);
        debugPrint('AuthService Init: User exists - isAnonymous: ${restoredUser.isAnonymous}, name: ${_currentUser?.name}');
        if (!restoredUser.isAnonymous) {
          _saveUser(_currentUser!);
        } else {
          // Clear any saved user data if current user is anonymous
          await _clearSavedUser();
        }
      } else {
        // No Firebase user, clear saved data and sign in as guest
        debugPrint('AuthService Init: No Firebase user, signing in anonymously');
        await _clearSavedUser();
        await signInAnonymously();
        // signInAnonymously()'s SUCCESS path never assigns _currentUser
        // itself (only its own failure path does, via
        // _enableOfflineGuestMode) — it relies on the authStateChanges()
        // listener below to pick the new user up. But that listener calls
        // .skip(1), and Firebase's authStateChanges() replays the CURRENT
        // state to a fresh listener — so on a first-ever launch, the skipped
        // event IS this anonymous sign-in, and _currentUser stays null for
        // the rest of the session (breaking anything that reads it, e.g.
        // cloud sync). Read the now-current Firebase user directly instead of
        // relying on that listener. The `_currentUser == null` guard leaves
        // an already-set offline-guest fallback (from a signInAnonymously
        // failure) untouched.
        if (_currentUser == null) {
          final signedInUser = _firebaseAuth?.currentUser;
          if (signedInUser != null) {
            _isGuestMode = signedInUser.isAnonymous;
            _currentUser = UserModel.fromFirebaseUser(signedInUser);
            debugPrint(
                'AuthService Init: Anonymous sign-in complete - uid: ${signedInUser.uid}');
          }
        }
      }
      
      // Listen to subsequent Firebase auth state changes
      _firebaseAuth?.authStateChanges().skip(1).listen((firebase_auth.User? user) {
        if (user != null) {
          _isGuestMode = user.isAnonymous;
          _currentUser = UserModel.fromFirebaseUser(user);
          debugPrint('Auth State Changed: isAnonymous: ${user.isAnonymous}, isGuest: $_isGuestMode, name: ${_currentUser?.name}');
          if (!user.isAnonymous) {
            _saveUser(_currentUser!);
          } else {
            _clearSavedUser();
          }
        } else {
          _currentUser = null;
          _isGuestMode = false;
          _clearSavedUser();
        }
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      debugPrint("Firebase Auth initialization failed: $e");
    }
  }

  Future<void> _clearSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefKey);
  }

  Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefKey, jsonEncode(user.toJson()));
  }

  /// Sign in with email and password using Firebase Auth
  Future<String?> signInWithEmailPassword(String email, String password) async {
    if (_firebaseAuth == null) {
      return 'Firebase is not initialized.';
    }
    try {
      final emailError = Validators.validateEmail(email);
      if (emailError != null) return emailError;

      final passwordError = Validators.validatePassword(password);
      if (passwordError != null) return passwordError;

      _isLoading = true;
      notifyListeners();

      await _firebaseAuth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _getErrorMessage(e.code);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred. Please try again.';
    }
  }



  /// Sign in anonymously (Guest Mode)
  Future<String?> signInAnonymously() async {
    if (_firebaseAuth == null) {
      debugPrint('Guest Auth: Firebase not initialized, enabling offline guest mode');
      _enableOfflineGuestMode();
      return null; // Allow offline guest mode
    }
    try {
      _isLoading = true;
      notifyListeners();

      await _firebaseAuth!.signInAnonymously();

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      _isLoading = false;
      debugPrint("Guest Auth Error: ${e.code} - ${e.message}\n${e.stackTrace}");
      
      // Handle specific error codes
      if (e.code == 'admin-restricted-operation' || e.code == 'operation-not-allowed') {
        _enableOfflineGuestMode();
        notifyListeners();
        return null; // Allow offline guest mode as fallback
      }
      
      if (e.code == 'internal-error' || e.code == 'network-request-failed') {
        debugPrint('Guest Auth: Network/internal error, enabling offline guest mode');
        _enableOfflineGuestMode();
        notifyListeners();
        return null; // Allow offline guest mode as fallback
      }
      
      notifyListeners();
      return _getGuestAuthErrorMessage(e.code);
    } catch (e) {
      _isLoading = false;
      debugPrint("Guest Auth Unexpected Error: $e");
      // Enable offline guest mode as fallback for any error
      _enableOfflineGuestMode();
      notifyListeners();
      return null; // Allow offline guest mode
    }
  }

  /// Enable offline guest mode when Firebase auth fails
  void _enableOfflineGuestMode() {
    _isGuestMode = true;
    _currentUser = UserModel(
      id: 'offline_guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Guest',
      email: '',
      photoUrl: null,
    );
    debugPrint('Offline guest mode enabled: ${_currentUser?.id}');
  }

  /// Get user-friendly error message for guest auth errors
  String _getGuestAuthErrorMessage(String code) {
    switch (code) {
      case 'admin-restricted-operation':
      case 'operation-not-allowed':
        return 'Guest mode is not enabled. Please sign in with Google.';
      case 'internal-error':
        return 'Service temporarily unavailable. Please try again.';
      case 'network-request-failed':
        return 'No internet connection. Using offline mode.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      default:
        return 'Authentication error. Please try again.';
    }
  }

  /// Link guest account with Google or sign in with Google
  /// If user is currently a guest, this will link the account
  /// Returns null on success, error message on failure, or 'cancelled' if user cancelled
  Future<String?> signInWithGoogle() async {
    if (_firebaseAuth == null) {
      debugPrint('ERROR: Firebase is not initialized');
      return 'Firebase is not initialized.';
    }
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('Starting Google Sign-In flow...');
      
      // Sign out first to allow account selection
      await _googleSignIn.signOut();
      debugPrint('Google Sign-In: Signed out from previous session');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      debugPrint('Google Sign-In: User selection result: ${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        // User cancelled the sign-in flow
        debugPrint('Google Sign-In: User cancelled');
        _isLoading = false;
        notifyListeners();
        return 'cancelled';
      }

      debugPrint('Google Sign-In: Getting authentication credentials...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('ERROR: Missing tokens - accessToken: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}');
        _isLoading = false;
        notifyListeners();
        return 'Failed to get authentication credentials. Please try again.';
      }
      
      debugPrint('Google Sign-In: Creating Firebase credential...');
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      firebase_auth.UserCredential userCredential;
      final isAnonymous = _firebaseAuth!.currentUser?.isAnonymous ?? false;
      debugPrint('Google Sign-In: Current user is anonymous: $isAnonymous');
      
      // If user is guest, link the account; otherwise sign in
      if (isAnonymous) {
        debugPrint('Google Sign-In: Linking anonymous account with Google...');
        try {
          userCredential = await _firebaseAuth!.currentUser!.linkWithCredential(credential);
          debugPrint('Google Sign-In: Successfully linked account');
        } on firebase_auth.FirebaseAuthException catch (linkError) {
          if (linkError.code == 'credential-already-in-use' || 
              linkError.code == 'email-already-in-use') {
            // Account exists, sign out anonymous and sign in with Google
            debugPrint('Google Sign-In: Account exists, signing out anonymous and signing in...');
            await _firebaseAuth!.signOut();
            userCredential = await _firebaseAuth!.signInWithCredential(credential);
            debugPrint('Google Sign-In: Successfully signed in with existing account');
          } else {
            rethrow;
          }
        }
      } else {
        debugPrint('Google Sign-In: Signing in with credential...');
        userCredential = await _firebaseAuth!.signInWithCredential(credential);
        debugPrint('Google Sign-In: Successfully signed in');
      }

      // Sync data with cloud after successful sign-in
      final userId = userCredential.user?.uid;
      debugPrint('Google Sign-In: User ID: $userId');
      
      if (userId != null) {
        try {
          debugPrint('Starting cloud sync for user: $userId');
          final cloudSync = CloudSyncService();
          
          // Check if user has existing cloud data
          final hasCloudData = await cloudSync.hasCloudData(userId);
          
          if (hasCloudData) {
            // Downloading brings the user's own data TO the device — no
            // privacy question, and it is what a returning user expects.
            debugPrint('Cloud data found, downloading to device');
            await cloudSync.downloadDataFromCloud(userId);
          } else if (CleanStorageService.cloudSyncEnabled) {
            // Uploading is the direction that needs consent. Signing in is not
            // itself consent to sync — a user may sign in only to use cloud
            // BACKUP, or to restore. Without this gate, signing in silently
            // uploaded every local medicine, vitals reading and health record.
            debugPrint('No cloud data found, uploading local data');
            await cloudSync.uploadDataToCloud(userId);
          } else {
            debugPrint('• Upload skipped — cloud sync is off');
          }
          
          debugPrint('Cloud sync completed successfully');
        } catch (syncError) {
          debugPrint('Cloud sync error (non-fatal): $syncError');
          // Don't fail the sign-in if sync fails
        }
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('Google Sign-In: Complete');
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Google Sign In Firebase Error: ${e.code}');
      _isLoading = false;
      notifyListeners();
      return _getErrorMessage(e.code);
    } catch (e) {
      debugPrint('Google Sign In Error (non-Firebase): $e');
      _isLoading = false;
      notifyListeners();
      // ApiException 10 / DEVELOPER_ERROR / sign_in_failed means the build's
      // signing SHA-1 (or OAuth config) isn't registered in the Firebase
      // project — the #1 cause of Android Google Sign-In failing.
      final s = e.toString();
      if (s.contains('ApiException: 10') ||
          s.contains('DEVELOPER_ERROR') ||
          s.contains('sign_in_failed') ||
          s.contains('12500')) {
        debugPrint(
            '⚠️ Google Sign-In config error: register this build\'s SHA-1 '
            'fingerprint on the Firebase Android app, then re-download '
            'google-services.json.');
        return "Google Sign-In isn't set up for this app build yet. "
            'Please try again later or continue as guest.';
      }
      return 'Google Sign In failed.';
    }
  }

  Future<void> signOut() async {
    try {
      if (_firebaseAuth != null) {
        await _firebaseAuth!.signOut();
      }
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
    
    await _clearSavedUser();

    // Signing out also turns cloud sync off. Leaving it on would mean the next
    // sign-in silently resumes uploading, which is not what "sign out" means
    // to a user handing their phone to someone else.
    await CleanStorageService.setCloudSyncEnabled(false);

    // Local health data deliberately STAYS on the device.
    //
    // This is a local-first app, so signing out of the cloud must not destroy
    // records the user may have no other copy of. But "Sign out" reads to most
    // people as "my data is gone", and it is not — so if a PIN exists, re-arm
    // the app lock on the way out. That is the difference between handing
    // someone your phone and handing them your medication history.
    try {
      if (AppLockService().hasPinSet) {
        await CleanStorageService.setAppPreference(
            AppLockService.keyLockEnabled, true);
      }
    } catch (_) {}

    // Deliberately NOT re-signing in anonymously here.
    //
    // This used to call signInAnonymously(), so there was no path in the whole
    // app that reached a state without a Firebase identity — sign out, and you
    // silently got a fresh anonymous account instead. Local-only mode now
    // means local-only. An anonymous identity is created on demand if and when
    // something actually needs one.
    _enableOfflineGuestMode();
  }

  /// Permanently deletes the account: cloud documents, the Firebase Auth
  /// user, and then everything on this device.
  ///
  /// Google Play has required an in-app account-deletion path since 2024, and
  /// there was none — "Delete all data" in Settings wiped local Drift rows
  /// only. It left `users/{uid}` in Firestore, the whole backups subcollection,
  /// and the Auth account itself untouched, so a user who deleted their data
  /// still had a live cloud copy of it.
  ///
  /// Returns `null` on success, or a message to show the user.
  ///
  /// NOTE on completeness: a client cannot reliably delete subcollections —
  /// Firestore has no recursive delete from the SDK. This removes the
  /// documents the app itself writes (including `backups`, which is the one
  /// holding a full health export). A Cloud Function using the Admin SDK's
  /// recursive delete is the correct belt-and-braces follow-up, and is called
  /// out in docs/app-rating.md.
  Future<String?> deleteAccount() async {
    final user = _firebaseAuth?.currentUser;
    if (user == null) {
      // Local-only / guest: there is no cloud account to delete. The caller
      // still wipes local data, which is the whole of "delete" for them.
      return null;
    }

    try {
      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      // Backups first — each document holds a complete health export, so it is
      // the most sensitive thing to leave behind if a later step fails.
      for (final sub in const [
        'backups',
        'medicines',
        'reminders',
        'reminderCategories',
        'water',
        'vitals',
        'diary',
        'cycles',
        'steps',
        'sleep',
      ]) {
        try {
          final docs =
              await db.collection('users').doc(uid).collection(sub).get();
          for (final d in docs.docs) {
            await d.reference.delete();
          }
        } catch (e) {
          debugPrint('Account delete: subcollection $sub failed: $e');
        }
      }
      try {
        await db.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint('Account delete: user doc failed: $e');
      }

      await user.delete();
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Firebase refuses deletion on a stale session. This is correct
        // behaviour, not a bug — surface it so the user can re-authenticate.
        return 'For your security, please sign in again and then delete your '
            'account.';
      }
      return e.message ?? 'Could not delete the account.';
    } catch (e) {
      return 'Could not delete the account: $e';
    }

    await _clearSavedUser();
    await CleanStorageService.setCloudSyncEnabled(false);
    _enableOfflineGuestMode();
    return null;
  }

  /// Send password reset email
  Future<String?> sendPasswordResetEmail(String email) async {
    if (_firebaseAuth == null) {
      return 'Firebase is not initialized.';
    }
    try {
      await _firebaseAuth!.sendPasswordResetEmail(email: email.trim());
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Set password for the current user (enables Email/Password sign-in)
  Future<String?> setPassword(String password) async {
    if (_firebaseAuth?.currentUser == null) {
      return 'No user signed in.';
    }
    try {
      await _firebaseAuth!.currentUser!.updatePassword(password);
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Failed to set password: $e';
    }
  }

  // REMOVED: checkEmailExists / fetchSignInMethodsForEmail.
  //
  // It had zero callers, and it was an account-enumeration oracle: anyone with
  // the (public, extractable-from-any-APK) Firebase API key could test whether
  // an address had an account. For a medication tracker that discloses "this
  // person uses a medication app", which is a health inference.
  //
  // Firebase deprecated the API for exactly this reason. Also switch on
  // Authentication → Settings → **Email Enumeration Protection** in the
  // console — that is an owner action and cannot be done from the codebase.
  // Any future "does this email exist" flow should attempt the sign-in and
  // branch on the generic `invalid-credential` error instead.

  /// Sign up with email and password (restored for smart flow)
  Future<String?> signUpWithEmailPassword(String name, String email, String password) async {
    if (_firebaseAuth == null) {
      return 'Firebase is not initialized.';
    }
    try {
      final nameError = Validators.validateName(name);
      if (nameError != null) return nameError;

      final emailError = Validators.validateEmail(email);
      if (emailError != null) return emailError;

      final passwordError = Validators.validatePassword(password);
      if (passwordError != null) return passwordError;

      _isLoading = true;
      notifyListeners();

      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _getErrorMessage(e.code);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled in Firebase Console. Please contact support.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again to set a password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'provider-already-linked':
        return 'Your account is already linked with Google.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      case 'invalid-verification-id':
        return 'Invalid verification ID.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        debugPrint('Unhandled auth error code: $code');
        return 'Authentication failed. Please try again.';
    }
  }
}
