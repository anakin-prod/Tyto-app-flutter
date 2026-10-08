import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../services/auth_service.dart';
import '../services/soins_service.dart';
import '../services/user_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/account_gate.dart';
import '../widgets/drawer_navigation.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/tyto_icons.dart';
import '../widgets/tyto_tile.dart';
import 'nouveau_soin_screen.dart';
import 'soin_dossier_screen.dart';

/// « Soins en cours » : les prises du jour à cocher, et les dossiers de
/// soin ouverts (conjonctivite, plaie, traitement long…), chacun avec ses
/// traitements à heures fixes et le suivi de son évolution.
class SoinsScreen extends StatefulWidget {
  const SoinsScreen({super.key});

  @override
  State<SoinsScreen> createState() => _SoinsScreenState();
}

class _SoinsScreenState extends State<SoinsScreen> {
  SoinsEtat _etat = const SoinsEtat();
  List<Pet> _pets = [];
  bool _chargement = true;
  bool _erreur = false;
  bool _isPro = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!AuthService.isSignedIn) {
      setState(() => _chargement = false);
      return;
    }
    if (!silencieux) setState(() => _chargement = true);
    try {
      final token = AuthService.currentSession?.accessToken;
      if (token != null) {
        final profil = await UserService.fetchMe(token);
        if (mounted) {
          setState(() {
            _isPro = profil.pro;
            _isPremium = profil.premium;
          });
        }
      }
      final etat = await SoinsService.charger();
      final pets = await _chargerAnimaux();
      if (!mounted) return;
      setState(() {
        _etat = etat;
        _pets = pets;
        _chargement = false;
        _erreur = false;
      });
      // Les notifications suivent toujours l'état réel des soins.
      SoinsService.programmerDepuis(etat, pets);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  Future<List<Pet>> _chargerAnimaux() => SoinsService.animaux();

  String? _nomAnimal(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p.name;
    }
    return null;
  }

  Pet? _animal(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p;
    }
    return null;
  }

  Future<void> _nouveau() async {
    final cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NouveauSoinScreen(pets: _pets)),
    );
    if (cree == true) _charger(silencieux: true);
  }

  Future<void> _ouvrir(SoinDossier d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoinDossierScreen(dossierId: d.id)),
    );
    if (mounted) _charger(silencieux: true);
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

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

  // ---------- Morceaux d'écran ----------

  Widget _introduction() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TytoColors.nuit2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TytoColors.fauve.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TytoIcon.soins(size: 22, color: TytoColors.fauve),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Ne rate plus une prise', style: TytoText.display(size: 18)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Le vétérinaire prescrit des gouttes tous les soirs à 21 h ? Ouvre un dossier de soin : "
            "Tyto sonne à l'heure dite, tu coches « Fait », et tu notes chaque jour si ça va mieux. "
            "En cas de doute, tout est prêt à montrer au vétérinaire.",
            style: TytoText.body(size: 14.5, color: TytoColors.lune.withOpacity(0.85)).copyWith(height: 1.55),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _nouveau,
            icon: const Icon(Icons.add_rounded, size: 18, color: TytoColors.nuit),
            label: Text('Ouvrir un dossier de soin', style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit)),
            style: ElevatedButton.styleFrom(
              backgroundColor: TytoColors.fauve,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteDossier(SoinDossier d) {
    final nom = _nomAnimal(d.petId) ?? 'Ton compagnon';
    final pet = _animal(d.petId);
    final maintenant = DateTime.now();
    final suivi = _etat.suiviLe(d.id, aujourdhui());
    final alerte = _etat.alerte(d, nom);
    final prochaine = _etat.prochainePrise(d.id, maintenant);

    String lignePrise;
    if (prochaine != null) {
      final aujourdHui = prochaine.jour == aujourdhui();
      final demain = prochaine.jour == aujourdhui().add(const Duration(days: 1));
      final quand = aujourdHui
          ? "aujourd'hui"
          : demain
              ? 'demain'
              : 'le ${jourCourt(prochaine.jour)}';
      lignePrise = 'Prochaine prise : $quand à ${prochaine.heure}';
    } else {
      lignePrise = _etat.traitementsDe(d.id).isEmpty ? 'Suivi seul, sans traitement' : 'Plus de prise à venir';
    }

    return InkWell(
      onTap: () => _ouvrir(d),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TytoColors.nuit2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (alerte != null && alerte.grave ? TytoColors.urgence : TytoColors.lune).withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TytoColors.fauve.withOpacity(0.16),
                    border: Border.all(color: TytoColors.fauve.withOpacity(0.5)),
                  ),
                  alignment: Alignment.center,
                  child: SpeciesIcon(species: pet?.species ?? 'autre', size: 20, color: TytoColors.fauve),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.titre, style: TytoText.ui(size: 15.5, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('$nom · jour ${d.jourNumero}', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                    ],
                  ),
                ),
                if (suivi != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: couleurSuivi(suivi.etat).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconeSuivi(suivi.etat), size: 14, color: couleurSuivi(suivi.etat)),
                        const SizedBox(width: 4),
                        Text(libelleSuivi(suivi.etat),
                            style: TytoText.ui(size: 11.5, weight: FontWeight.w700, color: couleurSuivi(suivi.etat))),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 15, color: TytoColors.brume),
                const SizedBox(width: 6),
                Expanded(child: Text(lignePrise, style: TytoText.ui(size: 13, color: TytoColors.lune.withOpacity(0.8)))),
              ],
            ),
            if (suivi == null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 16, color: TytoColors.fauve),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text("Comment va $nom aujourd'hui ? Note-le dans le dossier.",
                        style: TytoText.ui(size: 12.5, color: TytoColors.fauve)),
                  ),
                ],
              ),
            ],
            if (alerte != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (alerte.grave ? TytoColors.urgence : TytoColors.fauve).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (alerte.grave ? TytoColors.urgence : TytoColors.fauve).withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: alerte.grave ? TytoColors.urgence : TytoColors.fauve),
                    const SizedBox(width: 8),
                    Expanded(child: Text(alerte.texte, style: TytoText.ui(size: 12.5, color: TytoColors.lune))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contenu() {
    final actifs = _etat.actifs;
    final aujourd = aujourdhui();
    final prises = _etat.occurrencesLe(aujourd);
    final multi = _pets.length > 1;
    final clos = _etat.clos.take(6).toList();

    return RefreshIndicator(
      color: TytoColors.fauve,
      backgroundColor: TytoColors.nuit2,
      onRefresh: () => _charger(silencieux: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (actifs.isEmpty) _introduction(),
          if (actifs.isNotEmpty) ...[
            titreSection("Aujourd'hui"),
            if (prises.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  "Aucune prise prévue aujourd'hui.",
                  style: TytoText.body(size: 14.5, color: TytoColors.brume),
                ),
              ),
            for (final o in prises)
              LignePriseSoin(
                occurrence: o,
                nomAnimal: multi ? _nomAnimal(o.traitement.petId) : null,
                onFait: () => _pointer(o),
                onPasser: () => _pointer(o, sauter: true),
                onAnnuler: () => _annuler(o),
              ),
            titreSection('Dossiers en cours'),
            for (final d in actifs) _carteDossier(d),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _nouveau,
              icon: const Icon(Icons.add_rounded, size: 18, color: TytoColors.fauve),
              label: Text('Nouveau dossier de soin', style: TytoText.ui(size: 14, color: TytoColors.fauve)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: TytoColors.fauve.withOpacity(0.55)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (clos.isNotEmpty) ...[
            titreSection('Terminés'),
            for (final d in clos)
              TytoTile(
                icon: Icons.check_circle_outline_rounded,
                title: d.titre,
                subtitle: '${_nomAnimal(d.petId) ?? 'Compagnon'} · du ${jourCourt(d.debut)} au ${jourLong(d.cloture ?? d.debut)}',
                accent: TytoColors.vert,
                onTap: () => _ouvrir(d),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: TytoDrawer(
        activeId: 'soins',
        onSelect: (id) => handleDrawerNavigation(context, 'soins', id),
        isPro: _isPro,
        isPremium: _isPremium,
      ),
      appBar: AppBar(
        title: Text('Soins en cours', style: TytoText.display(size: 19)),
        actions: [
          if (AuthService.isSignedIn && _pets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: TytoColors.fauve),
              tooltip: 'Nouveau dossier de soin',
              onPressed: _nouveau,
            ),
        ],
      ),
      body: !AuthService.isSignedIn
          ? const AccountGate()
          : _chargement
              ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
              : _erreur
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Impossible de charger les soins pour l'instant. Vérifie ta connexion.",
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
                  : _pets.isEmpty
                      ? const TytoEmptyState(
                          icon: Icons.medication_outlined,
                          message: "Ajoute d'abord un compagnon dans « Mes animaux »\npour suivre ses soins.",
                        )
                      : _contenu(),
    );
  }
}
