import 'package:flutter/widgets.dart';

/// « Se connecter avec Apple » — iPhone seulement.
///
/// Cette version est VIDE : c'est celle d'Android (et des compilations de
/// test). Pendant la compilation iOS, ios_setup/prepare_ios.py la remplace
/// par ios_setup/apple_ios.dart, qui contient la vraie connexion et ajoute
/// le paquet sign_in_with_apple. Ainsi, les compilations Android
/// n'embarquent rien de tout cela et ne montrent aucun bouton Apple.
class AppleService {
  /// La connexion Apple est-elle utilisable dans cette compilation ?
  static bool get disponible => false;

  /// Le bouton officiel « Continuer avec Apple » (rien ici).
  ///
  /// [surSombre] : bouton blanc pour un fond sombre, noir sinon.
  static Widget bouton({
    required VoidCallback onTap,
    bool surSombre = false,
    double hauteur = 46,
    double rayon = 10,
  }) =>
      const SizedBox.shrink();

  /// Ouvre la fenêtre Apple et connecte l'utilisateur à Supabase.
  /// Renvoie false si l'utilisateur a simplement annulé.
  static Future<bool> seConnecter() async => false;
}
