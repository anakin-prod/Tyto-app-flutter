import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import 'data_service.dart';
import 'notification_service.dart';

/// Lit et écrit les soins dans Supabase (tables care_cases, care_treatments,
/// care_doses, care_checkins — voir supabase-v8-soins.sql). Les mêmes
/// tables sont lues par le site : ce que tu coches dans l'app apparaît
/// aussitôt sur le site, et inversement.
class SoinsService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Les animaux du compte (pour choisir à qui s'applique un dossier).
  static Future<List<Pet>> animaux() => DataService.loadPets();

  // ---------- Lecture ----------

  static Future<SoinsEtat> charger() async {
    if (_db.auth.currentUser == null) return const SoinsEtat();
    final depuis = cleJour(aujourdhui().subtract(const Duration(days: 60)));

    final dossiersBruts = await _db.from('care_cases').select().order('created_at', ascending: false);
    final traitementsBruts = await _db.from('care_treatments').select().order('created_at', ascending: true);
    final prisesBrutes = await _db.from('care_doses').select().gte('day', depuis);
    final suivisBruts = await _db.from('care_checkins').select().gte('day', depuis).order('day', ascending: false);

    return SoinsEtat(
      dossiers: (dossiersBruts as List).map((r) => SoinDossier.fromRow(r)).toList(),
      traitements: (traitementsBruts as List).map((r) => SoinTraitement.fromRow(r)).toList(),
      prises: (prisesBrutes as List).map((r) => SoinPrise.fromRow(r)).toList(),
      suivis: (suivisBruts as List).map((r) => SoinSuivi.fromRow(r)).toList(),
    );
  }

  // ---------- Dossiers ----------

  /// Ouvre un dossier avec ses traitements. Retourne son identifiant.
  static Future<String?> creerDossier({
    required String petId,
    required String titre,
    String? notes,
    required List<NouveauTraitement> traitements,
    String? nomAnimal,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return null;

    final ligne = await _db
        .from('care_cases')
        .insert({
          'user_id': user.id,
          'pet_id': petId,
          'title': titre.trim(),
          'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
          'started_on': cleJour(aujourdhui()),
          'created_by_email': user.email,
        })
        .select()
        .single();
    final id = ligne['id'].toString();

    for (final t in traitements) {
      await _insererTraitement(user.id, id, petId, t);
    }

    // Une trace dans le carnet de santé : Tyto la relit à chaque question.
    try {
      await DataService.saveEvent(
        petId: petId,
        type: 'observation',
        eventDate: DateTime.now(),
        label: 'Soin ouvert : ${titre.trim()}',
        notes: traitements.isEmpty
            ? 'Suivi quotidien démarré.'
            : traitements.map((t) => t.nom.trim()).join(', '),
      );
    } catch (e) {
      // La trace dans le carnet est un plus : jamais bloquante.
    }
    return id;
  }

  static Future<void> cloturer(SoinDossier dossier, String nomAnimal) async {
    await _db
        .from('care_cases')
        .update({'status': 'closed', 'closed_on': cleJour(aujourdhui())})
        .eq('id', dossier.id);
    try {
      await DataService.saveEvent(
        petId: dossier.petId,
        type: 'observation',
        eventDate: DateTime.now(),
        label: 'Soin terminé : ${dossier.titre}',
        notes: 'Du ${jourLong(dossier.debut)} au ${jourLong(aujourdhui())}.',
      );
    } catch (e) {
      // Idem : jamais bloquant.
    }
  }

  static Future<void> supprimerDossier(String id) async {
    await _db.from('care_cases').delete().eq('id', id);
  }

  // ---------- Traitements ----------

  static Future<void> _insererTraitement(
    String userId,
    String dossierId,
    String petId,
    NouveauTraitement t,
  ) async {
    await _db.from('care_treatments').insert({
      'user_id': userId,
      'case_id': dossierId,
      'pet_id': petId,
      'name': t.nom.trim(),
      'dose': (t.dose?.trim().isEmpty ?? true) ? null : t.dose!.trim(),
      'times': t.heures,
      'every_days': t.tousLesJours,
      'start_date': cleJour(t.debut),
      'end_date': t.fin == null ? null : cleJour(t.fin!),
      'notes': (t.notes?.trim().isEmpty ?? true) ? null : t.notes!.trim(),
    });
  }

  static Future<void> ajouterTraitement(SoinDossier dossier, NouveauTraitement t) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _insererTraitement(user.id, dossier.id, dossier.petId, t);
  }

  static Future<void> modifierTraitement(String id, NouveauTraitement t) async {
    await _db.from('care_treatments').update({
      'name': t.nom.trim(),
      'dose': (t.dose?.trim().isEmpty ?? true) ? null : t.dose!.trim(),
      'times': t.heures,
      'every_days': t.tousLesJours,
      'start_date': cleJour(t.debut),
      'end_date': t.fin == null ? null : cleJour(t.fin!),
      'notes': (t.notes?.trim().isEmpty ?? true) ? null : t.notes!.trim(),
    }).eq('id', id);
  }

  /// « Arrêter » : aujourd'hui devient le dernier jour du traitement.
  static Future<void> arreterTraitement(SoinTraitement t) async {
    // Comme sur le site : on arrête à la veille, les prises passées
    // restent dans l'historique et plus rien n'est prévu aujourd'hui.
    final hier = aujourdhui().subtract(const Duration(days: 1));
    final fin = hier.isBefore(t.debut) ? t.debut : hier;
    await _db.from('care_treatments').update({'end_date': cleJour(fin)}).eq('id', t.id);
  }

  static Future<void> supprimerTraitement(String id) async {
    await _db.from('care_treatments').delete().eq('id', id);
  }

  // ---------- Prises ----------

  static Future<void> pointer(SoinOccurrence o, {bool sautee = false}) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.from('care_doses').upsert({
      'user_id': user.id,
      'treatment_id': o.traitement.id,
      'day': cleJour(o.jour),
      'at_time': o.heure,
      'status': sautee ? 'skipped' : 'done',
      'done_at': DateTime.now().toUtc().toIso8601String(),
      'done_by_email': user.email,
    }, onConflict: 'treatment_id,day,at_time');
  }

  static Future<void> annulerPrise(String priseId) async {
    await _db.from('care_doses').delete().eq('id', priseId);
  }

  // ---------- Suivi du jour ----------

  static Future<void> enregistrerSuivi({
    required String dossierId,
    required String etat,
    String? note,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.from('care_checkins').upsert({
      'user_id': user.id,
      'case_id': dossierId,
      'day': cleJour(aujourdhui()),
      'state': etat,
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
    }, onConflict: 'case_id,day');
  }

  // ---------- Notifications ----------

  /// Les notifications à programmer pour les 7 prochains jours : une à
  /// l'heure de chaque prise pas encore cochée, plus une relance 30
  /// minutes après pour les deux prochains jours.
  static List<RappelSoin> calculerRappels(
    SoinsEtat etat,
    Map<String, String> nomsAnimaux, {
    DateTime? maintenant,
  }) {
    final now = maintenant ?? DateTime.now();
    final base = jourSeul(now);
    final liste = <RappelSoin>[];

    for (var i = 0; i < 7; i++) {
      final jour = base.add(Duration(days: i));
      for (final o in etat.occurrencesLe(jour)) {
        if (o.traitee) continue;
        final m = o.moment;
        if (!m.isAfter(now)) continue;

        final nom = nomsAnimaux[o.traitement.petId];
        final titre = nom != null ? 'Tyto — $nom' : 'Tyto';
        final dose = (o.traitement.dose?.trim().isNotEmpty ?? false) ? ' (${o.traitement.dose!.trim()})' : '';

        liste.add(RappelSoin(
          moment: m,
          titre: titre,
          texte: "C'est l'heure : ${o.traitement.nom}$dose.",
        ));
        if (i <= 1) {
          liste.add(RappelSoin(
            moment: m.add(const Duration(minutes: 30)),
            titre: titre,
            texte: 'Pas encore coché : ${o.traitement.nom}$dose. Ouvre Tyto pour le noter.',
            relance: true,
          ));
        }
      }
    }
    liste.sort((a, b) => a.moment.compareTo(b.moment));
    return liste.take(45).toList();
  }

  /// Reprogramme les notifications à partir de données déjà chargées.
  static Future<void> programmerDepuis(SoinsEtat etat, List<Pet> animaux) async {
    try {
      final noms = {for (final p in animaux) p.id: p.name};
      await NotificationService.reprogrammerSoins(calculerRappels(etat, noms));
    } catch (e) {
      // Une notification manquée ne doit jamais faire planter l'écran.
    }
  }

  /// Recharge tout puis reprogramme : utilisé à l'ouverture de l'app.
  static Future<void> reprogrammerNotifications() async {
    try {
      if (_db.auth.currentUser == null) return;
      final etat = await charger();
      final animaux = await DataService.loadPets();
      await programmerDepuis(etat, animaux);
    } catch (e) {
      // Pas de réseau, tables absentes… : on réessaiera à la prochaine ouverture.
    }
  }

  // ---------- Résumé pour le vétérinaire ----------

  static String resumePourVeto(SoinsEtat etat, SoinDossier d, Pet pet) {
    final maintenant = DateTime.now();
    final b = StringBuffer();
    b.writeln('Suivi de soin — ${pet.name} (${pet.species})');
    b.writeln('Problème : ${d.titre}');
    b.writeln('Ouvert le ${jourLong(d.debut)} (jour ${d.jourNumero}).');
    if (d.notes != null && d.notes!.trim().isNotEmpty) b.writeln('Précisions : ${d.notes!.trim()}');
    b.writeln();

    final trs = etat.traitementsDe(d.id);
    if (trs.isEmpty) {
      b.writeln('Aucun traitement enregistré.');
    } else {
      b.writeln('Traitements :');
      for (final t in trs) {
        final obs = etat.observance(t, maintenant);
        final dose = (t.dose?.trim().isNotEmpty ?? false) ? ' — ${t.dose!.trim()}' : '';
        final periode = t.fin == null
            ? 'depuis le ${jourLong(t.debut)}, jusqu\'à nouvel ordre'
            : 'du ${jourLong(t.debut)} au ${jourLong(t.fin!)}';
        final prises = obs.prevues > 0 ? ' Prises cochées : ${obs.faites} sur ${obs.prevues}.' : '';
        b.writeln('- ${t.nom}$dose — ${t.rythme.toLowerCase()}, $periode.$prises');
      }
    }

    final suivis = etat.suivisDe(d.id).reversed.toList();
    if (suivis.isNotEmpty) {
      b.writeln();
      b.writeln('Évolution jour par jour :');
      for (final s in suivis) {
        final note = (s.note?.trim().isNotEmpty ?? false) ? ' — ${s.note!.trim()}' : '';
        b.writeln('- ${jourCourt(s.jour)} : ${s.libelle.toLowerCase()}$note');
      }
    }
    b.writeln();
    b.writeln('Résumé généré par Tyto. Il ne remplace pas l\'avis d\'un vétérinaire.');
    return b.toString();
  }
}
