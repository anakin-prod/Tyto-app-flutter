import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'fenetre_papier.dart';
import 'tyto_icons.dart';

// ============================================================
// Les briques des écrans « Soins en cours », reprises telles quelles
// de components/SoinsPanel.js du site : carte papier (carte), pastilles
// (Pastille), étiquettes (etiquette), champs (champ), bouton doré
// (boutonOr), bouton discret (boutonDiscret), ligne d'une prise du jour,
// encadré d'alerte, et les textes de dates / heures du site.
// ============================================================

/// Demande « En parler à Tyto » : l'identifiant de l'animal dont on veut
/// ouvrir la conversation. Le chat peut l'écouter pour choisir l'animal.
final ValueNotifier<String?> soinsDemandeChat = ValueNotifier<String?>(null);

// ---------- Textes du site (dates, heures, rythme) ----------

const _joursSemaine = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

/// « ven. 9/10 » (jourCourt du site).
String soinsJourCourt(DateTime d) =>
    '${_joursSemaine[d.weekday - 1]} ${d.day}/${d.month.toString().padLeft(2, '0')}';

/// « 21 h », « 8 h 30 » (heureTexte du site).
String soinsHeureTexte(String h) {
  final morceaux = h.split(':');
  final heures = int.tryParse(morceaux.first) ?? 0;
  final minutes = morceaux.length > 1 ? morceaux[1] : '';
  final suite = (minutes.isNotEmpty && minutes != '00') ? ' $minutes' : '';
  return '$heures h$suite';
}

/// « Chaque jour à 7 h, 21 h » (rythmeTexte du site).
String soinsRythmeTexte(int pas, List<String> heures) {
  final triees = List<String>.from(heures)..sort();
  final hs = triees.map(soinsHeureTexte).join(', ');
  final quand = pas == 1
      ? 'Chaque jour'
      : pas == 7
          ? 'Chaque semaine'
          : 'Tous les $pas jours';
  return hs.isNotEmpty ? '$quand à $hs' : quand;
}

/// « du 06/10/2026 au 12/10/2026 » ou « depuis le 07/10/2026, jusqu'à
/// nouvel ordre » (periodeTexte du site).
String soinsPeriodeTexte(DateTime debut, DateTime? fin) {
  if (fin != null) return 'du ${jourLong(debut)} au ${jourLong(fin)}';
  return "depuis le ${jourLong(debut)}, jusqu'à nouvel ordre";
}

/// « 21:05 » : l'heure qu'il est, au format des heures de prise (le site
/// compare ces textes entre eux).
String soinsHeureMaintenant(DateTime maintenant) =>
    '${maintenant.hour.toString().padLeft(2, '0')}:${maintenant.minute.toString().padLeft(2, '0')}';

/// Les prises du jour de tous les dossiers en cours, dans l'ordre exact du
/// site (duJour) : dossier par dossier, traitement par traitement, puis
/// triées par heure sans changer l'ordre des prises à la même heure.
List<SoinOccurrence> soinsDuJour(SoinsEtat etat, DateTime maintenant) {
  final auj = jourSeul(maintenant);
  final liste = <SoinOccurrence>[];
  for (final d in etat.actifs) {
    for (final t in etat.traitementsDe(d.id)) {
      if (!t.estPrevuLe(auj)) continue;
      for (final h in t.heures) {
        liste.add(SoinOccurrence(traitement: t, jour: auj, heure: h, prise: etat.prise(t.id, auj, h)));
      }
    }
  }
  final ordre = List<int>.generate(liste.length, (i) => i);
  ordre.sort((a, b) {
    final c = liste[a].heure.compareTo(liste[b].heure);
    return c != 0 ? c : a - b;
  });
  return [for (final i in ordre) liste[i]];
}

