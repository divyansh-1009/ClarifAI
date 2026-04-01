import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;
  bool _isLoading = false;

  AuthProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService() {
    _initialize();
  }

  // ── Getters ─────────────────────────────────

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnknown => _status == AuthStatus.unknown;

  // ── Initialization ───────────────────────────

  /// Called once on startup to restore session from local storage.
  Future<void> _initialize() async {
    _setLoading(true);
    try {
      final token = await _apiService.getAccessToken();
      if (token == null) {
        _setUnauthenticated();
        return;
      }

      // Try to fetch the live user profile; fall back to cache.
      try {
        final user = await _apiService.getCurrentUser();
        _setAuthenticated(user);
      } on UnauthorizedException {
        // Access token expired — try to refresh silently.
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          try {
            final user = await _apiService.getCurrentUser();
            _setAuthenticated(user);
            return;
          } catch (_) {}
        }
        // Refresh also failed — restore from cache so UX doesn't break.
        final cached = await _apiService.getCachedUser();
        if (cached != null) {
          _setAuthenticated(cached);
        } else {
          await _apiService.clearTokens();
          _setUnauthenticated();
        }
      } catch (_) {
        // Network unavailable — use cached user if available.
        final cached = await _apiService.getCachedUser();
        if (cached != null) {
          _setAuthenticated(cached);
        } else {
          _setUnauthenticated();
        }
      }
    } catch (e) {
      _setUnauthenticated();
    } finally {
      _setLoading(false);
    }
  }

  // ── Registration ─────────────────────────────

  /// Step 1: Sends an OTP to [email].
  /// Returns `true` on success, sets [error] and returns `false` on failure.
  Future<bool> sendOtp(String email) async {
    _clearError();
    _setLoading(true);
    try {
      await _apiService.sendOtp(email);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Could not connect to server. Check your network.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Step 2: Verifies OTP and registers the user.
  /// Returns `true` on success and transitions to [AuthStatus.authenticated].
  Future<bool> verifyOtpAndRegister({
    required String email,
    required String username,
    required String password,
    required String password2,
    required String otp,
  }) async {
    _clearError();
    _setLoading(true);
    try {
      final response = await _apiService.verifyOtpAndRegister(
        email: email,
        username: username,
        password: password,
        password2: password2,
        otp: otp,
      );
      _setAuthenticated(response.user);
      return true;
    } on ValidationException catch (e) {
      _setError(e.message);
      return false;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Could not connect to server. Check your network.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Login ────────────────────────────────────

  /// Authenticates with [username] + [password].
  /// Returns `true` on success.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _clearError();
    _setLoading(true);
    try {
      final user = await _apiService.login(
        username: username,
        password: password,
      );
      _setAuthenticated(user);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Could not connect to server. Check your network.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ───────────────────────────────────

  /// Logs out the current user and clears all local state.
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _apiService.logout();
    } catch (_) {
      // Always clear local state even if server call fails.
    } finally {
      _user = null;
      _error = null;
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── User refresh ─────────────────────────────

  /// Re-fetches the user profile from the backend and updates local state.
  Future<void> refreshUser() async {
    if (!isAuthenticated) return;
    try {
      final user = await _apiService.getCurrentUser();
      _user = user;
      notifyListeners();
    } catch (_) {
      // Silently ignore — keep stale user data
    }
  }

  // ── Private helpers ──────────────────────────

  void _setAuthenticated(UserModel user) {
    _user = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Clears the current error message (call from UI after displaying it).
  void clearError() => _clearError();
}
