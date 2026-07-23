import 'package:supabase_flutter/supabase_flutter.dart';

/// Reproduit exactement le système de connexion du site : jamais de mot
/// de passe. Soit un lien magique envoyé par email, soit un bouton Google.
class AuthService {
  static const _redirectTo = 'app.tytoai.twa://login-callback';

  static SupabaseClient get _client => Supabase.instance.client;

  /// Envoie un lien de connexion à l'adresse email donnée.
  /// L'utilisateur clique dessus, revient dans l'app, et se retrouve connecté.
  static Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: _redirectTo,
    );
  }

  /// Ouvre l'écran de connexion Google natif du téléphone.
  static Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectTo,
    );
  }

  static Future<void> signOut() => _client.auth.signOut();

  static Session? get currentSession => _client.auth.currentSession;

  /// Le flux qui prévient l'app à chaque changement (connecté / déconnecté).
  static Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