/// La prochaine prise d'un dossier, calculée comme sur le site : sur 8
/// jours ; aujourd'hui, ni les heures passées ni les prises déjà cochées.
SoinOccurrence? soinsProchaine(SoinsEtat etat, SoinDossier d, DateTime maintenant) {
  final auj = jourSeul(maintenant);
  final hm = soinsHeureMaintenant(maintenant);
  final traitements = etat.traitementsDe(d.id);
  for (var k = 0; k < 8; k++) {
    final jour = auj.add(Duration(days: k));
    SoinOccurrence? meilleure;
    for (final t in traitements) {
      if (!t.estPrevuLe(jour)) continue;
      for (final h in t.heures) {
        if (k == 0 && h.compareTo(hm) < 0) continue;
        if (k == 0 && etat.prise(t.id, jour, h) != null) continue;
        if (meilleure == null || h.compareTo(meilleure.heure) < 0) {
          meilleure = SoinOccurrence(traitement: t, jour: jour, heure: h);
        }
      }
    }
    if (meilleure != null) return meilleure;
  }
  return null;
}

/// « Prises cochées : 3 sur 7 » (stats du site) : les prises prévues des
/// 60 derniers jours jusqu'à maintenant, et celles cochées « fait ».
Observance soinsStats(SoinsEtat etat, SoinTraitement t, DateTime maintenant) {
  final auj = jourSeul(maintenant);
  final hm = soinsHeureMaintenant(maintenant);
  final limite = auj.subtract(const Duration(days: 60));
  var jour = t.debut.isBefore(limite) ? limite : t.debut;
  final fin = t.fin;
  final dernier = (fin != null && fin.isBefore(auj)) ? fin : auj;
  var prevues = 0;
  var faites = 0;
  while (!jour.isAfter(dernier)) {
    if (t.estPrevuLe(jour)) {
      for (final h in t.heures) {
        if (jour == auj && h.compareTo(hm) > 0) continue;
        prevues++;
        final p = etat.prise(t.id, jour, h);
        if (p != null && !p.sautee) faites++;
      }
    }
    jour = jour.add(const Duration(days: 1));
  }
  return Observance(faites, prevues);
}

/// Le résumé pour le vétérinaire, mot pour mot celui du site (resume).
String soinsResume(SoinsEtat etat, SoinDossier d, String nom, Pet? pet, DateTime maintenant) {
  final l = <String>[];
  l.add('Suivi de soin — $nom${pet != null ? ' (${pet.species})' : ''}');
  l.add('Problème : ${d.titre}');
  l.add('Ouvert le ${jourLong(d.debut)} (jour ${d.jourNumero}).');
  final notes = d.notes ?? '';
  if (notes.isNotEmpty) l.add('Précisions : $notes');
  l.add('');
  final trs = etat.traitementsDe(d.id);
  if (trs.isEmpty) {
    l.add('Aucun traitement enregistré.');
  } else {
    l.add('Traitements :');
    for (final t in trs) {
      final s = soinsStats(etat, t, maintenant);
      final dose = t.dose ?? '';
      l.add('- ${t.nom}${dose.isNotEmpty ? ' — $dose' : ''} — '
          '${soinsRythmeTexte(t.tousLesJours, t.heures).toLowerCase()}, '
          '${soinsPeriodeTexte(t.debut, t.fin)}.'
          '${s.prevues > 0 ? ' Prises cochées : ${s.faites} sur ${s.prevues}.' : ''}');
    }
  }
  final suivis = etat.suivisDe(d.id).reversed.toList();
  if (suivis.isNotEmpty) {
    l.add('');
    l.add('Évolution jour par jour :');
    for (final s in suivis) {
      final note = s.note ?? '';
      l.add('- ${soinsJourCourt(s.jour)} : ${libelleSuivi(s.etat).toLowerCase()}${note.isNotEmpty ? ' — $note' : ''}');
    }
  }
  l.add('');
  l.add("Résumé généré par Tyto. Il ne remplace pas l'avis d'un vétérinaire.");
  return l.join('\n');
}

