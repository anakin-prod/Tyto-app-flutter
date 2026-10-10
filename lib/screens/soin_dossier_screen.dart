import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../services/soins_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/paw_trails.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/traitement_form.dart';

/// Le détail d'un dossier de soin : c'est le dossier « déplié » du site
/// (Dossier dans SoinsPanel.js) — comment va l'animal aujourd'hui, les
/// traitements, l'évolution, le résumé pour le vétérinaire, la clôture.
class SoinDossierScreen extends StatefulWidget {
  final String dossierId;
  const SoinDossierScreen({super.key, required this.dossierId});

  @override
  State<SoinDossierScreen> createState() => _SoinDossierScreenState();
}

class _SoinDossierScreenState extends State<SoinDossierScreen> {
  SoinsEtat _etat = const SoinsEtat();
  List<Pet> _pets = [];
  bool _chargement = true;
  bool _erreur = false;
  bool _occupe = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  SoinDossier? get _dossier => _etat.dossier(widget.dossierId);

  Pet? get _animal {
    final d = _dossier;
    if (d == null) return null;
    for (final p in _pets) {
      if (p.id == d.petId) return p;
    }
    return null;
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) setState(() => _chargement = true);
    try {
      final etat = await SoinsService.charger();
      final pets = await SoinsService.animaux();
      if (!mounted) return;
      setState(() {
        _etat = etat;
        _pets = pets;
        _chargement = false;
        _erreur = false;
      });
      SoinsService.programmerDepuis(etat, pets);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  // ---------- Actions ----------

  /// Lance une écriture en évitant les doubles touchers (occupe du site).
  Future<void> _ecrire(Future<void> Function() action, String echec) async {
    if (_occupe) return;
    setState(() => _occupe = true);
    try {
      await action();
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) messageSoin(context, echec);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _pointer(SoinOccurrence o, {bool sauter = false}) =>
      _ecrire(() => SoinsService.pointer(o, sautee: sauter), "La prise n'a pas pu être enregistrée, réessaie.");

  Future<void> _annuler(SoinOccurrence o) async {
    final prise = o.prise;
    if (prise == null) return;
    await _ecrire(() => SoinsService.annulerPrise(prise.id), "L'annulation n'a pas abouti, réessaie.");
  }

  /// Mieux / Pareil / Moins bien : la note tapée, sinon celle déjà
  /// enregistrée aujourd'hui, part avec.
  Future<void> _suivi(String etat) async {
    final actuel = _etat.suiviLe(widget.dossierId, aujourdhui());
    final saisie = _note.text.trim();
    final note = saisie.isNotEmpty ? saisie : (actuel?.note ?? '');
    await _ecrire(
      () => SoinsService.enregistrerSuivi(dossierId: widget.dossierId, etat: etat, note: note),
      "Le suivi n'a pas pu être enregistré, réessaie.",
    );
  }

  /// « Enregistrer la note » : garde l'état du jour, change la note.
  Future<void> _enregistrerNote() async {
    final actuel = _etat.suiviLe(widget.dossierId, aujourdhui());
    if (actuel == null) return;
    final note = _note.text;
    await _ecrire(
      () => SoinsService.enregistrerSuivi(dossierId: widget.dossierId, etat: actuel.etat, note: note),
      "Le suivi n'a pas pu être enregistré, réessaie.",
    );
    if (mounted) setState(() => _note.clear());
  }

  Future<void> _ajouterTraitement() async {
    final d = _dossier;
    if (d == null) return;
    final t = await ouvrirFormulaireTraitement(context);
    if (t == null || !mounted) return;
    await _ecrire(() => SoinsService.ajouterTraitement(d, t), "Le traitement n'a pas pu être ajouté, réessaie.");
  }

  Future<void> _modifierTraitement(SoinTraitement t) async {
    final nouveau = await ouvrirFormulaireTraitement(context, initial: t.versNouveau());
    if (nouveau == null || !mounted) return;
    await _ecrire(() => SoinsService.modifierTraitement(t.id, nouveau), "La modification n'a pas abouti, réessaie.");
  }

  /// « Arrêter » : comme sur le site, sans confirmation (les prises déjà
  /// cochées restent dans l'historique).
  Future<void> _arreter(SoinTraitement t) =>
      _ecrire(() => SoinsService.arreterTraitement(t), "L'arrêt n'a pas abouti, réessaie.");

  Future<void> _supprimer(SoinTraitement t) async {
    final ok = await confirmerSoin(context, 'Supprimer ce traitement et ses prises cochées ?', 'Supprimer');
    if (!ok || !mounted) return;
    await _ecrire(() => SoinsService.supprimerTraitement(t.id), "La suppression n'a pas abouti, réessaie.");
  }

  Future<void> _cloturer() async {
    final d = _dossier;
    if (d == null || _occupe) return;
    final ok = await confirmerSoin(
      context,
      "Clôturer le dossier « ${d.titre} » ? Les rappels s'arrêtent.",
      'Clôturer',
    );
    if (!ok || !mounted) return;
    setState(() => _occupe = true);
    try {
      await SoinsService.cloturer(d, _animal?.name ?? 'Ton compagnon');
      await SoinsService.reprogrammerNotifications();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _occupe = false);
        messageSoin(context, "La clôture n'a pas abouti, réessaie.");
      }
    }
  }

