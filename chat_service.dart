import 'dart:convert';
import 'package:http/http.dart' as http;

/// Ce service appelle l'API déjà en place sur tytoai.app — exactement la
/// même que celle utilisée par le site. On ne réécrit aucune logique
/// (quotas, IA, base de données) : tout reste sur le serveur existant.
class ChatService {
  static const _baseUrl = 'https://tytoai.app';

  /// [accessToken] est le jeton de connexion Supabase de l'utilisateur
  /// (obtenu via AuthService). [messages] est l'historique de la
  /// conversation, dans l'ordre, rôle "user" ou "assistant".
  static Future<ChatResult> send({
    required String accessToken,
    required List<Map<String, String>> messages,
    String? petId,
    String? imageBase64,
    String? imageMediaType,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'messages': messages,
          // Tyto adapte sa réponse à l'animal concerné (son espèce, son
          // âge, ses antécédents), comme sur le site.
          if (petId != null) 'petId': petId,
          if (imageBase64 != null)
            'image': {'data': imageBase64, 'media_type': imageMediaType ?? 'image/jpeg'},
        }),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200) {
        return ChatResult.error(data['error'] as String? ?? 'server');
      }

      return ChatResult(
        text: data['text'] as String,
        remaining: data['remaining'] as int?,
        premium: data['premium'] as bool?,
      );
    } catch (e) {
      return ChatResult.error('network');
    }
  }
}

class ChatResult {
  final String? text;
  final int? remaining;
  final bool? premium;
  final String? error;

  ChatResult({this.text, this.remaining, this.premium}) : error = null;
  ChatResult.error(this.error)
      : text = null,
        remaining = null,
        premium = null;

  bool get isError => error != null;
}