/// « Misty · jour 4 · prochaine prise à 12 h » (ligne sous le titre d'un
/// dossier ouvert).
String soinsLigneDossier(SoinsEtat etat, SoinDossier d, String nom) {
  final base = '$nom · jour ${d.jourNumero}';
  final prochaine = soinsProchaine(etat, d, DateTime.now());
  if (prochaine == null) return base;
  final auj = aujourdhui();
  final quand = prochaine.jour == auj
      ? 'à '
      : prochaine.jour == auj.add(const Duration(days: 1))
          ? 'demain à '
          : '${soinsJourCourt(prochaine.jour)} à ';
  return '$base · prochaine prise $quand${soinsHeureTexte(prochaine.heure)}';
}

/// « Rex · du 19/09/2026 au 27/09/2026 » (ligne d'un dossier terminé).
String soinsLigneTermine(SoinDossier d, String nom) {
  final c = d.cloture;
  return c != null
      ? '$nom · du ${jourLong(d.debut)} au ${jourLong(c)}'
      : '$nom · depuis le ${jourLong(d.debut)}';
}

// ---------- Suivi du jour : Mieux / Pareil / Moins bien ----------

/// La couleur de l'état (ETATS du site) : vert, fauve, urgence.
Color couleurSuivi(String etat) {
  switch (etat) {
    case 'better':
      return TytoColors.vert;
    case 'worse':
      return TytoColors.urgence;
    default:
      return TytoColors.fauve;
  }
}

/// La couleur du mot dans « Évolution » (#2f6e60, #8a6a2f, URGENCE).
Color couleurSuiviTexte(String etat) {
  switch (etat) {
    case 'better':
      return const Color(0xFF2F6E60);
    case 'worse':
      return TytoColors.urgence;
    default:
      return const Color(0xFF8A6A2F);
  }
}

String libelleSuivi(String etat) {
  switch (etat) {
    case 'better':
      return 'Mieux';
    case 'worse':
      return 'Moins bien';
    default:
      return 'Pareil';
  }
}

const etatsSuivi = ['better', 'same', 'worse'];

// ---------- Mise en page ----------

/// Titre de section sur le fond nuit (« Aujourd'hui », « Dossiers en
/// cours », « Terminés ») : Fraunces 17, poids normal, lune, marges
/// [haut] 2 8 2.
Widget titreSection(String texte, {double haut = 6}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(2, haut, 2, 8),
    child: Text(texte, style: TytoText.display(size: 17, weight: FontWeight.w400, color: TytoColors.lune)),
  );
}

/// La phrase du bas de la rubrique (12 px, brume, interligne 1,5,
/// marges [haut] 2 6 2).
Widget avertissementSoins({double haut = 6}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(2, haut, 2, 6),
    child: Text(
      "Tyto n'est pas un vétérinaire : il t'aide à suivre ce que ton vétérinaire a prescrit, sans jamais le modifier.",
      style: TytoText.ui(size: 12, color: TytoColors.brume).copyWith(height: 1.5),
    ),
  );
}

/// Le texte d'attente du site (« Chargement des soins… »).
Widget chargementSoins() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
    child: Text('Chargement des soins…', style: TytoText.ui(size: 14, color: TytoColors.brume)),
  );
}

/// La carte papier du site (carte) : fond ivoire, bord 1 px encre à 15 %,
/// rayon 12, padding 14 x 16, ombre, 12 px sous elle.
class CarteSoin extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double bas;

  const CarteSoin({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.bas = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bas),
      child: SizedBox(
        width: double.infinity,
        child: FenetrePapier(padding: padding, child: child),
      ),
    );
  }
}

/// La carte d'introduction de la rubrique (gélule + « Soins en cours »).
class IntroSoins extends StatelessWidget {
  const IntroSoins({super.key});

