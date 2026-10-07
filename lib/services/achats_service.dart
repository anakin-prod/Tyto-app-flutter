import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Les achats intégrés Apple (RevenueCat) — iOS seulement.
///
/// Cette version est VIDE : c'est celle d'Android, où l'abonnement se fait
/// sur le site. Pendant la compilation iOS, ios_setup/prepare_ios.py la
/// remplace par ios_setup/achats_ios.dart, qui contient les vrais achats.
/// Ainsi, les compilations Android n'embarquent ni RevenueCat ni la
/// bibliothèque de facturation de Google Play.
class AchatsService {
  /// Monte à chaque achat réussi : l'écran principal l'écoute pour
  /// rafraîchir le statut Premium/Pro.
  static final ValueNotifier<int> achatReussi = ValueNotifier<int>(0);

  /// Les achats intégrés sont-ils utilisables dans cette compilation ?
  static bool get disponible => false;

  static Future<void> demarrer() async {}

  static Future<void> connecter(String userId) async {}

  static Future<void> deconnecter() async {}

  /// Ouvre l'écran d'abonnement. Renvoie true si un achat a abouti.
  static Future<bool> ouvrirOffres(BuildContext context) async => false;

  /// Ouvre la gestion de l'abonnement dans les réglages Apple.
  static Future<void> gererAbonnement() async {}
}
