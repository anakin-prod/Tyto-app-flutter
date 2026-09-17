import 'dart:convert';
import 'package:http/http.dart' as http;

/// Appelle la même route /api/me que le site, pour connaître le vrai
/// statut de l'utilisateur (gratuit / premium / pro) et son quota restant.
class UserProfile {
  final bool premium;
  final bool pro;
  final int? remaining;

  UserProfile({required this.premium, required this.pro, this.remaining});

  factory UserProfile.free() => UserProfile(premium: false, pro: false, remaining: null);
}

class UserService {
  static const _baseUrl = 'https://tytoai.app';

  static Future<UserProfile> fetchMe(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) return UserProfile.free();
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // On lit exactement comme le site : "effectivePlan" est le plan qui
      // s'applique réellement (il tient compte d'un accès Pro via une
      // équipe), alors que "plan" n'est que l'abonnement payé en propre.
      final effectif = (data['effectivePlan'] ?? data['plan'] ?? 'free').toString();
      final pro = data['pro'] == true || effectif == 'pro';
      return UserProfile(
        premium: pro || data['premium'] == true || effectif == 'premium',
        pro: pro,
        remaining: data['remaining'] is int ? data['remaining'] as int : null,
      );
    } catch (e) {
      return UserProfile.free();
    }
  }
}