  @override
  Widget build(BuildContext context) {
    return CarteSoin(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TytoIcon.soins(size: 22, color: TytoColors.encre),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Soins en cours', style: TytoText.display(size: 19, color: TytoColors.encre)),
                const SizedBox(height: 4),
                Text(
                  'Un dossier par problème de santé : les traitements à heures fixes, le suivi jour après jour, '
                  "et un résumé à montrer au vétérinaire. Les rappels sonores à l'heure de chaque prise sont "
                  "envoyés par l'application Tyto sur ton téléphone ; ici, tu coches et tu suis.",
                  style: TytoText.body(size: 15, color: TytoColors.encre).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// L'étiquette d'un champ (etiquette du site) : 11 px gras, capitales,
/// espacement 0,08 em, encre à 60 %, marges [haut] 0 5.
class EtiquetteSoin extends StatelessWidget {
  final String texte;
  final double haut;

  const EtiquetteSoin(this.texte, {super.key, this.haut = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: haut, bottom: 5),
      child: Text(
        texte.toUpperCase(),
        style: TytoText.ui(size: 11, weight: FontWeight.w700, color: encreA(0x99)).copyWith(letterSpacing: 0.88),
      ),
    );
  }
}

/// Un champ blanc du site (champ) : 14,5 px, padding 9 x 12, bord 1 px
/// encre à 20 %, rayon 10.
class ChampSoin extends StatelessWidget {
  final TextEditingController controller;
  final String indication;
  final ValueChanged<String>? onChanged;

  const ChampSoin({super.key, required this.controller, required this.indication, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: TytoColors.encre,
      style: TytoText.ui(size: 14.5, color: TytoColors.encre),
      decoration: decorationChampPapier(
        indication: indication,
        taille: 14.5,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
    );
  }
}

/// Le champ « heure » ou « date » du site (input type time / date) : même
/// habillage que [ChampSoin], la valeur à gauche et le petit symbole du
/// navigateur à droite. Un toucher ouvre le sélecteur du téléphone.
class ChampChoixSoin extends StatelessWidget {
  final String texte;
  final double largeur;
  final double hauteur;
  final bool heure;
  final VoidCallback onTap;

  const ChampChoixSoin({
    super.key,
    required this.texte,
    required this.largeur,
    required this.hauteur,
    required this.heure,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: largeur,
        height: hauteur,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: encreA(0x33)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(texte, maxLines: 1, style: TytoText.ui(size: 14.5, color: TytoColors.encre)),
            ),
            Icon(
              heure ? Icons.access_time : Icons.calendar_today,
              size: heure ? 16 : 15,
              color: TytoColors.encre,
            ),
          ],
        ),
      ),
    );
  }
}

/// Une pastille du site (Pastille) : blanche, bord encre à 20 % ; active,
/// teintée de sa couleur à 20 % avec un bord plein et le texte en gras.
class PastilleSoin extends StatelessWidget {
  final String texte;
  final bool actif;
  final VoidCallback? onTap;
  final Color? couleur;

  const PastilleSoin({
    super.key,
    required this.texte,
    required this.actif,
    required this.onTap,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? TytoColors.fauve;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: actif ? c.withAlpha(0x33) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: actif ? c : encreA(0x33)),
        ),
        child: Text(
          texte,
          style: TytoText.ui(
            size: 13,
            weight: actif ? FontWeight.w700 : FontWeight.w400,
            color: TytoColors.encre,
          ),
        ),
      ),
    );
  }
}

/// Le bouton doré du site (boutonOr) : 11 x 22, 14,5 px gras ; [petit]
/// = le « Fait » des prises (7 x 14, 13 px).
class BoutonOrSoin extends StatelessWidget {
  final String texte;
  final VoidCallback? onTap;
  final bool petit;
  final bool actif;
  final double opaciteInactive;