  Future<void> _supprimerDossier() async {
    final d = _dossier;
    if (d == null || _occupe) return;
    final ok = await confirmerSoin(
      context,
      'Supprimer définitivement le dossier « ${d.titre} », ses traitements et son suivi ?',
      'Supprimer',
    );
    if (!ok || !mounted) return;
    setState(() => _occupe = true);
    try {
      await SoinsService.supprimerDossier(d.id);
      await SoinsService.reprogrammerNotifications();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _occupe = false);
        messageSoin(context, "La suppression n'a pas abouti, réessaie.");
      }
    }
  }

  /// Le site copie le résumé ; l'application le partage (message, e-mail…
  /// ou copie depuis la feuille de partage du téléphone). Le texte est
  /// celui du site, mot pour mot.
  Future<void> _partager() async {
    final d = _dossier;
    if (d == null) return;
    final pet = _animal;
    final nom = pet?.name ?? 'Ton compagnon';
    final texte = soinsResume(_etat, d, nom, pet, DateTime.now());
    await Share.share(texte, subject: 'Suivi de $nom — ${d.titre}');
  }

  /// « En parler à Tyto » : retour au chat, en demandant l'animal du dossier.
  void _enParlerATyto() {
    final d = _dossier;
    if (d == null) return;
    soinsDemandeChat.value = d.petId;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ---------- Morceaux d'écran ----------

  /// Un traitement : carte blanche, bord encre à 12 %, rayon 10, padding
  /// 10 x 12 ; nom, dose et rythme, période, progression, prises cochées.
  Widget _carteTraitement(SoinTraitement t, SoinDossier d) {
    final obs = soinsStats(_etat, t, DateTime.now());
    final fini = t.termine;
    final dose = t.dose?.trim() ?? '';
    final remarque = t.notes?.trim() ?? '';
    final prisesDuJour = d.clos
        ? <SoinOccurrence>[]
        : _etat.occurrencesLe(aujourdhui(), dossierId: d.id).where((o) => o.traitement.id == t.id).toList();
    final total = t.joursTotal;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: encreA(0x1f)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: t.nom,
              children: [
                if (fini) TextSpan(text: ' (terminé)', style: TytoText.ui(size: 14.5, color: encreA(0x99))),
              ],
            ),
            style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.encre),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${dose.isNotEmpty ? '$dose · ' : ''}${soinsRythmeTexte(t.tousLesJours, t.heures)}',
              style: TytoText.ui(size: 12.5, color: encreA(0xb3)),
            ),
          ),
          Text(soinsPeriodeTexte(t.debut, t.fin), style: TytoText.ui(size: 12.5, color: encreA(0xb3))),
          if (remarque.isNotEmpty) Text(remarque, style: TytoText.ui(size: 12.5, color: encreA(0xb3))),
          if (t.fin != null && total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: ProgressionSoin(ratio: t.jourCourant / total),
            ),
          if (obs.prevues > 0)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Prises cochées : ${obs.faites} sur ${obs.prevues}',
                style: TytoText.ui(size: 12.5, color: TytoColors.encre),
              ),
            ),
          // Propre à l'application : les prises du jour de ce traitement,
          // à cocher depuis le dossier (mêmes lignes que « Aujourd'hui »).
          if (prisesDuJour.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  for (final o in prisesDuJour)
                    LignePriseSoin(
                      occurrence: o,
                      trait: true,
                      onFait: () => _pointer(o),
                      onPasser: () => _pointer(o, sauter: true),
                      onAnnuler: () => _annuler(o),
                    ),
                ],
              ),
            ),
          if (!d.clos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BoutonDiscretSoin('Modifier', onTap: () => _modifierTraitement(t)),
                  if (!fini) BoutonDiscretSoin('Arrêter', onTap: () => _arreter(t)),
                  BoutonDiscretSoin('Supprimer', onTap: () => _supprimer(t)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Une ligne d'« Évolution » : date (76 px au moins), état en couleur,
  /// puis la note.
  Widget _ligneEvolution(SoinSuivi s) {
    final note = s.note?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 76),
            child: Text(soinsJourCourt(s.jour), style: TytoText.ui(size: 13.5, color: encreA(0x99))),
          ),
          const SizedBox(width: 8),
          Text(
            libelleSuivi(s.etat),
            style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: couleurSuiviTexte(s.etat)),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text('— $note', style: TytoText.ui(size: 13.5, color: encreA(0xb3))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contenu(SoinDossier d) {
    final nom = _animal?.name ?? 'Ton compagnon';
    final traitements = _etat.traitementsDe(d.id);
    final suivis = _etat.suivisDe(d.id);
    final dixSuivis = suivis.take(10).toList();
    final alerte = _etat.alerte(d, nom);
    final actuel = _etat.suiviLe(d.id, aujourdhui());
    final notes = d.notes?.trim() ?? '';
    final noteDuJour = actuel?.note?.trim() ?? '';

    // Les marges du site se fondent entre blocs (ex. 8 px sous les notes
    // et 4 px au-dessus de l'étiquette donnent 8 px) : les valeurs
    // ci-dessous en tiennent compte.
    final corps = <Widget>[
      if (notes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(notes, style: TytoText.body(size: 14.5, color: TytoColors.encre)),
        ),
      if (!d.clos) ...[
        EtiquetteSoin("Comment va $nom aujourd'hui ?", haut: notes.isNotEmpty ? 0 : 4),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final e in etatsSuivi)
              PastilleSoin(
                texte: libelleSuivi(e),
                actif: actuel?.etat == e,
                couleur: couleurSuivi(e),
                onTap: () => _suivi(e),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChampSoin(
            controller: _note,
            indication: noteDuJour.isNotEmpty ? noteDuJour : 'Une note (appétit, œil moins rouge…)',
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_note.text.trim().isNotEmpty && actuel != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BoutonDiscretSoin('Enregistrer la note', onTap: _enregistrerNote),
          ),
      ],
      // Dossier clos (propre à l'application) : « Traitements » ouvre le
      // bloc, avec les 4 px de la première étiquette du site.
      EtiquetteSoin('Traitements', haut: d.clos ? 4 : 12),
      if (traitements.isEmpty)
        Text(
          d.clos
              ? 'Aucun traitement enregistré.'
              : "Aucun traitement. Ajoute-en un pour avoir les rappels dans l'application.",
          style: TytoText.ui(size: 13, color: encreA(0x99)),
        ),
      for (final t in traitements) _carteTraitement(t, d),
      if (!d.clos) BoutonDiscretSoin('Ajouter un traitement', onTap: _ajouterTraitement),
      if (dixSuivis.isNotEmpty) ...[
        EtiquetteSoin('Évolution', haut: (d.clos && traitements.isNotEmpty) ? 4 : 12),
        for (final s in dixSuivis) _ligneEvolution(s),
      ],
      Padding(
        padding: EdgeInsets.only(top: (d.clos && dixSuivis.isEmpty && traitements.isNotEmpty) ? 8 : 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BoutonOrSoin('Partager le résumé pour le vétérinaire', onTap: _partager),
            BoutonDiscretSoin('En parler à Tyto', onTap: _enParlerATyto),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!d.clos) BoutonDiscretSoin('Clôturer le dossier', onTap: _cloturer),
            BoutonDiscretSoin('Supprimer le dossier', onTap: _supprimerDossier),
          ],
        ),
      ),
    ];

    return RefreshIndicator(
      color: TytoColors.fauve,
      backgroundColor: TytoColors.nuit2,
      onRefresh: () => _charger(silencieux: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          CarteSoin(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toucher l'en-tête replie le dossier, comme sur le site :
                // ici, cela ramène à la liste.
                EnteteDossierSoin(
                  titre: d.titre,
                  ligne: d.clos ? soinsLigneTermine(d, nom) : soinsLigneDossier(_etat, d, nom),
                  dernier: suivis.isNotEmpty ? suivis.first : null,
                  deplie: true,
                  onTap: () => Navigator.maybePop(context),
                ),
                if (alerte != null) ...[
                  const SizedBox(height: 10),
                  AlerteSoin(texte: alerte.texte, grave: alerte.grave),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: encreA(0x1a))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: corps,
                  ),
                ),
              ],
            ),
          ),
          avertissementSoins(),
        ],
      ),
    );
  }

  Widget _erreurChargement() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        CarteSoin(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Soins en cours', style: TytoText.display(size: 19, color: TytoColors.encre)),
              const SizedBox(height: 6),
              Text(
                "Impossible de charger ce dossier pour l'instant. Vérifie ta connexion.",
                style: TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.55),
              ),
              const SizedBox(height: 12),
              BoutonDiscretSoin('Réessayer', onTap: () => _charger()),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _dossier;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('Soins en cours', style: TytoText.display(size: 19))),
      body: Stack(
        children: [
          // Les empreintes qui traversent le fond, comme sur tout le site.
          const Positioned.fill(child: PawTrails()),
          Positioned.fill(
            child: _chargement
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [chargementSoins()],
                  )
                : _erreur
                    ? _erreurChargement()
                    : d == null
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                            children: [
                              Text("Ce dossier n'existe plus.", style: TytoText.ui(size: 14, color: TytoColors.brume)),
                            ],
                          )
                        : _contenu(d),
          ),
        ],
      ),
    );
  }
}
