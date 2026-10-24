// ============================================================
// « SE CONNECTER AVEC APPLE » — version iOS.
//
// Ce fichier est copié sur lib/services/apple_service.dart pendant la
// compilation iOS (voir ios_setup/prepare_ios.py), en même temps que
// l'ajout des paquets sign_in_with_apple et crypto. Il n'existe pas dans
// les compilations Android, qui gardent la version vide.
//
// Comment ça marche (connexion « native », sans page web) :
//   1. on fabrique un nombre au hasard (le « nonce ») et on en donne
//      l'empreinte SHA-256 à Apple ;
//   2. l'utilisateur valide avec Face ID dans la fenêtre d'Apple ;
//   3. Apple renvoie un jeton signé qui contient cette empreinte ;
//   4. on donne ce jeton ET le nombre d'origine à Supabase, qui vérifie
//      auprès d'Apple que tout concorde, puis ouvre la session.
//
// Réglages indispensables (voir le guide) : « Sign in with Apple » activé
// sur l'identifiant app.tytoai.tyto chez Apple, et app.tytoai.tyto déclaré
// dans Supabase > Authentication > Sign In / Providers > Apple.
// ============================================================

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppleService {
  /// Cette compilation sait se connecter avec Apple.
  static bool get disponible => true;

  /// Le bouton officiel d'Apple (logo et proportions imposés par Apple).
  ///
  /// [surSombre] : bouton blanc pour un fond sombre, noir sinon.
  static Widget bouton({
    required VoidCallback onTap,
    bool surSombre = false,
    double hauteur = 46,
    double rayon = 10,
  }) {
    return SignInWithAppleButton(
      onPressed: onTap,
      text: 'Continuer avec Apple',
      height: hauteur,
      style: surSombre ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
      borderRadius: BorderRadius.all(Radius.circular(rayon)),
    );
  }

  /// Un nombre au hasard, imprévisible, de 32 octets.
  static String _nonceAleatoire() {
    final hasard = Random.secure();
    final octets = List<int>.generate(32, (_) => hasard.nextInt(256));
    return base64UrlEncode(octets).replaceAll('=', '');
  }

  /// Ouvre la fenêtre Apple et connecte l'utilisateur à Supabase.
  /// Renvoie false si l'utilisateur a simplement annulé la fenêtre ;
  /// toute autre erreur est transmise à l'écran, qui l'affiche.
  static Future<bool> seConnecter() async {
    final nonce = _nonceAleatoire();
    final empreinte = sha256.convert(utf8.encode(nonce)).toString();

    final AuthorizationCredentialAppleID identifiants;
    try {
      identifiants = await SignInWithApple.getAppleIDCredential(
        // L'e-mail suffit : Tyto n'a pas besoin du nom.
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: empreinte,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }

    final jeton = identifiants.identityToken;
    if (jeton == null) {
      throw const AuthException("Apple n'a pas renvoyé de jeton de connexion.");
    }

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: jeton,
      nonce: nonce,
    );
    return true;
  }
}
