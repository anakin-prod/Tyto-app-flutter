import 'package:flutter/foundation.dart';

/// Les règles d'Apple ne sont pas celles de Google : sur iOS, l'app ne doit
/// proposer aucun bouton, lien ou message qui renvoie vers un paiement hors
/// de l'App Store (règle 3.1.1), et ne peut pas proposer la connexion Google
/// sans offrir aussi « Se connecter avec Apple » (règle 4.8). Ce petit
/// fichier centralise la question « est-on sur iOS ? ».
class PlatformInfo {
  static bool get estIOS => defaultTargetPlatform == TargetPlatform.iOS;
}
