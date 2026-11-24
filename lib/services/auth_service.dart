import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Current user
  User? get currentUser => _client?.auth.currentUser;

  /// Current user ID (falls back to guest_user if not logged in / offline)
  String get currentUserId => _client?.auth.currentUser?.id ?? 'guest_user';

  /// Auth state changes stream
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  /// Check if user is logged in
  bool get isSignedIn => _client?.auth.currentUser != null;

  /// Sign in with Email and Password
  Future<AuthResponse?> signInWithEmail(String email, String password) async {
    final client = _client;
    if (client == null) return null;
    try {
      return await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('Supabase sign-in error: $e');
      rethrow;
    }
  }

  /// Register with Email and Password
  Future<AuthResponse?> registerWithEmail(String email, String password) async {
    final client = _client;
    if (client == null) return null;
    try {
      return await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('Supabase register error: $e');
      rethrow;
    }
  }

  /// Sign in with Google (OAuth)
  Future<bool> signInWithGoogle() async {
    final client = _client;
    if (client == null) return false;
    try {
      return await client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      debugPrint('Supabase Google OAuth error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('Supabase sign-out error: $e');
    }
  }
}
