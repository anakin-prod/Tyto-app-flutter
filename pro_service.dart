import 'dart:convert';
import 'package:http/http.dart' as http;

/// Les fonctions réservées au plan Pro. Elles appellent les mêmes routes
/// que le site — aucune logique n'est réécrite ici.
class ProService {
  static const _baseUrl = 'https://tytoai.app';

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ---------- Lecture d'une ordonnance photographiée ----------

  static Future<PrescriptionResult> readPrescription({
    required String accessToken,
    required String base64Image,
    required String mediaType,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/prescription'),
        headers: _headers(accessToken),
        body: jsonEncode({'image': base64Image, 'mediaType': mediaType}),
      );
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        return PrescriptionResult.error(
          d['error'] == 'image_too_large'
              ? "Cette photo est trop lourde — réessaie avec une photo un peu moins grande."
              : "La lecture de l'ordonnance a échoué. Réessaie avec une photo plus nette.",
        );
      }
      final lignes = (d['lines'] as List? ?? [])
          .map((l) => PrescriptionLine.fromJson(l as Map<String, dynamic>, d['readable'] == true))
          .toList();
      return PrescriptionResult(lines: lignes, readable: d['readable'] == true);
    } catch (e) {
      return PrescriptionResult.error(
          "La lecture de l'ordonnance a échoué. Réessaie dans un instant.");
    }
  }

  // ---------- Synthèse pour le vétérinaire ----------

  static Future<VetReport?> vetReport({
    required String accessToken,
    required String petId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/vet-report'),
        headers: _headers(accessToken),
        body: jsonEncode({'petId': petId}),
      );
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      final report = d['report'] as Map<String, dynamic>?;
      if (report == null) return null;
      return VetReport(
        content: report['content'] as String? ?? '',
        petName: d['petName'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  // ---------- Équipe ----------

  static Future<TeamData?> loadTeam(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/team'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) return null;
      return TeamData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  static Future<InviteResult> invite({
    required String accessToken,
    required String email,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/team'),
        headers: _headers(accessToken),
        body: jsonEncode({'email': email}),
      );
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        return InviteResult(ok: false, message: _messageErreurInvite(d['error'] as String?));
      }
      return InviteResult(
        ok: true,
        message: d['emailSent'] == true
            ? "Invitation envoyée à $email"
            : "Invitation créée, mais l'email n'a pas pu être envoyé automatiquement.",
        inviteUrl: d['inviteUrl'] as String?,
      );
    } catch (e) {
      return InviteResult(ok: false, message: "L'invitation n'a pas abouti. Réessaie.");
    }
  }

  static Future<bool> removeMember({
    required String accessToken,
    required String memberId,
  }) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/api/team?id=$memberId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static String _messageErreurInvite(String? code) {
    switch (code) {
      case 'already_member':
        return 'Cette personne fait déjà partie de ton équipe.';
      case 'self':
        return "Tu ne peux pas t'inviter toi-même.";
      case 'not_pro':
        return "Les équipes sont réservées au plan Pro.";
      default:
        return "L'invitation n'a pas abouti. Réessaie.";
    }
  }
}

// ---------- Les données renvoyées ----------

class PrescriptionLine {
  final String medication;
  final String? dose;
  final int? timesPerDay;
  final int? durationDays;
  final String? notes;
  bool checked;

  PrescriptionLine({
    required this.medication,
    this.dose,
    this.timesPerDay,
    this.durationDays,
    this.notes,
    this.checked = false,
  });

  factory PrescriptionLine.fromJson(Map<String, dynamic> j, bool readable) {
    return PrescriptionLine(
      medication: j['medication'] as String? ?? '',
      dose: j['dose'] as String?,
      timesPerDay: j['times_per_day'] is int ? j['times_per_day'] as int : null,
      durationDays: j['duration_days'] is int ? j['duration_days'] as int : null,
      notes: j['notes'] as String?,
      // Pré-coché seulement si la lecture globale est jugée fiable.
      checked: readable,
    );
  }
}

class PrescriptionResult {
  final List<PrescriptionLine> lines;
  final bool readable;
  final String? error;

  PrescriptionResult({required this.lines, required this.readable}) : error = null;
  PrescriptionResult.error(this.error)
      : lines = const [],
        readable = false;

  bool get isError => error != null;
}

class VetReport {
  final String content;
  final String? petName;
  VetReport({required this.content, this.petName});
}

class TeamMember {
  final String id;
  final String email;
  final String status; // invited | active
  TeamMember({required this.id, required this.email, required this.status});

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        id: j['id']?.toString() ?? '',
        email: j['email'] as String? ?? '',
        status: j['status'] as String? ?? 'invited',
      );
}

class TeamData {
  final List<TeamMember> members;
  final int seatsIncluded;
  final int seatsExtra;
  final int extraPriceEur;

  TeamData({
    required this.members,
    required this.seatsIncluded,
    required this.seatsExtra,
    required this.extraPriceEur,
  });

  factory TeamData.fromJson(Map<String, dynamic> j) {
    final seats = j['seats'] as Map<String, dynamic>? ?? {};
    return TeamData(
      members: (j['members'] as List? ?? [])
          .map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      seatsIncluded: seats['included'] is int ? seats['included'] as int : 0,
      seatsExtra: seats['extra'] is int ? seats['extra'] as int : 0,
      extraPriceEur: seats['extraPriceEur'] is int ? seats['extraPriceEur'] as int : 0,
    );
  }
}

class InviteResult {
  final bool ok;
  final String message;
  final String? inviteUrl;
  InviteResult({required this.ok, required this.message, this.inviteUrl});
}
