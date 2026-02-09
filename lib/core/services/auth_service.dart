
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  static const String _userBoxName = 'user_data';

  Future<void> init() async {
    await Hive.openBox(_userBoxName);
    await _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final box = Hive.box(_userBoxName);
    final userData = box.get('current_user');
    if (userData != null) {
      _currentUser = UserModel.fromJson(Map<String, dynamic>.from(userData));
      notifyListeners();
    }
  }

  Future<void> _saveUser(UserModel user) async {
    final box = Hive.box(_userBoxName);
    await box.put('current_user', user.toJson());
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = UserModel(
        id: googleUser.id,
        name: googleUser.displayName ?? 'User',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
      );

      await _saveUser(_currentUser!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
    
    final box = Hive.box(_userBoxName);
    await box.delete('current_user');
    _currentUser = null;
    notifyListeners();
  }

  // For demo/mock sign in (no backend)
  Future<bool> mockSignIn(String name, String email) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(Duration(milliseconds: 500));

    _currentUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      photoUrl: null,
    );

    await _saveUser(_currentUser!);
    _isLoading = false;
    notifyListeners();
    return true;
  }
}
