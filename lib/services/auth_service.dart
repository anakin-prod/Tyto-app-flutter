import 'package:supabase_flutter/supabase_flutter.dart';

/// Reproduit exactement le système de connexion du site : jamais de mot
/// de passe. Soit un lien magique envoyé par email, soit un bouton Google.
class AuthService {
  static const _redirectTo = 'app.tytoai.twa://login-callback';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: _redirectTo,
    );
  }

  static Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectTo,
    );
  }

  static Future<void> signOut() => _client.auth.signOut();

  static Session? get currentSession => _client.auth.currentSession;

  static Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
