import 'package:flutter/foundation.dart';

/// A stand-in for real auth, used as the router's `refreshListenable`.
///
/// Notifying listeners makes go_router re-run every redirect, which is how
/// logging in or out immediately moves the user off a guarded route.
class AuthService extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _role = 'guest';

  /// Whether a user is signed in.
  bool get isLoggedIn => _isLoggedIn;

  /// The signed-in user's role, matched against a route's
  /// `metadata: {'requiresRole': …}`.
  String get role => _role;

  /// Signs in with [role].
  void login({String role = 'user'}) {
    _isLoggedIn = true;
    _role = role;
    notifyListeners();
  }

  /// Signs out.
  void logout() {
    _isLoggedIn = false;
    _role = 'guest';
    notifyListeners();
  }
}

/// The app-wide auth service.
///
/// Declared here rather than in `main.dart` so `app_router.dart` can reach it
/// without importing the entry point — the generated part file lives in
/// `app_router.dart`, and every guard it names has to be visible from there.
final authService = AuthService();
