import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Réutilise la route /api/portal déjà en place sur le site : on ne
/// reconstruit rien côté Stripe, on ouvre juste la même page dans le
/// navigateur du téléphone.
class BillingService {
  static const _baseUrl = 'https://tytoai.app';

  static Future<bool> openPortal(String accessToken) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/portal'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null) return false;
      return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      return false;
    }
  }

  /// La page des offres, pour un compte qui n'est pas encore abonné.
  static Future<bool> openOffers() {
    return launchUrl(Uri.parse('$_baseUrl/tarifs'), mode: LaunchMode.externalApplication);
  }
}
