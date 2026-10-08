import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../services/soins_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/traitement_form.dart';

/// Le détail d'un dossier de soin : comment va l'animal aujourd'hui, les
/// traitements avec leurs prises du jour, l'historique du suivi, et de
/// quoi préparer la consultation chez le vétérinaire.
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
  final _note = TextEditingController();
  bool _envoiSuivi = false;

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
      final suiviDuJour = etat.suiviLe(widget.dossierId, aujourdhui());
      setState(() {
        _etat = etat;
        _pets = pets;
        _chargement = false;
        _erreur = false;
        if (suiviDuJour?.note != null && _note.text.isEmpty) _note.text = suiviDuJour!.note!;
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

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // ---------- Actions ----------

  Future<void> _pointer(SoinOccurrence o, {bool sauter = false}) async {
    try {
      await SoinsService.pointer(o, sautee: sauter);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("La prise n'a pas pu être enregistrée, réessaie.");
    }
  }

  Future<void> _annuler(SoinOccurrence o) async {
    final prise = o.prise;
    if (prise == null) return;
    try {
      await SoinsService.annulerPrise(prise.id);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("L'annulation n'a pas abouti, réessaie.");
    }
  }

  Future<void> _suivi(String etat) async {
    if (_envoiSuivi) return;
    setState(() => _envoiSuivi = true);
    try {
      await SoinsService.enregistrerSuivi(dossierId: widget.dossierId, etat: etat, note: _note.text);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("Le suivi n'a pas pu être enregistré, réessaie.");
    } finally {
      if (mounted) setState(() => _envoiSuivi = false);
    }
  }

  Future<void> _ajouterTraitement() async {
    final d = _dossier;
    if (d == null) return;
    final t = await ouvrirFormulaireTraitement(context);
    if (t == null) return;
    try {
      await SoinsService.ajouterTraitement(d, t);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("Le traitement n'a pas pu être ajouté, réessaie.");
    }
  }

  Future<void> _modifierTraitement(SoinTraitement t) async {
    final nouveau = await ouvrirFormulaireTraitement(context, initial: t.versNouveau());
    if (nouveau == null) return;
    try {
      await SoinsService.modifierTraitement(t.id, nouveau);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("La modification n'a pas abouti, réessaie.");
    }
  }

  Future<bool> _confirmer(String titre, String texte, String bouton) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        title: Text(titre, style: TytoText.display(size: 18)),
        content: Text(texte, style: TytoText.body(size: 14.5, color: TytoColors.lune.withOpacity(0.85))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(bouton, style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.fauve)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _arreter(SoinTraitement t) async {
    final ok = await _confirmer(
      'Arrêter ce traitement ?',
      "${t.nom} ne sera plus rappelé à partir de demain. Les prises déjà cochées restent dans l'historique.",
      'Arrêter',
    );
    if (!ok) return;
    try {
      await SoinsService.arreterTraitement(t);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("L'arrêt n'a pas abouti, réessaie.");
    }
  }

  Future<void> _supprimer(SoinTraitement t) async {
    final ok = await _confirmer(
      'Supprimer ce traitement ?',
      '${t.nom} sera retiré du dossier, avec ses prises cochées.',
      'Supprimer',
    );
    if (!ok) return;
    try {
      await SoinsService.supprimerTraitement(t.id);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) _message("La suppression n'a pas abouti, réessaie.");
    }
  }

  Future<void> _cloturer() async {
    final d = _dossier;
    if (d == null) return;
    final nom = _animal?.name ?? 'ton compagnon';
    final ok = await _confirmer(
      'Clôturer ce dossier ?',
      "Les rappels s'arrêtent et le dossier passe dans « Terminés ». Une note est ajoutée au carnet de $nom.",
      'Clôturer',
    );
    if (!ok) return;
    try {
      await SoinsService.cloturer(d, nom);
      await SoinsService.reprogrammerNotifications();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _message("La clôture n'a pas abouti, réessaie.");
    }
  }

  Future<void> _supprimerDossier() async {
    final d = _dossier;
    if (d == null) return;
    final ok = await _confirmer(
      'Supprimer ce dossier ?',
      'Le dossier, ses traitements et son suivi seront effacés définitivement.',
      'Supprimer',
    );
    if (!ok) return;
    try {
      await SoinsService.supprimerDossier(d.id);
      await SoinsService.reprogrammerNotifications();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _message("La suppression n'a pas abouti, réessaie.");
    }
  }

  Future<void> _partager() async {
    final d = _dossier;
    final pet = _animal;
    if (d == null || pet == null) return;
    final texte = SoinsService.resumePourVeto(_etat, d, pet);
    await Share.share(texte, subject: 'Suivi de ${pet.name} — ${d.titre}');
  }

  // ---------- Morceaux d'écran ----------

  Widget _carte({required Widget enfant, Color? bord}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TytoColors.nuit2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (bord ?? TytoColors.lune).withOpacity(bord == null ? 0.08 : 0.5)),
      ),
      child: enfant,
    );
  }

  Widget _entete(SoinDossier d, String nom) {
    return _carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.titre, style: TytoText.display(size: 22)),
          const SizedBox(height: 4),
          Text(
            d.clos
                ? '$nom · du ${jourLong(d.debut)} au ${jourLong(d.cloture ?? d.debut)}'
                : '$nom · jour ${d.jourNumero} · depuis le ${jourLong(d.debut)}',
            style: TytoText.ui(size: 13, color: TytoColors.brume),
          ),
          if (d.notes != null && d.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.notes!.trim(), style: TytoText.body(size: 14.5, color: TytoColors.lune.withOpacity(0.85))),
          ],
        ],
      ),
    );
  }

  Widget _alerte(SoinAlerte a) {
    final couleur = a.grave ? TytoColors.urgence : TytoColors.fauve;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withOpacity(0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: couleur),
          const SizedBox(width: 10),
          Expanded(child: Text(a.texte, style: TytoText.ui(size: 13.5, color: TytoColors.lune).copyWith(height: 1.4))),
        ],
      ),
    );
  }

  Widget _boutonSuivi(String etat, SoinSuivi? actuel) {
    final on = actuel?.etat == etat;
    final couleur = couleurSuivi(etat);
    return Expanded(
      child: GestureDetector(
        onTap: _envoiSuivi ? null : () => _suivi(etat),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: on ? couleur.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? couleur : TytoColors.lune.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(iconeSuivi(etat), size: 24, color: on ? couleur : TytoColors.brume),
              const SizedBox(height: 4),
              Text(
                libelleSuivi(etat),
                style: TytoText.ui(
                  size: 12.5,
                  weight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? couleur : TytoColors.brume,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suiviDuJour(SoinDossier d, String nom) {
    final actuel = _etat.suiviLe(d.id, aujourdhui());
    return _carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Comment va $nom aujourd'hui ?", style: TytoText.ui(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              _boutonSuivi('better', actuel),
              const SizedBox(width: 8),
              _boutonSuivi('same', actuel),
              const SizedBox(width: 8),
              _boutonSuivi('worse', actuel),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: TytoText.ui(color: TytoColors.lune),
            decoration: InputDecoration(
              hintText: 'Une précision (œil moins rouge, mange moins…)',
              hintStyle: TytoText.ui(size: 13, color: TytoColors.brume),
              filled: true,
              fillColor: TytoColors.nuit,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            actuel == null
                ? "Choisis une option : la précision est enregistrée avec."
                : 'Enregistré. Touche une option pour mettre à jour avec la précision ci-dessus.',
            style: TytoText.ui(size: 11.5, color: TytoColors.brume),
          ),
        ],
      ),
    );
  }

  Widget _carteTraitement(SoinTraitement t, SoinDossier d, String nom) {
    final obs = _etat.observance(t, DateTime.now());
    final prisesDuJour = _etat.occurrencesLe(aujourdhui(), dossierId: d.id).where((o) => o.traitement.id == t.id).toList();

    String? etatPeriode;
    double? progression;
    if (t.pasCommence) {
      etatPeriode = 'Commence le ${jourLong(t.debut)}';
    } else if (t.termine) {
      etatPeriode = 'Traitement terminé';
      progression = 1.0;
    } else if (t.fin != null) {
      etatPeriode = 'Jour ${t.jourCourant} sur ${t.joursTotal}';
      progression = t.joursTotal == 0 ? null : t.jourCourant / t.joursTotal;
    } else {
      etatPeriode = 'Jour ${t.jourCourant}, sans date de fin';
    }

    return _carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.nom, style: TytoText.ui(size: 16, weight: FontWeight.w700)),
                    if (t.dose != null && t.dose!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(t.dose!.trim(), style: TytoText.ui(size: 13.5, color: TytoColors.lune.withOpacity(0.85))),
                      ),
                    const SizedBox(height: 3),
                    Text(t.rythme, style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                    Text(periodeTexte(t.debut, t.fin), style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                    if (t.notes != null && t.notes!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(t.notes!.trim(), style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                      ),
                  ],
                ),
              ),
              if (!d.clos)
                PopupMenuButton<String>(
                  color: TytoColors.nuit2,
                  icon: const Icon(Icons.more_vert_rounded, color: TytoColors.brume),
                  onSelected: (v) {
                    if (v == 'modifier') _modifierTraitement(t);
                    if (v == 'arreter') _arreter(t);
                    if (v == 'supprimer') _supprimer(t);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'modifier', child: Text('Modifier', style: TytoText.ui())),
                    if (!t.termine) PopupMenuItem(value: 'arreter', child: Text('Arrêter le traitement', style: TytoText.ui())),
                    PopupMenuItem(value: 'supprimer', child: Text('Supprimer', style: TytoText.ui(color: TytoColors.urgence))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(etatPeriode, style: TytoText.ui(size: 12.5, weight: FontWeight.w700, color: TytoColors.fauve)),
          if (progression != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progression.clamp(0.0, 1.0),
                minHeight: 6,
                color: TytoColors.fauve,
                backgroundColor: TytoColors.lune.withOpacity(0.1),
              ),
            ),
          ],
          if (obs.prevues > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Prises cochées : ${obs.faites} sur ${obs.prevues}',
              style: TytoText.ui(size: 12, color: TytoColors.brume),
            ),
          ],
          if (!d.clos && prisesDuJour.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final o in prisesDuJour)
              LignePriseSoin(
                occurrence: o,
                onFait: () => _pointer(o),
                onPasser: () => _pointer(o, sauter: true),
                onAnnuler: () => _annuler(o),
              ),
          ],
        ],
      ),
    );
  }

  Widget _historique(SoinDossier d) {
    final liste = _etat.suivisDe(d.id).take(14).toList();
    if (liste.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titreSection('Évolution'),
        _carte(
          enfant: Column(
            children: [
              for (final s in liste)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(iconeSuivi(s.etat), size: 20, color: couleurSuivi(s.etat)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 46,
                        child: Text(jourCourt(s.jour), style: TytoText.ui(size: 13, weight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Text(
                          (s.note != null && s.note!.trim().isNotEmpty) ? '${s.libelle} — ${s.note!.trim()}' : s.libelle,
                          style: TytoText.ui(size: 13, color: TytoColors.lune.withOpacity(0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenu(SoinDossier d) {
    final nom = _animal?.name ?? 'ton compagnon';
    final traitements = _etat.traitementsDe(d.id);
    final alerte = _etat.alerte(d, nom);

    return RefreshIndicator(
      color: TytoColors.fauve,
      backgroundColor: TytoColors.nuit2,
      onRefresh: () => _charger(silencieux: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _entete(d, nom),
          if (alerte != null) _alerte(alerte),
          if (!d.clos) _suiviDuJour(d, nom),
          titreSection('Traitements'),
          if (traitements.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Aucun traitement dans ce dossier. Ajoute-en un pour être rappelé à chaque prise.',
                style: TytoText.body(size: 14.5, color: TytoColors.brume),
              ),
            ),
          for (final t in traitements) _carteTraitement(t, d, nom),
          if (!d.clos)
            OutlinedButton.icon(
              onPressed: _ajouterTraitement,
              icon: const Icon(Icons.add_rounded, size: 18, color: TytoColors.fauve),
              label: Text('Ajouter un traitement', style: TytoText.ui(size: 14, color: TytoColors.fauve)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: TytoColors.fauve.withOpacity(0.55)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          _historique(d),
          titreSection('Pour le vétérinaire'),
          OutlinedButton.icon(
            onPressed: _partager,
            icon: const Icon(Icons.ios_share_rounded, size: 18, color: TytoColors.lune),
            label: Text('Partager le résumé du suivi', style: TytoText.ui(size: 14, color: TytoColors.lune)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: TytoColors.lune.withOpacity(0.25)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (!d.clos) ...[
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _cloturer,
              style: ElevatedButton.styleFrom(
                backgroundColor: TytoColors.vert,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Clôturer le dossier',
                style: TytoText.ui(weight: FontWeight.w700, color: const Color(0xFF0F2A24)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _dossier;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Dossier de soin', style: TytoText.display(size: 19)),
        actions: [
          if (d != null)
            PopupMenuButton<String>(
              color: TytoColors.nuit2,
              icon: const Icon(Icons.more_vert_rounded, color: TytoColors.fauve),
              onSelected: (v) {
                if (v == 'supprimer') _supprimerDossier();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'supprimer',
                  child: Text('Supprimer le dossier', style: TytoText.ui(color: TytoColors.urgence)),
                ),
              ],
            ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
          : _erreur
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Impossible de charger ce dossier pour l'instant. Vérifie ta connexion.",
                          textAlign: TextAlign.center,
                          style: TytoText.body(size: 14.5, color: TytoColors.brume),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: _charger,
                          child: Text('Réessayer', style: TytoText.ui(color: TytoColors.fauve)),
                        ),
                      ],
                    ),
                  ),
                )
              : d == null
                  ? Center(
                      child: Text(
                        'Ce dossier n\'existe plus.',
                        style: TytoText.body(size: 14.5, color: TytoColors.brume),
                      ),
                    )
                  : _contenu(d),
    );
  }
}
