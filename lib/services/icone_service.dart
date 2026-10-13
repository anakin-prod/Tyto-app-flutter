import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// L'icône de l'appli au choix, sur iPhone seulement : « nuit » (bleu, celle
/// d'origine) ou « ivoire ». Le changement passe par un petit pont natif
/// (ajouté à la compilation iOS par ios_setup/prepare_ios.py). Si le pont
/// n'existe pas (Android, ou iPhone sans le pont), tout échoue sans bruit.
class IconeService {
  static const _canal = MethodChannel('app.tytoai/icone');
  static const _nomIvoire = 'AppIcon-Ivoire';

  /// Le choix n'est proposé que sur iPhone.
  static bool get disponible => Platform.isIOS;

  /// Le choix actuel : 'nuit' ou 'ivoire'.
  static Future<String> actuelle() async {
    try {
      final nom = await _canal.invokeMethod<String>('actuelle');
      return nom == _nomIvoire ? 'ivoire' : 'nuit';
    } catch (_) {
      return 'nuit';
    }
  }

  /// Change l'icône. Renvoie faux si ça n'a pas marché.
  static Future<bool> definir(String choix) async {
    try {
      await _canal.invokeMethod<void>('definir', choix == 'ivoire' ? _nomIvoire : null);
      return true;
    } catch (_) {
      return false;
    }
  }
}
