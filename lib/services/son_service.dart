import 'package:flutter/services.dart';
import 'reglages_service.dart';

/// Le petit « hou » de la chouette joué à l'envoi d'un message. La lecture est
/// faite par un petit code natif (Android : SoundPool ; iPhone : AudioServices),
/// qui ne coupe pas la musique en cours et se tait quand le téléphone est en
/// mode silencieux. Si le code natif est absent, tout échoue sans bruit.
class SonService {
  static const _canal = MethodChannel('app.tytoai/son');

  /// À l'envoi d'un message, si ce n'est pas désactivé dans Paramètres.
  static Future<void> jouerEnvoi() async {
    if (!Reglages.sonMessage) return;
    await essayer();
  }

  /// Joue le son tout de suite (utilisé aussi quand on active le réglage).
  static Future<void> essayer() async {
    try {
      await _canal.invokeMethod<void>('jouer', {
        'nom': Reglages.fichierSonMessage,
        'volume': 0.7,
      });
    } catch (_) {}
  }
}
