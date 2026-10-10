import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../services/auth_service.dart';
import '../services/soins_service.dart';
import '../services/user_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/account_gate.dart';
import '../widgets/drawer_navigation.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/paw_trails.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/tyto_drawer.dart';
import 'emergency_sheet.dart';
import 'nouveau_soin_screen.dart';
import 'soin_dossier_screen.dart';
import 'tableau_entete.dart';

/// « Soins en cours » (SoinsPanel du site) : la carte d'introduction, le
/// bouton « Ouvrir un dossier de soin », les prises du jour à cocher, les
/// dossiers en cours et les dossiers terminés. Un dossier s'ouvre dans
/// son propre écran (sur le site, il se déplie sur place).
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
  bool _tablesAbsentes = false; // erreurTables du site : script v8 pas encore passé
  bool _occupe = false;
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
      final pets = await SoinsService.animaux();
      if (!mounted) return;
      setState(() {
        _etat = etat;
        _pets = pets;
        _chargement = false;
        _erreur = false;
        _tablesAbsentes = false;
      });
      // Les notifications suivent toujours l'état réel des soins.
      SoinsService.programmerDepuis(etat, pets);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
        // Tables care_* absentes : le message du site sur le script v8.
        _tablesAbsentes = e.toString().contains('care_');
      });
    }
  }

  /// nomDe du site : le nom de l'animal, ou « Ton compagnon ».
  String _nomDe(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p.name;
    }
    return 'Ton compagnon';
  }

  Pet? _animal(String petId) {
    for (final p in _pets) {
      if (p.id == petId) return p;
    }
    return null;
  }

  // ---------- Actions ----------

  Future<void> _nouveau() async {
    final cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NouveauSoinScreen(pets: _pets)),
    );
    if (cree == true && mounted) _charger(silencieux: true);
  }

  Future<void> _ouvrir(SoinDossier d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoinDossierScreen(dossierId: d.id)),
    );
    if (mounted) _charger(silencieux: true);
  }

  Future<void> _pointer(SoinOccurrence o, {bool sauter = false}) async {
    if (_occupe) return;
    setState(() => _occupe = true);
    try {
      await SoinsService.pointer(o, sautee: sauter);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) messageSoin(context, "La prise n'a pas pu être enregistrée, réessaie.");
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _annuler(SoinOccurrence o) async {
    final prise = o.prise;
    if (prise == null || _occupe) return;
    setState(() => _occupe = true);
    try {
      await SoinsService.annulerPrise(prise.id);
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) messageSoin(context, "L'annulation n'a pas abouti, réessaie.");
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// « Résumé » d'un dossier terminé : le site le copie, l'application le
  /// partage (message, e-mail… ou copie depuis la feuille de partage). Le
  /// texte est celui du site, mot pour mot.
  Future<void> _resume(SoinDossier d) async {
    final nom = _nomDe(d.petId);
    final texte = soinsResume(_etat, d, nom, _animal(d.petId), DateTime.now());
    await Share.share(texte, subject: 'Suivi de $nom — ${d.titre}');
  }

  /// Le bouton URGENCE de l'en-tête du site.
  void _ouvrirUrgence() {
    final Pet? p = _pets.isNotEmpty ? _pets.first : null;
    EmergencySheet.ouvrir(context, petId: p?.id, petName: p?.name, petWeight: p?.weightKg);
  }

  Future<void> _supprimer(SoinDossier d) async {
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
      await _charger(silencieux: true);
    } catch (e) {
      if (mounted) messageSoin(context, "La suppression n'a pas abouti, réessaie.");
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  // ---------- Morceaux d'écran ----------

  /// Un dossier en cours (replié, comme sur le site) : un toucher l'ouvre.
  Widget _carteDossier(SoinDossier d) {
    final nom = _nomDe(d.petId);
    final suivis = _etat.suivisDe(d.id);
    final alerte = _etat.alerte(d, nom);
    return CarteSoin(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnteteDossierSoin(
            titre: d.titre,
            ligne: soinsLigneDossier(_etat, d, nom),
            dernier: suivis.isNotEmpty ? suivis.first : null,
            deplie: false,
            onTap: () => _ouvrir(d),
          ),
          if (alerte != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _ouvrir(d),
              child: AlerteSoin(texte: alerte.texte, grave: alerte.grave),
            ),
          ],
        ],
      ),
    );
  }

  /// Un dossier terminé : titre, animal et dates, « Résumé », « Supprimer ».
  Widget _carteTermine(SoinDossier d) {
    return CarteSoin(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _ouvrir(d),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.titre, style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.encre)),
                  Text(soinsLigneTermine(d, _nomDe(d.petId)), style: TytoText.ui(size: 12.5, color: encreA(0x99))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          BoutonDiscretSoin('Résumé', onTap: () => _resume(d)),
          const SizedBox(width: 10),
          BoutonDiscretSoin('Supprimer', onTap: () => _supprimer(d)),
        ],
      ),
    );
  }

  Widget _contenu() {
    final actifs = _etat.actifs;
    final clos = _etat.clos.take(10).toList();
    final prises = soinsDuJour(_etat, DateTime.now());

    final enfants = <Widget>[const IntroSoins()];

    if (_pets.isEmpty) {
      enfants.add(Text(
        "Crée d'abord le profil d'un compagnon pour ouvrir un dossier de soin.",
        style: TytoText.ui(size: 14, color: TytoColors.brume),
      ));
    } else {
      enfants.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: double.infinity,
          child: BoutonOrSoin('Ouvrir un dossier de soin', onTap: _nouveau),
        ),
      ));
    }

    // Aujourd'hui : toutes les prises du jour, dans une seule carte.
    if (prises.isNotEmpty) {
      enfants.add(titreSection("Aujourd'hui", haut: 6));
      enfants.add(CarteSoin(
        child: Column(
          children: [
            for (var i = 0; i < prises.length; i++)
              LignePriseSoin(
                occurrence: prises[i],
                nomAnimal: _nomDe(prises[i].traitement.petId),
                trait: i > 0,
                onFait: () => _pointer(prises[i]),
                onPasser: () => _pointer(prises[i], sauter: true),
                onAnnuler: () => _annuler(prises[i]),
              ),
          ],
        ),
      ));
    }

    // Dossiers en cours. Les marges du site se fondent : après une carte
    // (12 px dessous), le titre n'ajoute rien ; sinon il ajoute ses 10 px.
    enfants.add(titreSection('Dossiers en cours', haut: prises.isNotEmpty ? 0 : 10));
    if (actifs.isEmpty) {
      enfants.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          'Aucun dossier ouvert. Quand le vétérinaire prescrit un traitement, ouvre un dossier : '
          'Tyto garde les heures et le suivi.',
          style: TytoText.ui(size: 14, color: TytoColors.brume),
        ),
      ));
    }
    for (final d in actifs) {
      enfants.add(_carteDossier(d));
    }

    // Terminés (16 px au-dessus : 12 + 4 après une carte, 14 + 2 après le texte).
    var apresCarte = actifs.isNotEmpty;
    if (clos.isNotEmpty) {
      enfants.add(titreSection('Terminés', haut: apresCarte ? 4 : 2));
      for (final d in clos) {
        enfants.add(_carteTermine(d));
      }
      apresCarte = true;
    }

    // La phrase du bas (18 px au-dessus).
    enfants.add(avertissementSoins(haut: apresCarte ? 6 : 4));

    return RefreshIndicator(
      color: TytoColors.fauve,
      backgroundColor: TytoColors.nuit2,
      onRefresh: () => _charger(silencieux: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: enfants,
      ),
    );
  }

  /// Les tables absentes : la carte du site (« pas encore activée… script
  /// v8 »). Sinon (pas de réseau…), propre à l'application : le même
  /// habillage, un texte sur la connexion et « Réessayer ».
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
                _tablesAbsentes
                    ? "Cette rubrique n'est pas encore activée sur ce compte. Le script Supabase « v8 – soins » doit d'abord être exécuté."
                    : "Impossible de charger les soins pour l'instant. Vérifie ta connexion.",
                style: TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.55),
              ),
              if (!_tablesAbsentes) ...[
                const SizedBox(height: 12),
                BoutonDiscretSoin('Réessayer', onTap: () => _charger()),
              ],
            ],
          ),
        ),
      ],
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
      // L'en-tête du site, le même sur toutes les rubriques.
      appBar: EnteteSite.pour(
        context,
        isPro: _isPro,
        isPremium: _isPremium,
        onUrgence: _ouvrirUrgence,
      ),
      body: Stack(
        children: [
          // Les empreintes qui traversent le fond, comme sur tout le site.
          const Positioned.fill(child: PawTrails()),
          Positioned.fill(
            child: !AuthService.isSignedIn
                ? const AccountGate()
                : _chargement
                    // Le texte d'attente du site n'est pas dans le bloc à 16 px
                    // du haut : 8 px (main) + ses 24 px.
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [chargementSoins()],
                      )
                    : _erreur
                        ? _erreurChargement()
                        : _contenu(),
          ),
        ],
      ),
    );
  }
}
