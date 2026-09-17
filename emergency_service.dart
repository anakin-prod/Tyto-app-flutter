import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Appelle la même route /api/emergency que le site, et ouvre la même
/// recherche de vétérinaire de garde.
class EmergencyService {
  static const _baseUrl = 'https://tytoai.app';

  static Future<EmergencyResult> analyse({
    required String accessToken,
    required String description,
    String? petId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/emergency'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'description': description, 'petId': petId}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || data['text'] == null) {
        return EmergencyResult.error(data['error'] as String? ?? 'server');
      }
      return EmergencyResult(
        text: data['text'] as String,
        gravity: data['gravity'] as String? ?? 'SURVEILLER',
      );
    } catch (e) {
      return EmergencyResult.error('network');
    }
  }

  /// La même recherche que sur le site : un vétérinaire de garde ouvert
  /// maintenant, près de la position de l'utilisateur.
  static Future<bool> findVet() {
    return launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/v%C3%A9t%C3%A9rinaire+urgence+de+garde+ouvert+maintenant',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

class EmergencyResult {
  final String? text;
  final String? gravity; // VITAL | URGENT | SURVEILLER
  final String? error;

  EmergencyResult({this.text, this.gravity}) : error = null;
  EmergencyResult.error(this.error)
      : text = null,
        gravity = null;

  bool get isError => error != null;
}
