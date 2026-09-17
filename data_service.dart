import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet.dart';
import '../models/health_event.dart';

/// Lit et écrit directement dans les mêmes tables Supabase que le site
/// (pets, health_events). Aucune donnée n'est dupliquée : ce que tu
/// ajoutes dans l'app apparaît sur le site, et inversement.
class DataService {
  static SupabaseClient get _db => Supabase.instance.client;

  // ---------- Animaux ----------

  static Future<List<Pet>> loadPets() async {
    final rows = await _db.from('pets').select().order('created_at', ascending: true);
    return (rows as List).map(_petFromRow).toList();
  }

  static Future<void> savePet({
    String? id,
    required String name,
    required String species,
    String? breed,
    String? sex,
    DateTime? birthdate,
    double? weightKg,
    bool sterilized = false,
    String? allergies,
    String? conditions,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    final payload = {
      'user_id': userId,
      'name': name.trim(),
      'species': species,
      'breed': (breed?.trim().isEmpty ?? true) ? null : breed!.trim(),
      'sex': sex,
      'birthdate': birthdate?.toIso8601String().substring(0, 10),
      'weight_kg': weightKg,
      'sterilized': sterilized,
      'allergies': (allergies?.trim().isEmpty ?? true) ? null : allergies!.trim(),
      'conditions': (conditions?.trim().isEmpty ?? true) ? null : conditions!.trim(),
    };

    if (id != null) {
      await _db.from('pets').update(payload).eq('id', id);
    } else {
      await _db.from('pets').insert(payload);
    }
  }

  static Future<void> deletePet(String id) async {
    await _db.from('pets').delete().eq('id', id);
  }

  // ---------- Carnet de santé ----------

  static Future<List<HealthEvent>> loadEvents(String petId) async {
    final rows = await _db
        .from('health_events')
        .select()
        .eq('pet_id', petId)
        .order('event_date', ascending: false);
    return (rows as List).map(_eventFromRow).toList();
  }

  /// Les rappels à venir, tous animaux confondus (comme le tableau du site).
  static Future<List<HealthEvent>> loadUpcoming() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await _db
        .from('health_events')
        .select()
        .gte('next_due', today)
        .order('next_due', ascending: true);
    return (rows as List).map(_eventFromRow).toList();
  }

  static Future<void> saveEvent({
    required String petId,
    required String type,
    required DateTime eventDate,
    DateTime? nextDue,
    double? valueNum,
    String? notes,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    await _db.from('health_events').insert({
      'user_id': userId,
      'pet_id': petId,
      'type': type,
      'event_date': eventDate.toIso8601String().substring(0, 10),
      'next_due': nextDue?.toIso8601String().substring(0, 10),
      'value_num': valueNum,
      'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
    });

    // Une pesée met aussi à jour le poids du profil, comme sur le site.
    if (type == 'poids' && valueNum != null) {
      await _db.from('pets').update({'weight_kg': valueNum}).eq('id', petId);
    }
  }

  static Future<void> deleteEvent(String id) async {
    await _db.from('health_events').delete().eq('id', id);
  }

  // ---------- Conversion des lignes ----------

  static Pet _petFromRow(dynamic row) {
    return Pet(
      id: row['id'].toString(),
      name: row['name'] as String? ?? '',
      species: row['species'] as String? ?? 'autre',
      breed: row['breed'] as String?,
      sex: row['sex'] as String?,
      birthdate: row['birthdate'] != null ? DateTime.tryParse(row['birthdate'].toString()) : null,
      weightKg: row['weight_kg'] != null ? (row['weight_kg'] as num).toDouble() : null,
      sterilized: row['sterilized'] == true,
      allergies: row['allergies'] as String?,
      conditions: row['conditions'] as String?,
    );
  }

  static HealthEvent _eventFromRow(dynamic row) {
    return HealthEvent(
      id: row['id'].toString(),
      petId: row['pet_id'].toString(),
      type: row['type'] as String? ?? 'autre',
      eventDate: DateTime.tryParse(row['event_date'].toString()) ?? DateTime.now(),
      nextDue: row['next_due'] != null ? DateTime.tryParse(row['next_due'].toString()) : null,
      valueNum: row['value_num'] != null ? (row['value_num'] as num).toDouble() : null,
      notes: row['notes'] as String?,
    );
  }

  // ---------- Historique des conversations ----------
  // Chaque animal (et « général ») a sa propre conversation, sauvegardée
  // au fil de l'eau — comme sur le site — pour ne rien perdre à la
  // fermeture de l'app.

  static Future<void> saveMessage({
    required String threadKey,
    required String role,
    required String content,
    bool hasImage = false,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _db.from('messages').insert({
        'user_id': userId,
        'thread_key': threadKey,
        'role': role,
        'content': content,
        'has_image': hasImage,
      });
    } catch (e) {
      // Une sauvegarde ratée ne doit jamais bloquer la conversation.
    }
  }

  /// Les 200 derniers messages, tous fils confondus — comme sur le site.
  static Future<Map<String, List<Map<String, dynamic>>>> loadConversations() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final rows = await _db
          .from('messages')
          .select('thread_key, role, content, has_image, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(200);

      final groupes = <String, List<Map<String, dynamic>>>{};
      for (final row in (rows as List).reversed) {
        final cle = row['thread_key'] as String;
        (groupes[cle] ??= []).add({
          'role': row['role'],
          'content': row['content'],
          'hasImage': row['has_image'] == true,
          'date': DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
        });
      }
      return groupes;
    } catch (e) {
      return {};
    }
  }

  /// Efface une conversation entière — utilisé pour « Effacer cet
  /// historique » depuis le panneau.
  static Future<void> deleteConversation(String threadKey) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _db.from('messages').delete().eq('thread_key', threadKey).eq('user_id', userId);
    } catch (e) {
      // Silencieux : au pire, l'historique réapparaîtra au prochain chargement.
    }
  }
}
