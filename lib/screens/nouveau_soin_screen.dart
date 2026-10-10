import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../services/notification_service.dart';
import '../services/soins_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/paw_trails.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/traitement_form.dart';

// SUGGESTIONS du site.
const _suggestions = [
  'Conjonctivite',
  'Otite',
  'Plaie',
  'Gastro-entérite',
  'Infection urinaire',
  'Boiterie',
  'Allergie',
  'Soin dentaire',
];

/// Ouvre un dossier de soin (NouveauDossier du site) : quel animal, quel
/// problème, et les traitements à donner (avec leurs heures). Les
/// traitements peuvent aussi arriver déjà remplis, depuis la lecture
/// d'une ordonnance.
class NouveauSoinScreen extends StatefulWidget {
  final List<Pet> pets;
  final Pet? petInitial;
  final List<NouveauTraitement> traitementsInitiaux;
  final bool depuisOrdonnance;

  const NouveauSoinScreen({
    super.key,
    required this.pets,
    this.petInitial,
    this.traitementsInitiaux = const [],
    this.depuisOrdonnance = false,
  });

  @override
  State<NouveauSoinScreen> createState() => _NouveauSoinScreenState();
}

class _NouveauSoinScreenState extends State<NouveauSoinScreen> {
  final _titre = TextEditingController();
  final _notes = TextEditingController();
  late List<NouveauTraitement> _traitements;
  Pet? _pet;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _traitements = List<NouveauTraitement>.from(widget.traitementsInitiaux);
    _pet = widget.petInitial ?? (widget.pets.isNotEmpty ? widget.pets.first : null);
  }

  @override
  void dispose() {
    _titre.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final t = await ouvrirFormulaireTraitement(context);
    if (t == null || !mounted) return;
    setState(() => _traitements.add(t));
  }

  Future<void> _modifier(int i) async {
    final t = await ouvrirFormulaireTraitement(context, initial: _traitements[i]);
    if (t == null || !mounted) return;
    setState(() => _traitements[i] = t);
  }

  Future<void> _creer() async {
    if (_envoi) return;
    final titre = _titre.text.trim();
    if (_pet == null) {
      setState(() => _erreur = "Choisis l'animal concerné.");
      return;
    }
    if (titre.isEmpty) {
      setState(() => _erreur = 'Indique le problème, par exemple « Conjonctivite ».');
      return;
    }
    setState(() {
      _erreur = null;
      _envoi = true;
    });
    try {
      final id = await SoinsService.creerDossier(
        petId: _pet!.id,
        titre: titre,
        notes: _notes.text,
        traitements: _traitements,
        nomAnimal: _pet!.name,
      );
      if (id == null) throw Exception('pas de session');
      // La permission de notifier est demandée ici, au moment où elle a un
      // sens : pour sonner à l'heure des prises.
      await NotificationService.demanderPermission();
      await SoinsService.reprogrammerNotifications();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      final manque = e.toString().contains('care_');
      messageSoin(
        context,
        manque
            ? "Les soins ne sont pas encore activés sur ce compte : il manque le script Supabase v8."
            : "Le dossier n'a pas pu être créé. Vérifie ta connexion et réessaie.",
      );
    }
  }

  /// Un traitement déjà saisi : carte blanche, bord encre à 12 %, rayon
  /// 10, padding 9 x 12, puis « Modifier » et « Retirer ».
  Widget _carteTraitement(int i) {
    final t = _traitements[i];
    final dose = t.dose?.trim() ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: encreA(0x1f)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.nom, style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.encre)),
          Text(
            '${dose.isNotEmpty ? '$dose · ' : ''}${soinsRythmeTexte(t.tousLesJours, t.heures)}',
            style: TytoText.ui(size: 12.5, color: encreA(0xb3)),
          ),
          Text(soinsPeriodeTexte(t.debut, t.fin), style: TytoText.ui(size: 12.5, color: encreA(0xb3))),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              children: [
                BoutonDiscretSoin('Modifier', onTap: () => _modifier(i)),
                const SizedBox(width: 6),
                BoutonDiscretSoin('Retirer', onTap: () => setState(() => _traitements.removeAt(i))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulaire() {
    return CarteSoin(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveau dossier de soin', style: TytoText.display(size: 18, color: TytoColors.encre)),
          if (widget.depuisOrdonnance) ...[
            const SizedBox(height: 10),
            const AlerteSoin(
              texte: "Les traitements viennent de l'ordonnance : les heures sont proposées par défaut. "
                  'Vérifie chaque ligne et ajuste les heures selon la prescription.',
              grave: false,
            ),
          ],

          if (widget.pets.length > 1) ...[
            const EtiquetteSoin('Pour qui ?'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final p in widget.pets)
                  PastilleSoin(
                    texte: p.name,
                    actif: _pet?.id == p.id,
                    onTap: () => setState(() => _pet = p),
                  ),
              ],
            ),
          ],

          const EtiquetteSoin('Quel problème ?'),
          ChampSoin(
            controller: _titre,
            indication: 'Conjonctivite, plaie à la patte…',
            onChanged: (_) => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final s in _suggestions)
                  PastilleSoin(
                    texte: s,
                    actif: _titre.text.trim() == s,
                    onTap: () => setState(() => _titre.text = s),
                  ),
              ],
            ),
          ),

          const EtiquetteSoin("Ce qu'a dit le vétérinaire (facultatif)"),
          ChampSoin(controller: _notes, indication: 'Revoir dans 10 jours si ça ne passe pas…'),

          const EtiquetteSoin('Traitements'),
          if (_traitements.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "Aucun traitement pour l'instant. Tu peux ouvrir le dossier sans traitement pour suivre "
                "simplement l'évolution jour après jour.",
                style: TytoText.ui(size: 13, color: encreA(0x99)),
              ),
            ),
          for (var i = 0; i < _traitements.length; i++) _carteTraitement(i),
          BoutonDiscretSoin('Ajouter un traitement', onTap: _ajouter),

          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_erreur!, style: TytoText.ui(size: 13, color: TytoColors.urgence)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: rangeeBoutonsSoin([
              BoutonOrSoin(
                _envoi ? 'Création…' : 'Ouvrir le dossier',
                onTap: _creer,
                actif: !_envoi,
                opaciteInactive: 0.6,
              ),
              BoutonDiscretSoin('Annuler', onTap: () => Navigator.pop(context)),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('Soins en cours', style: TytoText.display(size: 19))),
      body: Stack(
        children: [
          // Les empreintes qui traversent le fond, comme sur tout le site.
          const Positioned.fill(child: PawTrails()),
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const IntroSoins(),
                _formulaire(),
                avertissementSoins(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