  const BoutonOrSoin(
    this.texte, {
    super.key,
    required this.onTap,
    this.petit = false,
    this.actif = true,
    this.opaciteInactive = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return BoutonPilule(
      texte: texte,
      onTap: onTap,
      fond: TytoColors.fauve,
      encre: TytoColors.nuit,
      padding: petit
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
          : const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      taille: petit ? 13 : 14.5,
      gras: true,
      actif: actif,
      opaciteInactive: opaciteInactive,
    );
  }
}

/// Le bouton discret du site (boutonDiscret) : sans fond, bord 1 px encre
/// à 25 %, texte encre 13 px, padding 6 x 14.
class BoutonDiscretSoin extends StatelessWidget {
  final String texte;
  final VoidCallback? onTap;

  const BoutonDiscretSoin(this.texte, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BoutonPilule(
      texte: texte,
      onTap: onTap,
      encre: TytoColors.encre,
      bord: encreA(0x40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      taille: 13,
      gras: false,
    );
  }
}

/// Une rangée de boutons comme une ligne flex du site : collés à gauche,
/// [ecart] px entre eux, tous étirés à la hauteur du plus haut (le bouton
/// discret à côté du bouton doré fait donc 39 px, comme sur le site).
Widget rangeeBoutonsSoin(List<Widget> boutons, {double ecart = 8}) {
  final enfants = <Widget>[];
  for (var i = 0; i < boutons.length; i++) {
    if (i > 0) enfants.add(SizedBox(width: ecart));
    enfants.add(boutons[i]);
  }
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: enfants,
    ),
  );
}

/// L'encadré d'alerte d'un dossier : urgence (grave) ou fauve, fond à
/// 13 %, bord à 53 %, rayon 10, Karla 13,5 interligne 1,45.
class AlerteSoin extends StatelessWidget {
  final String texte;
  final bool grave;

  const AlerteSoin({super.key, required this.texte, required this.grave});

  @override
  Widget build(BuildContext context) {
    final c = grave ? TytoColors.urgence : TytoColors.fauve;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withAlpha(0x22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withAlpha(0x88)),
      ),
      child: Text(texte, style: TytoText.ui(size: 13.5, color: TytoColors.encre).copyWith(height: 1.45)),
    );
  }
}

/// La puce du dernier suivi sous le titre d'un dossier : « ven. 9/10 :
/// Moins bien », teintée de la couleur de l'état.
class PuceSuiviSoin extends StatelessWidget {
  final SoinSuivi suivi;

  const PuceSuiviSoin({super.key, required this.suivi});

  @override
  Widget build(BuildContext context) {
    final c = couleurSuivi(suivi.etat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(0x33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Text(
        '${soinsJourCourt(suivi.jour)} : ${libelleSuivi(suivi.etat)}',
        style: TytoText.ui(size: 12, weight: FontWeight.w700, color: TytoColors.encre),
      ),
    );
  }
}

/// L'en-tête d'un dossier (bouton du site) : titre Fraunces 17, ligne
/// d'infos, puce du dernier suivi, et « + » / « − » à droite.
class EnteteDossierSoin extends StatelessWidget {
  final String titre;
  final String ligne;
  final SoinSuivi? dernier;
  final bool deplie;
  final VoidCallback onTap;

  const EnteteDossierSoin({
    super.key,
    required this.titre,
    required this.ligne,
    required this.dernier,
    required this.deplie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final suivi = dernier;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: TytoText.display(size: 17, color: TytoColors.encre)),
                const SizedBox(height: 2),
                Text(ligne, style: TytoText.ui(size: 12.5, color: encreA(0x99))),
                if (suivi != null) ...[
                  const SizedBox(height: 7),
                  PuceSuiviSoin(suivi: suivi),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(deplie ? '−' : '+', style: TytoText.ui(size: 18, color: encreA(0x99))),
        ],
      ),
    );
  }
}

