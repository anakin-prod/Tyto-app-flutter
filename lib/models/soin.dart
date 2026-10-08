// ============================================================
// « Soins en cours » : un dossier par problème (ex. Conjonctivite),
// avec ses traitements à heures fixes, ses prises cochées « fait »
// et son suivi quotidien (mieux / pareil / moins bien).
//
// Toutes les dates sont des jours « purs », sans heure, en UTC : un
// changement d'heure (été / hiver) ne peut ainsi jamais décaler un
// jour de traitement.
// ============================================================

DateTime jourSeul(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime aujourdhui() => jourSeul(DateTime.now());

String cleJour(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? lireJour(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  if (d == null) return null;
  return jourSeul(d);
}

String jourCourt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String jourLong(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// « 08:00 », « 08:00 et 20:00 », « 08:00, 14:00 et 21:00 ».
String listerHeures(List<String> heures) {
  if (heures.isEmpty) return '';
  if (heures.length == 1) return heures.first;
  final debut = heures.sublist(0, heures.length - 1).join(', ');
  return '$debut et ${heures.last}';
}

/// « Tous les jours à 21:00 », « Un jour sur 2 à 08:00 et 20:00 »…
String rythmeTexte(int pas, List<String> heures) {
  final freq = pas == 1
      ? 'Tous les jours'
      : pas == 2
          ? 'Un jour sur 2'
          : pas == 7
              ? 'Chaque semaine'
              : 'Tous les $pas jours';
  return heures.isEmpty ? freq : '$freq à ${listerHeures(heures)}';
}

/// « Du 03/10 au 10/10/2026 » ou « Depuis le 03/10/2026, sans fin ».
String periodeTexte(DateTime debut, DateTime? fin) {
  if (fin == null) return 'Depuis le ${jourLong(debut)}, jusqu\'à nouvel ordre';
  return 'Du ${jourCourt(debut)} au ${jourLong(fin)}';
}

// ---------- Le dossier ----------

class SoinDossier {
  final String id;
  final String petId;
  final String titre;
  final String? notes;
  final DateTime debut;
  final bool clos;
  final DateTime? cloture;

  const SoinDossier({
    required this.id,
    required this.petId,
    required this.titre,
    this.notes,
    required this.debut,
    this.clos = false,
    this.cloture,
  });

  factory SoinDossier.fromRow(dynamic r) {
    return SoinDossier(
      id: r['id'].toString(),
      petId: r['pet_id'].toString(),
      titre: (r['title'] ?? '').toString(),
      notes: r['notes'] as String?,
      debut: lireJour(r['started_on']) ?? aujourdhui(),
      clos: r['status'] == 'closed',
      cloture: lireJour(r['closed_on']),
    );
  }

  /// « Jour 1 » le jour de l'ouverture du dossier.
  int get jourNumero {
    final n = aujourdhui().difference(debut).inDays + 1;
    return n < 1 ? 1 : n;
  }
}

// ---------- Un traitement ----------

class SoinTraitement {
  final String id;
  final String dossierId;
  final String petId;
  final String nom;
  final String? dose;
  final List<String> heures; // « 21:00 », triées
  final int tousLesJours; // 1 = chaque jour, 2 = un jour sur deux, 7 = chaque semaine
  final DateTime debut;
  final DateTime? fin; // dernier jour ; null = jusqu'à nouvel ordre
  final String? notes;

  const SoinTraitement({
    required this.id,
    required this.dossierId,
    required this.petId,
    required this.nom,
    this.dose,
    required this.heures,
    this.tousLesJours = 1,
    required this.debut,
    this.fin,
    this.notes,
  });

  factory SoinTraitement.fromRow(dynamic r) {
    final brut = r['times'];
    final heures = <String>[];
    if (brut is List) {
      for (final h in brut) {
        final s = h.toString();
        // La base peut renvoyer « 21:00:00 » : on garde « 21:00 ».
        heures.add(s.length >= 5 ? s.substring(0, 5) : s);
      }
    }
    heures.sort();
    final pas = r['every_days'] is int ? r['every_days'] as int : 1;
    return SoinTraitement(
      id: r['id'].toString(),
      dossierId: r['case_id'].toString(),
      petId: r['pet_id'].toString(),
      nom: (r['name'] ?? '').toString(),
      dose: r['dose'] as String?,
      heures: heures,
      tousLesJours: pas < 1 ? 1 : pas,
      debut: lireJour(r['start_date']) ?? aujourdhui(),
      fin: lireJour(r['end_date']),
      notes: r['notes'] as String?,
    );
  }

  /// Une prise est-elle prévue ce jour-là ?
  bool estPrevuLe(DateTime jour) {
    final j = jourSeul(jour);
    if (j.isBefore(debut)) return false;
    if (fin != null && j.isAfter(fin!)) return false;
    return j.difference(debut).inDays % tousLesJours == 0;
  }

  bool get termine => fin != null && aujourdhui().isAfter(fin!);

  bool get pasCommence => debut.isAfter(aujourdhui());

  int get joursTotal => fin == null ? 0 : fin!.difference(debut).inDays + 1;

  /// Le jour où l'on en est (1 = premier jour), borné au traitement.
  int get jourCourant {
    final n = aujourdhui().difference(debut).inDays + 1;
    if (n < 0) return 0;
    if (fin != null && n > joursTotal) return joursTotal;
    return n;
  }

  String get rythme => rythmeTexte(tousLesJours, heures);

  NouveauTraitement versNouveau() => NouveauTraitement(
        nom: nom,
        dose: dose,
        heures: List<String>.from(heures),
        tousLesJours: tousLesJours,
        debut: debut,
        fin: fin,
        notes: notes,
      );
}

/// Ce que l'on saisit dans le formulaire, avant l'enregistrement.
class NouveauTraitement {
  final String nom;
  final String? dose;
  final List<String> heures;
  final int tousLesJours;
  final DateTime debut;
  final DateTime? fin;
  final String? notes;

  const NouveauTraitement({
    required this.nom,
    this.dose,
    required this.heures,
    this.tousLesJours = 1,
    required this.debut,
    this.fin,
    this.notes,
  });
}

// ---------- Une prise cochée ----------

class SoinPrise {
  final String id;
  final String traitementId;
  final DateTime jour;
  final String heure;
  final bool sautee;
  final DateTime? faiteLe;

  const SoinPrise({
    required this.id,
    required this.traitementId,
    required this.jour,
    required this.heure,
    this.sautee = false,
    this.faiteLe,
  });

  factory SoinPrise.fromRow(dynamic r) {
    final h = (r['at_time'] ?? '').toString();
    return SoinPrise(
      id: r['id'].toString(),
      traitementId: r['treatment_id'].toString(),
      jour: lireJour(r['day']) ?? aujourdhui(),
      heure: h.length >= 5 ? h.substring(0, 5) : h,
      sautee: r['status'] == 'skipped',
      faiteLe: r['done_at'] != null ? DateTime.tryParse(r['done_at'].toString())?.toLocal() : null,
    );
  }
}

// ---------- Le suivi du jour ----------

class SoinSuivi {
  final String id;
  final String dossierId;
  final DateTime jour;
  final String etat; // 'better' | 'same' | 'worse'
  final String? note;

  const SoinSuivi({
    required this.id,
    required this.dossierId,
    required this.jour,
    required this.etat,
    this.note,
  });

  factory SoinSuivi.fromRow(dynamic r) {
    return SoinSuivi(
      id: r['id'].toString(),
      dossierId: r['case_id'].toString(),
      jour: lireJour(r['day']) ?? aujourdhui(),
      etat: (r['state'] ?? 'same').toString(),
      note: r['note'] as String?,
    );
  }

  String get libelle {
    switch (etat) {
      case 'better':
        return 'Mieux';
      case 'worse':
        return 'Moins bien';
      default:
        return 'Pareil';
    }
  }
}

// ---------- Une prise à faire (ou faite) à une heure précise ----------

class SoinOccurrence {
  final SoinTraitement traitement;
  final DateTime jour;
  final String heure;
  final SoinPrise? prise;

  const SoinOccurrence({
    required this.traitement,
    required this.jour,
    required this.heure,
    this.prise,
  });

  /// L'instant exact de la prise, à l'heure locale du téléphone.
  DateTime get moment {
    final morceaux = heure.split(':');
    final h = int.tryParse(morceaux.first) ?? 0;
    final m = morceaux.length > 1 ? (int.tryParse(morceaux[1]) ?? 0) : 0;
    return DateTime(jour.year, jour.month, jour.day, h, m);
  }

  bool get traitee => prise != null;
  bool get faite => prise != null && !prise!.sautee;
  bool get sautee => prise != null && prise!.sautee;

  bool enRetard(DateTime maintenant) => prise == null && moment.isBefore(maintenant);
}

class Observance {
  final int faites;
  final int prevues;
  const Observance(this.faites, this.prevues);
}

class SoinAlerte {
  final String texte;
  final bool grave;
  const SoinAlerte(this.texte, this.grave);
}

// ---------- Tout ce qui est chargé ----------

class SoinsEtat {
  final List<SoinDossier> dossiers;
  final List<SoinTraitement> traitements;
  final List<SoinPrise> prises;
  final List<SoinSuivi> suivis; // du plus récent au plus ancien

  const SoinsEtat({
    this.dossiers = const [],
    this.traitements = const [],
    this.prises = const [],
    this.suivis = const [],
  });

  List<SoinDossier> get actifs => dossiers.where((d) => !d.clos).toList();

  List<SoinDossier> get clos => dossiers.where((d) => d.clos).toList();

  SoinDossier? dossier(String id) {
    for (final d in dossiers) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<SoinTraitement> traitementsDe(String dossierId) =>
      traitements.where((t) => t.dossierId == dossierId).toList();

  SoinPrise? prise(String traitementId, DateTime jour, String heure) {
    final j = jourSeul(jour);
    for (final p in prises) {
      if (p.traitementId == traitementId && p.heure == heure && p.jour == j) return p;
    }
    return null;
  }

  /// Toutes les prises d'un jour, dans l'ordre des heures. Par défaut, seuls
  /// les dossiers encore ouverts comptent.
  List<SoinOccurrence> occurrencesLe(DateTime jour, {String? dossierId, bool seulementActifs = true}) {
    final j = jourSeul(jour);
    final liste = <SoinOccurrence>[];
    for (final t in traitements) {
      if (dossierId != null && t.dossierId != dossierId) continue;
      if (seulementActifs) {
        final d = dossier(t.dossierId);
        if (d == null || d.clos) continue;
      }
      if (!t.estPrevuLe(j)) continue;
      for (final h in t.heures) {
        liste.add(SoinOccurrence(traitement: t, jour: j, heure: h, prise: prise(t.id, j, h)));
      }
    }
    liste.sort((a, b) {
      final c = a.heure.compareTo(b.heure);
      return c != 0 ? c : a.traitement.nom.compareTo(b.traitement.nom);
    });
    return liste;
  }

  /// La prochaine prise pas encore cochée d'un dossier (dans les 14 jours).
  SoinOccurrence? prochainePrise(String dossierId, DateTime maintenant) {
    final base = jourSeul(maintenant);
    for (var i = 0; i < 14; i++) {
      final jour = base.add(Duration(days: i));
      for (final o in occurrencesLe(jour, dossierId: dossierId)) {
        if (o.traitee) continue;
        if (o.moment.isAfter(maintenant)) return o;
      }
    }
    return null;
  }

  /// Les prises cochées sur les prises prévues, de 60 jours en arrière
  /// (ou du début du traitement) jusqu'à maintenant.
  Observance observance(SoinTraitement t, DateTime maintenant) {
    final aujourd = jourSeul(maintenant);
    var depart = t.debut;
    final limite = aujourd.subtract(const Duration(days: 60));
    if (depart.isBefore(limite)) depart = limite;
    var prevues = 0;
    var faites = 0;
    var jour = depart;
    while (!jour.isAfter(aujourd)) {
      if (t.estPrevuLe(jour)) {
        for (final h in t.heures) {
          final p = prise(t.id, jour, h);
          final passee = jour.isBefore(aujourd) ||
              DateTime(jour.year, jour.month, jour.day, int.tryParse(h.split(':').first) ?? 0,
                      int.tryParse(h.split(':').last) ?? 0)
                  .isBefore(maintenant);
          if (p != null && !p.sautee) {
            prevues++;
            faites++;
          } else if (passee) {
            prevues++;
          }
        }
      }
      jour = jour.add(const Duration(days: 1));
    }
    return Observance(faites, prevues);
  }

  List<SoinSuivi> suivisDe(String dossierId) {
    final liste = suivis.where((s) => s.dossierId == dossierId).toList();
    liste.sort((a, b) => b.jour.compareTo(a.jour));
    return liste;
  }

  SoinSuivi? suiviLe(String dossierId, DateTime jour) {
    final j = jourSeul(jour);
    for (final s in suivis) {
      if (s.dossierId == dossierId && s.jour == j) return s;
    }
    return null;
  }

  /// Un message prudent quand l'évolution inquiète. Jamais de diagnostic :
  /// on invite simplement à parler au vétérinaire.
  SoinAlerte? alerte(SoinDossier d, String nomAnimal) {
    if (d.clos) return null;
    final liste = suivisDe(d.id);
    final aujourd = aujourdhui();

    if (liste.length >= 2) {
      final a = liste[0];
      final b = liste[1];
      final consecutifs = a.jour.difference(b.jour).inDays == 1;
      final recent = aujourd.difference(a.jour).inDays <= 1;
      if (a.etat == 'worse' && b.etat == 'worse' && consecutifs && recent) {
        return SoinAlerte(
          '$nomAnimal va moins bien depuis deux jours de suite. Contacte ton vétérinaire sans attendre.',
          true,
        );
      }
    }
    if (liste.isNotEmpty && liste.first.etat == 'worse' && aujourd.difference(liste.first.jour).inDays <= 1) {
      return SoinAlerte(
        "$nomAnimal va moins bien. Si ça continue ou si ça s'aggrave, appelle ton vétérinaire.",
        true,
      );
    }
    if (d.jourNumero >= 4 && liste.length >= 3) {
      final troisDerniers = liste.take(3).toList();
      final aucunMieux = troisDerniers.every((s) => s.etat != 'better');
      final recent = aujourd.difference(troisDerniers.first.jour).inDays <= 1;
      if (aucunMieux && recent) {
        return SoinAlerte(
          "Pas d'amélioration depuis plusieurs jours. Mieux vaut en parler à ton vétérinaire.",
          false,
        );
      }
    }
    final trs = traitementsDe(d.id);
    if (trs.isNotEmpty && trs.every((t) => t.termine)) {
      return SoinAlerte(
        'Les traitements sont terminés. Comment va $nomAnimal ? Clôture le dossier si tout est réglé, sinon contacte ton vétérinaire.',
        false,
      );
    }
    return null;
  }
}
