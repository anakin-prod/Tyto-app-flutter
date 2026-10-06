import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// La suppression de compte, exigée par Apple (règle 5.1.1(v)) et Google
/// Play pour toute app qui permet de créer un compte. Le serveur annule
/// l'abonnement puis efface toutes les données ; si l'annulation de
/// l'abonnement échoue, rien n'est supprimé et on peut réessayer.
class AccountService {
  static const _baseUrl = 'https://tytoai.app';

  /// Renvoie true si le compte a bien été supprimé.
  static Future<bool> supprimerCompte() async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/delete-account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'confirm': true}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || data['ok'] != true) return false;

      // Le compte n'existe plus côté serveur : on ferme la session locale.
      // Une erreur ici n'est pas grave, la suppression a bien eu lieu.
      try {
        await AuthService.signOut();
      } catch (_) {}
      return true;
    } catch (e) {
      return false;
    }
  }
}
