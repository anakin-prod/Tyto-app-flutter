import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/health_event.dart';
import '../models/pet.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/account_gate.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/paw_trails.dart';
import '../widgets/site_icons.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/drawer_navigation.dart';
import '../services/user_service.dart';
import 'carnet_screen.dart';
import 'emergency_sheet.dart';
import 'pets_screen.dart';
import 'tableau_entete.dart';
import 'tableau_site.dart';

/// Le tableau de bord du site : compteurs en pastilles, puis les rappels
/// de tous les compagnons rangés par échéance (en retard, cette semaine,
/// dans le mois, plus tard) et les pesées à prévoir.
class TableauScreen extends StatefulWidget {
  const TableauScreen({super.key});

  @override
  State<TableauScreen> createState() => _TableauScreenState();
}

/// Un compagnon à peser : jamais pesé, ou pas depuis plus de 90 jours.
class _Pesee {
  final Pet pet;
  final DateTime? derniere;
  final int? jours;
  const _Pesee(this.pet, this.derniere, this.jours);
}

class _TableauScreenState extends State<TableauScreen> {
  List<HealthEvent> _events = [];
  Map<String, int> _recurrences = {};
  List<Pet> _pets = [];
  bool _loading = true;
  bool _isPro = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silencieux = false}) async {
    if (!AuthService.isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    if (!silencieux) setState(() => _loading = true);
    final token = AuthService.currentSession?.accessToken;
    if (token != null) {
      final profil = await UserService.fetchMe(token);
      if (mounted) setState(() { _isPro = profil.pro; _isPremium = profil.premium; });
    }
    try {
      // Tout le carnet de chaque compagnon (comme loadAllEvents du site),
      // y compris les rappels déjà dépassés.
      final pets = await DataService.loadPets();
      final parAnimal = await Future.wait(pets.map((p) => DataService.loadEvents(p.id)));
      final recurrences = await CarnetDonnees.recurrences();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _events = [for (final liste in parAnimal) ...liste];
        _recurrences = recurrences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _marquerFait(HealthEvent ev) async {
    try {
      await CarnetDonnees.marquerFait(ev, _recurrences[ev.id]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("L'enregistrement n'a pas abouti, réessaie.")),
        );
      }
      return;
    }
    await _load(silencieux: true);
  }

  /// Le bouton URGENCE de l'en-tête : comme sur le site, la fenêtre
  /// d'urgence connaît le compagnon actif (le premier, par défaut).
  void _ouvrirUrgence() {
    final Pet? p = _pets.isNotEmpty ? _pets.first : null;
    EmergencySheet.ouvrir(context, petId: p?.id, petName: p?.name, petWeight: p?.weightKg);
  }

  String _nomAnimal(String id) {
    for (final p in _pets) {
      if (p.id == id) return p.name;
    }
    return '?';
  }

  List<HealthEvent> _filtrer(bool Function(int jours) garder) {
    final liste = _events.where((e) => e.nextDue != null && garder(joursAvant(e.nextDue!))).toList();
    liste.sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    return liste;
  }

  List<_Pesee> get _peseesAPrevoir {
    final resultat = <_Pesee>[];
    for (final p in _pets) {
      DateTime? derniere;
      for (final e in _events) {
        if (e.petId == p.id && e.type == 'poids' && (derniere == null || e.eventDate.isAfter(derniere))) {
          derniere = e.eventDate;
        }
      }
      final jours = derniere == null ? null : -joursAvant(derniere);
      if (jours == null || jours > 90) resultat.add(_Pesee(p, derniere, jours));
    }
    return resultat;
  }

  // ---------- Les éléments du tableau ----------

  /// Une pastille de compteur : padding 6 / 13, 13 px, bord d'1 px.
  Widget _pastille({Widget? icone, required String texte, bool alerte = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: alerte ? const Color(0x2E8A3A2E) : TytoColors.lune.withAlpha(0x0d),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: alerte ? const Color(0xAAC96A55) : TytoColors.lune.withAlpha(0x26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[icone, const SizedBox(width: 6)],
          Text(texte, style: TytoText.ui(size: 13, color: TytoColors.lune)),
        ],
      ),
    );
  }

  /// Les petits titres dorés (dashTitle) : 11 px gras, espacés de 0,18 em.
  Widget _titre(String texte) {
    return Text(
      texte.toUpperCase(),
      style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.fauve).copyWith(letterSpacing: 1.98),
    );
  }

  /// Une ligne de rappel (dashRow) : rouge en retard, dorée cette
  /// semaine, neutre ensuite.
  Widget _ligne(HealthEvent ev, String ton) {
    final d = joursAvant(ev.nextDue!);
    final quand = d < 0
        ? 'en retard de ${-d} j'
        : d == 0
            ? "aujourd'hui"
            : 'dans $d j';
    final fond = ton == 'retard'
        ? const Color(0x2E8A3A2E)
        : ton == 'semaine'
            ? TytoColors.fauve.withAlpha(0x26)
            : TytoColors.lune.withAlpha(0x0d);
    final bord = ton == 'retard'
        ? const Color(0xAAC96A55)
        : ton == 'semaine'
            ? TytoColors.fauve.withAlpha(0x88)
            : TytoColors.lune.withAlpha(0x26);
    const brume = TextStyle(color: TytoColors.brume);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bord),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: ev.libelle,
                    style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: TytoColors.lune),
                  ),
                  TextSpan(text: ' · ${_nomAnimal(ev.petId)} — ${dateFr(ev.nextDue!)} '),
                  TextSpan(text: '($quand)', style: brume),
                  if (_recurrences[ev.id] != null) const TextSpan(text: ' · récurrent', style: brume),
                ],
              ),
              style: interligne(TytoText.ui(size: 13.5, color: TytoColors.lune), 1.4),
            ),
          ),
          const SizedBox(width: 8),
          BoutonFait(onTap: () => _marquerFait(ev)),
        ],
      ),
    );
  }

  /// Une pesée à prévoir : toute la ligne ouvre le carnet du compagnon.
  Widget _lignePesee(_Pesee a) {
    final style = TytoText.ui(size: 13.5, color: TytoColors.lune);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CarnetScreen(pet: a.pet)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: TytoColors.lune.withAlpha(0x0d),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TytoColors.lune.withAlpha(0x26)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  SiteIcon.espece(a.pet.species, size: 14, color: TytoColors.lune),
                  const SizedBox(width: 7),
                  Text(a.pet.name, style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: TytoColors.lune)),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      a.derniere == null ? '— jamais pesé(e)' : '— dernière pesée il y a ${a.jours} j',
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('Ouvrir ›', style: style.copyWith(color: TytoColors.brume)),
          ],
        ),
      ),
    );
  }

  /// Pas encore de compagnon : la carte du site avec son bouton doré, qui
  /// ouvre directement le formulaire « Nouveau compagnon ».
  Widget _carteSansAnimal() {
    return FenetrePapier(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Text(
            'Le tableau de bord regroupe rappels et alertes de tous tes compagnons — parfait dès que tu en as plusieurs. Commence par en ajouter un !',
            textAlign: TextAlign.center,
            style: interligne(TytoText.body(size: 15.5, color: TytoColors.encre), 1.55),
          ),
          const SizedBox(height: 14),
          TableauBouton(
            fond: TytoColors.fauve,
            echellePresse: 0.98,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PetsScreen(nouveauCompagnon: true)),
            ),
            child: libelleBouton(
              icone: const SiteIcon('IconPlus', size: 14, color: TytoColors.nuit),
              ecart: 6,
              texte: 'Ajouter un compagnon',
              taille: 14.5,
              couleur: TytoColors.nuit,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contenu() {
    if (_pets.isEmpty) return [_carteSansAnimal()];
    final retard = _filtrer((d) => d < 0);
    final semaine = _filtrer((d) => d >= 0 && d <= 7);
    final mois = _filtrer((d) => d > 7 && d <= 30);
    final tard = _filtrer((d) => d > 30);
    final pesees = _peseesAPrevoir;
    final n = _pets.length;
    final rien = retard.isEmpty && semaine.isEmpty && mois.isEmpty && tard.isEmpty && pesees.isEmpty;

    // Les marges verticales du site se chevauchent (la plus grande des
    // deux l'emporte) : 6 px sous une ligne puis 16 px au-dessus d'un
    // titre font 16 px, pas 22.
    final enfants = <Widget>[];
    double enAttente = 0;
    void ajouter(Widget w, {double haut = 0, double bas = 0}) {
      final ecart = haut > enAttente ? haut : enAttente;
      if (ecart > 0) enfants.add(SizedBox(height: ecart));
      enfants.add(w);
      enAttente = bas;
    }

    ajouter(Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pastille(
          icone: const SiteIcon('IconPaw', size: 13, color: TytoColors.lune),
          texte: '$n compagnon${n > 1 ? 's' : ''}',
        ),
        _pastille(texte: '${retard.length + semaine.length} cette semaine'),
        if (retard.isNotEmpty)
          _pastille(
            icone: const SiteIcon('IconAlert', size: 13, color: TytoColors.lune),
            texte: '${retard.length} en retard',
            alerte: true,
          ),
      ],
    ));

    if (rien) {
      ajouter(
        FenetrePapier(
          child: Text(
            'Tout est à jour. Belle journée pour la meute !',
            textAlign: TextAlign.center,
            style: TytoText.body(size: 15.5, color: TytoColors.encre),
          ),
        ),
        haut: 16,
      );
    }

    void section(String titre, List<HealthEvent> liste, String ton) {
      if (liste.isEmpty) return;
      ajouter(_titre(titre), haut: 16, bas: 6);
      for (final ev in liste) {
        ajouter(_ligne(ev, ton), bas: 6);
      }
    }

    section('En retard', retard, 'retard');
    section('Cette semaine', semaine, 'semaine');
    section('Dans le mois', mois, 'mois');
    section('Plus tard', tard, 'mois');
    if (pesees.isNotEmpty) {
      ajouter(_titre('Pesées à prévoir'), haut: 16, bas: 6);
      for (final a in pesees) {
        ajouter(_lignePesee(a), bas: 6);
      }
    }
    if (enAttente > 0) enfants.add(SizedBox(height: enAttente));
    return enfants;
  }

  Widget _corps() {
    if (!AuthService.isSignedIn) return const AccountGate();
    if (_loading) return const Center(child: CircularProgressIndicator(color: TytoColors.fauve));
    return RefreshIndicator(
      color: TytoColors.fauve,
      backgroundColor: TytoColors.nuit2,
      onRefresh: () => _load(silencieux: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Comme le site : 8 px sous l'en-tête + 16 px, 16 px sur les côtés,
        // 24 px en bas, contenu limité à 720 px de large (688 + marges).
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 688),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _contenu(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: TytoDrawer(
        activeId: 'tableau',
        onSelect: (id) => handleDrawerNavigation(context, 'tableau', id),
        isPro: _isPro,
        isPremium: _isPremium,
      ),
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
          Positioned.fill(child: _corps()),
        ],
      ),
    );
  }
}
