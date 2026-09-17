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

  /// Connexion par mot de passe — utilisée uniquement par le compte que
  /// Google utilise pour examiner l'application avant publication.
  /// Les examinateurs ne peuvent pas recevoir de lien magique (ils n'ont
  /// pas accès à la boîte mail), il leur faut donc un accès direct.
  /// Ce n'est PAS une porte dérobée : c'est un vrai compte Supabase
  /// ordinaire, avec son propre mot de passe, révocable à tout moment.
  static Future<void> signInWithPassword(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Vrai pendant qu'une connexion Google est en cours (le temps que
  /// l'utilisateur choisisse son compte dans le navigateur et revienne).
  /// Sans ce marqueur, l'app recréerait une session anonyme entre-temps
  /// et annulerait la connexion en train de se faire.
  static bool oauthEnCours = false;

  static Future<void> signInWithGoogle() async {
    oauthEnCours = true;
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectTo,
      );
    } catch (e) {
      oauthEnCours = false;
      rethrow;
    }
    // Filet de sécurité : si l'utilisateur abandonne dans le navigateur,
    // on ne reste pas bloqué en « connexion en cours » indéfiniment.
    Future.delayed(const Duration(minutes: 3), () => oauthEnCours = false);
  }

  static Future<void> signOut() => _client.auth.signOut();

  static Session? get currentSession => _client.auth.currentSession;

  /// Vrai seulement si l'utilisateur a un VRAI compte (email ou Google).
  /// Une session anonyme ne compte pas comme "connecté" : c'est juste la
  /// session technique qui permet de discuter sans créer de compte.
  static bool get isSignedIn {
    final user = _client.auth.currentUser;
    return user != null && user.isAnonymous != true;
  }

  static String? get email => _client.auth.currentUser?.email;

  static Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