/// Une prise du jour (ligne « Aujourd'hui » du site) : l'heure en gras
/// (rouge si en retard), le traitement (barré une fois coché), l'animal
/// et la dose, puis « Fait » / « Passer » ou « Fait · annuler ».
class LignePriseSoin extends StatelessWidget {
  final SoinOccurrence occurrence;
  final String? nomAnimal;
  final bool trait; // filet au-dessus (toutes les lignes sauf la première)
  final VoidCallback onFait;
  final VoidCallback onPasser;
  final VoidCallback onAnnuler;

  const LignePriseSoin({
    super.key,
    required this.occurrence,
    this.nomAnimal,
    this.trait = false,
    required this.onFait,
    required this.onPasser,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    // Comme le site : pas encore cochée et son heure (« 08:00 ») avant
    // l'heure qu'il est.
    final enRetard = o.prise == null && o.heure.compareTo(soinsHeureMaintenant(DateTime.now())) < 0;
    final barre = o.traitee;
    final dose = o.traitement.dose?.trim() ?? '';
    final details = <String>[
      if (nomAnimal != null && nomAnimal!.isNotEmpty) nomAnimal!,
      if (dose.isNotEmpty) dose,
      if (enRetard) 'en retard',
    ];
    // Le site pose opacity 0.55 sur le nom barré : encre à 55 % (0x8c).
    final couleurNom = barre ? encreA(0x8c) : TytoColors.encre;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: trait ? BoxDecoration(border: Border(top: BorderSide(color: encreA(0x1a)))) : null,
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 58),
            child: Text(
              soinsHeureTexte(o.heure),
              style: TytoText.ui(
                size: 14,
                weight: FontWeight.w700,
                color: enRetard ? TytoColors.urgence : TytoColors.encre,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.traitement.nom,
                  style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: couleurNom).copyWith(
                    decoration: barre ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: couleurNom,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(details.join(' · '), style: TytoText.ui(size: 12.5, color: encreA(0x99))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (o.traitee)
            BoutonDiscretSoin(o.faite ? 'Fait · annuler' : 'Passée · annuler', onTap: onAnnuler)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BoutonOrSoin('Fait', onTap: onFait, petit: true),
                const SizedBox(width: 6),
                BoutonDiscretSoin('Passer', onTap: onPasser),
              ],
            ),
        ],
      ),
    );
  }
}

/// La barre de progression d'un traitement : 5 px, fond encre à 8 %,
/// remplissage vert, rayon 3.
class ProgressionSoin extends StatelessWidget {
  final double ratio;

  const ProgressionSoin({super.key, required this.ratio});

  @override
  Widget build(BuildContext context) {
    // Le site arrondit au pour cent près.
    final r = ((ratio * 100).round() / 100).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        width: double.infinity,
        color: encreA(0x14),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: r,
          heightFactor: 1,
          child: const ColoredBox(color: TytoColors.vert),
        ),
      ),
    );
  }
}

/// Le message du site (bandeau nuit au bord doré), montré en bas d'écran.
void messageSoin(BuildContext context, String texte) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TytoColors.nuit2,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: TytoColors.fauve.withAlpha(0x66)),
      ),
      content: Text(texte, style: TytoText.ui(size: 13.5, color: TytoColors.lune)),
    ),
  );
}

/// La demande de confirmation (window.confirm du site), sur une carte
/// papier : le message, le bouton doré de l'action et « Annuler ».
Future<bool> confirmerSoin(BuildContext context, String texte, String action) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xCC0A0E18),
    builder: (ctx) => CadreDialogue(
      marge: 16,
      largeurMax: 420,
      child: FenetrePapier(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texte, style: TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.55)),
            const SizedBox(height: 14),
            rangeeBoutonsSoin([
              BoutonOrSoin(action, onTap: () => Navigator.pop(ctx, true)),
              BoutonDiscretSoin('Annuler', onTap: () => Navigator.pop(ctx, false)),
            ]),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}
