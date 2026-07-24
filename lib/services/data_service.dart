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
}
