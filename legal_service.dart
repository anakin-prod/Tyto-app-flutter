import 'package:url_launcher/url_launcher.dart';

/// Les pages légales, hébergées sur le site. Google Play exige que la
/// politique de confidentialité soit accessible depuis l'application
/// elle-même, pas seulement depuis la fiche du Play Store.
class LegalService {
  static const _baseUrl = 'https://tytoai.app';

  static Future<bool> _ouvrir(String chemin) {
    return launchUrl(
      Uri.parse('$_baseUrl$chemin'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> confidentialite() => _ouvrir('/confidentialite');
  static Future<bool> conditions() => _ouvrir('/cgu-cgv');
  static Future<bool> mentionsLegales() => _ouvrir('/mentions-legales');
  static Future<bool> support() => _ouvrir('/support');
}
