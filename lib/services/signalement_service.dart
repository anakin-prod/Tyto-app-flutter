import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'platform_service.dart';

enum ResultatSignalement { envoye, indisponible, echec }

/// « Signaler un problème » : le message part vers le site (route
/// /api/signaler), qui l'envoie par e-mail à l'adresse de contact de Tyto.
class SignalementService {
  static const _baseUrl = 'https://tytoai.app';
  static const adresseContact = 'contact.surnia@gmail.com';

  static Future<ResultatSignalement> envoyer({required String message, required String contact}) async {
    final jeton = AuthService.currentSession?.accessToken;
    if (jeton == null) return ResultatSignalement.indisponible;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/signaler'),
            headers: {'Authorization': 'Bearer $jeton', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'contact': contact,
              'plateforme': PlatformInfo.estIOS ? 'iPhone' : 'Android',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return ResultatSignalement.envoye;
      // 503 : l'envoi d'e-mails n'est pas configuré côté site ; 404 : la
      // route n'est pas encore en ligne. Dans les deux cas, on propose la
      // messagerie de l'appareil.
      if (res.statusCode == 503 || res.statusCode == 404) return ResultatSignalement.indisponible;
      return ResultatSignalement.echec;
    } catch (_) {
      return ResultatSignalement.echec;
    }
  }

  /// Plan B : ouvre la messagerie de l'appareil avec le message prêt à partir.
  static Future<bool> ouvrirMessagerie(String message) {
    final plateforme = PlatformInfo.estIOS ? 'iPhone' : 'Android';
    final uri = Uri(
      scheme: 'mailto',
      path: adresseContact,
      queryParameters: {'subject': 'Signalement Tyto ($plateforme)', 'body': message},
    );
    return launchUrl(uri);
  }
}
