import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, guest }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get canChangePassword => _authService.canChangePasswordWithCurrentAccount;
  bool get isGoogleAccount => _authService.isGoogleAccount;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      if (_status == AuthStatus.guest) return;
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
      } else {
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.loginWithEmail(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan. Coba lagi.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount({String? currentPassword}) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteAccount(currentPassword: currentPassword);
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan. Coba lagi.';
      notifyListeners();
      return false;
    }
  }

  void continueAsGuest() {
    _status = AuthStatus.guest;
    _user = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak ditemukan.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password lama salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password minimal 6 karakter.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'requires-recent-login':
        return 'Silakan login ulang lalu coba lagi.';
      case 'no-current-user':
        return 'User tidak sedang login.';
      case 'missing-email':
        return 'Akun ini tidak mendukung operasi ini.';
      case 'password-change-not-supported':
        return 'Akun Google tidak bisa mengganti password dari aplikasi ini.';
      case 'missing-password':
        return 'Password wajib diisi.';
      case 'google-reauth-cancelled':
        return 'Verifikasi Google dibatalkan.';
      case 'google-email-mismatch':
        return 'Email verifikasi tidak sesuai. Pilih akun Google yang terdaftar di aplikasi.';
      case 'delete-account-not-supported':
        return 'Jenis akun ini belum didukung untuk hapus akun.';
      default:
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }
}