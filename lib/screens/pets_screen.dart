import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/account_gate.dart';
import '../widgets/site_icons.dart';
import '../widgets/animaux_styles.dart';
import '../widgets/paw_trails.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/drawer_navigation.dart';
import '../services/user_service.dart';
import 'behaviors_sheet.dart';
import 'breed_sheet.dart';
import '../data/breeds.dart';
import 'emergency_sheet.dart';
import 'lost_pet_screen.dart';
import 'tableau_entete.dart';

// Les mêmes espèces que sur le site (SPECIES), avec leurs libellés.
const _especes = <(String, String)>[
  ('chien', 'Chien'),
  ('chat', 'Chat'),
  ('lapin', 'Lapin'),
  ('oiseau', 'Oiseau'),
  ('rongeur', 'Rongeur'),
  ('reptile', 'Reptile'),
  ('poisson', 'Poisson'),
  ('cheval', 'Cheval'),
  ('autre', 'Autre'),
];

// Les teintes d'encre du site, avec leur transparence exacte
// (ENCRE + "99", "aa", "88", "77", "33", "26").
const _encre60 = Color(0x992A2118);
const _encre67 = Color(0xAA2A2118);
const _encre53 = Color(0x882A2118);
const _encre20 = Color(0x332A2118);
const _placeholder = Color(0xFF757575); // couleur par défaut des champs vides du navigateur
const _rougeSupprimer = Color(0xFFAA3333); // #a33

// Les deux petits dessins écrits directement dans la fiche du site (sans
// passer par Icons.js) : la croix « race » et la gamelle.
const _icoCroixRace = '<path d="M12 5v14M5 12h14" />';
const _icoGamelle = '<path d="M3.5 11h17c0 4.6-3.5 8-8.5 8s-8.5-3.4-8.5-8z" />'
    '<path d="M9 7c0-1 .8-1.3.8-2.3M15 7c0-1 .8-1.3.8-2.3" />';

// Le calendrier et la flèche que le navigateur dessine dans les champs
// « date » et « liste » du formulaire.
const _svgCalendrier = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 11 12">'
    '<rect x="0.75" y="2.25" width="9.5" height="9" rx="1.25" fill="none" stroke="#000" stroke-width="1.5"/>'
    '<rect x="0.75" y="2.25" width="9.5" height="2.6" fill="#000"/>'
    '<path d="M3 0.6v2.2M8 0.6v2.2" stroke="#000" stroke-width="1.3" stroke-linecap="round"/></svg>';
const _svgChevron = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 6">'
    '<path d="M1 1l4 4 4-4" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const _svgCoche = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 13 13">'
    '<path d="M3 6.8l2.4 2.4L10.2 4" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';

Widget _trace(String inner, {required double size, required Color color, double strokeWidth = 1.6, bool joinRond = true}) {
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
    'stroke-width="$strokeWidth" stroke-linecap="round"${joinRond ? ' stroke-linejoin="round"' : ''}>$inner</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// L'âge comme sur le site (ageOf) : en mois avant un an, puis en années.
String? _ageDe(DateTime? naissance) {
  if (naissance == null) return null;
  final now = DateTime.now();
  final mois = (now.year - naissance.year) * 12 + (now.month - naissance.month);
  if (mois < 0) return null;
  if (mois < 12) return '$mois mois';
  final ans = mois ~/ 12;
  return '$ans an${ans > 1 ? 's' : ''}';
}

/// Le poids écrit comme le navigateur l'écrit : « 23 » et non « 23.0 ».
String _kg(double w) => w == w.truncateToDouble() ? w.toInt().toString() : w.toString();

/// La page du guide « Peut-il manger ça ? » qui correspond à l'espèce.
/// Les espèces sans page dédiée arrivent sur la liste générale.
String _guideAliments(String espece) {
  const avecGuide = ['chien', 'chat', 'lapin', 'oiseau', 'cheval', 'poisson'];
  return avecGuide.contains(espece) ? '/aliments/$espece' : '/aliments';
}

class PetsScreen extends StatefulWidget {
  /// true : arrive directement sur le formulaire « Nouveau compagnon »,
  /// comme les boutons « Créer son profil » / « Ajouter un compagnon »
  /// des autres rubriques du site.
  final bool nouveauCompagnon;
  const PetsScreen({super.key, this.nouveauCompagnon = false});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  List<Pet> _pets = [];
  bool _loading = true;
  bool _isPro = false;
  bool _isPremium = false;

  // Le formulaire s'affiche à la place de la liste, comme sur le site.
  bool _formOuvert = false;
  Pet? _petEdite;

  @override
  void initState() {
    super.initState();
    _formOuvert = widget.nouveauCompagnon;
    _load();
  }

  /// [silencieux] : comme loadPets() sur le site, la liste affichée reste
  /// en place pendant le rechargement (après un enregistrement, une
  /// suppression ou un « tirer pour actualiser ») ; seul le tout premier
  /// chargement montre l'indicateur d'attente.
  Future<void> _load({bool silencieux = false}) async {
    final token = AuthService.currentSession?.accessToken;
    if (token != null) {
      final profil = await UserService.fetchMe(token);
      if (mounted) setState(() { _isPro = profil.pro; _isPremium = profil.premium; });
    }
    if (!mounted) return;
    if (!silencieux) setState(() => _loading = true);
    try {
      final pets = await DataService.loadPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de charger tes compagnons pour l'instant.")),
      );
    }
  }

  void _ouvrirFormulaire([Pet? pet]) {
    setState(() {
      _formOuvert = true;
      _petEdite = pet;
    });
  }

  void _fermerFormulaire() {
    setState(() {
      _formOuvert = false;
      _petEdite = null;
    });
  }

  Future<void> _supprimer(Pet pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        surfaceTintColor: Colors.transparent,
        title: Text('Supprimer ce compagnon et tout son carnet ?', style: TytoText.display(size: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Supprimer', style: TytoText.ui(color: TytoColors.urgence, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DataService.deletePet(pet.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La suppression n'a pas abouti, réessaie.")),
      );
      return;
    }
    if (!mounted) return;
    if (_formOuvert) _fermerFormulaire();
    _load(silencieux: true);
  }

  /// Le bouton URGENCE de l'en-tête : comme sur le site, la fenêtre
  /// d'urgence connaît le compagnon (le premier, par défaut).
  void _ouvrirUrgence() {
    final Pet? p = _pets.isNotEmpty ? _pets.first : null;
    EmergencySheet.ouvrir(context, petId: p?.id, petName: p?.name, petWeight: p?.weightKg);
  }

  @override
  Widget build(BuildContext context) {
    // Le retour arrière referme d'abord le formulaire, comme « Annuler ».
    return PopScope<Object?>(
      canPop: !_formOuvert,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _formOuvert) _fermerFormulaire();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: TytoDrawer(
          activeId: 'pets',
          onSelect: (id) => handleDrawerNavigation(context, 'pets', id),
          isPro: _isPro,
          isPremium: _isPremium,
        ),
        // L'en-tête du site, le même sur toutes les rubriques (menu,
        // chouette, « Tyto », badge du plan, URGENCE) : la rubrique
        // « Mes animaux » n'a pas de titre à elle sur le site.
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
      ),
    );
  }

  Widget _corps() {
    if (!AuthService.isSignedIn) return const AccountGate();

    // Marges du site : 8 px (contenu) + 16 px (rubrique) en haut, 24 en
    // bas, 16 sur les côtés ; le contenu ne dépasse pas 720 px de large
    // (688 + marges), centré, comme sur une tablette ou un grand écran.
    final largeur = MediaQuery.sizeOf(context).width;
    final cote = largeur > 720 ? (largeur - 688) / 2 : 16.0;
    final marges = EdgeInsets.fromLTRB(cote, 24, cote, 24);

    if (_formOuvert) {
      final edite = _petEdite;
      return SingleChildScrollView(
        padding: marges,
        child: _PetForm(
          key: ValueKey(edite?.id ?? 'nouveau'),
          pet: edite,
          onSaved: () {
            _fermerFormulaire();
            _load(silencieux: true);
          },
          onCancel: _fermerFormulaire,
          onDelete: edite == null ? null : () => _supprimer(edite),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: TytoColors.fauve));
    }

    return RefreshIndicator(
      color: TytoColors.fauve,
      backgroundColor: TytoColors.nuit2,
      onRefresh: () => _load(silencieux: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: marges,
        children: [
          if (_pets.isEmpty) _etatVide(),
          for (final p in _pets) _carte(p),
          // marginTop 4 sous la dernière carte (qui a déjà 10 de marge basse)
          const SizedBox(height: 4),
          // Sur le site, l'icône et le texte forment un bloc aligné sur la
          // ligne de base : le bouton fait 41,5 px de haut, le bloc collé
          // en haut (11 px) et 13,5 px dessous.
          _BoutonOr(
            onTap: () => _ouvrirFormulaire(),
            padding: const EdgeInsets.fromLTRB(22, 11, 22, 13.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SiteIcon('IconPlus', size: 14, color: TytoColors.nuit),
                const SizedBox(width: 6),
                Text('Ajouter un compagnon', style: karla(14.5, poids: FontWeight.w700, couleur: TytoColors.nuit)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La carte d'accueil quand aucun compagnon n'est encore créé.
  Widget _etatVide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: decorationPapier,
      child: Column(
        children: [
          const SiteIcon('IconPaw', size: 32, color: TytoColors.nuit),
          // marginBottom 4 de l'icône et marginTop 8 du titre se
          // confondent en 8 px, comme dans le navigateur.
          const SizedBox(height: 8),
          Text('Présente-moi ton compagnon', textAlign: TextAlign.center, style: fraunces(19)),
          const SizedBox(height: 6),
          Text(
            'Une fois son profil créé, chaque réponse de Tyto sera personnalisée '
            'pour lui : son espèce, son âge, son poids, ses allergies.',
            textAlign: TextAlign.center,
            style: newsreader(15, interligne: 1.55),
          ),
        ],
      ),
    );
  }

  /// La fiche d'un compagnon, sur papier ivoire comme sur le site.
  Widget _carte(Pet p) {
    final age = _ageDe(p.birthdate);
    final details = <String>[
      if (p.breed != null && p.breed!.trim().isNotEmpty) p.breed!,
      if (age != null) age,
      if (p.weightKg != null && p.weightKg != 0) '${_kg(p.weightKg!)} kg',
      if (p.allergies != null && p.allergies!.trim().isNotEmpty) 'allergies connues',
    ];

    return GestureDetector(
      onLongPress: () => _supprimer(p),
      onTap: () => _ouvrirFormulaire(p),
      child: _FicheEnfoncable(
        child: Row(
          children: [
            Opacity(
              opacity: 0.8,
              child: SiteIcon.espece(p.species, size: 28, color: TytoColors.nuit),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: fraunces(17)),
                  Text(
                    details.isEmpty ? p.species : details.join(' · '),
                    style: karla(12.5, couleur: _encre60, interligne: 1.5),
                  ),
                  const SizedBox(height: 4),
                  // gap: 14 du site : le même écart entre les liens et entre les lignes.
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _lien(
                        icone: const SiteIcon('IconBulb', size: 11, color: _encre67),
                        texte: 'Pourquoi il fait ça ?',
                        couleur: _encre67,
                        onTap: () => BehaviorsSheet.afficher(context, p),
                      ),
                      // Seulement si la race est reconnue dans ce que tu as saisi.
                      if (racePourAnimal(p.species, p.breed) != null)
                        _lien(
                          icone: _trace(_icoCroixRace, size: 11, color: _encre67, strokeWidth: 2.2, joinRond: false),
                          texte: titreRace,
                          couleur: _encre67,
                          onTap: () => BreedSheet.afficher(context, p),
                        ),
                      _lien(
                        icone: _trace(_icoGamelle, size: 11, color: _encre67, strokeWidth: 2.2),
                        texte: 'Peut-il manger ça ?',
                        couleur: _encre67,
                        pointille: false,
                        onTap: () => launchUrl(
                          Uri.parse('https://tytoai.app${_guideAliments(p.species)}'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _lien(
                        icone: const SiteIcon('IconAlert', size: 11, color: TytoColors.urgence),
                        texte: 'SOS il a disparu',
                        couleur: TytoColors.urgence,
                        onTap: () => LostPetScreen.ouvrir(context, p),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _ouvrirFormulaire(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _encre20),
                ),
                child: Text('Modifier', style: karla(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Un petit lien souligné de la fiche (pointillé, sauf « Peut-il manger ça ? »).
  Widget _lien({
    required Widget icone,
    required String texte,
    required Color couleur,
    required VoidCallback onTap,
    bool pointille = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icone,
          const SizedBox(width: 4),
          Text(
            texte,
            style: karla(11.5, couleur: couleur).copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: pointille ? TextDecorationStyle.dotted : TextDecorationStyle.solid,
              decorationColor: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// La fiche papier d'un compagnon. Comme .pet-card:active sur le site,
/// elle se soulève d'1 px tant que le doigt est posé dessus (transition
/// de 0,16 s) ; le survol n'existe pas sur téléphone.
class _FicheEnfoncable extends StatefulWidget {
  final Widget child;
  const _FicheEnfoncable({required this.child});

  @override
  State<_FicheEnfoncable> createState() => _FicheEnfoncableState();
}

class _FicheEnfoncableState extends State<_FicheEnfoncable> {
  bool _appui = false;

  void _poser(bool v) {
    if (_appui != v) setState(() => _appui = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _poser(true),
      onPointerUp: (_) => _poser(false),
      onPointerCancel: (_) => _poser(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.ease,
        transform: Matrix4.translationValues(0.0, _appui ? -1.0 : 0.0, 0.0),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: decorationPapier,
        child: widget.child,
      ),
    );
  }
}

/// Le bouton doré du site (goldBtn) : pilule fauve, texte nuit en gras,
/// qui s'enfonce légèrement à l'appui (.gold:active).
class _BoutonOr extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double opacite;
  final double? hauteur;
  final EdgeInsets padding;
  const _BoutonOr({
    required this.child,
    this.onTap,
    this.opacite = 1,
    this.hauteur,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
  });

  @override
  State<_BoutonOr> createState() => _BoutonOrState();
}

class _BoutonOrState extends State<_BoutonOr> {
  bool _appui = false;

  void _poser(bool v) {
    if (widget.onTap == null || _appui == v) return;
    setState(() => _appui = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _poser(true),
      onTapUp: (_) => _poser(false),
      onTapCancel: () => _poser(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _appui ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Opacity(
          opacity: widget.opacite,
          child: Container(
            height: widget.hauteur,
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TytoColors.fauve,
              borderRadius: BorderRadius.circular(999),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// La case à cocher telle que le navigateur l'affiche sur le site.
class _CaseNative extends StatelessWidget {
  final bool coche;
  const _CaseNative({required this.coche});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: coche ? const Color(0xFF0075FF) : Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: coche ? null : Border.all(color: const Color(0xFF767676)),
      ),
      child: coche ? SvgPicture.string(_svgCoche, width: 13, height: 13) : null,
    );
  }
}

/// Le formulaire d'ajout / modification d'un compagnon (PetForm du site),
/// affiché sur une carte papier à la place de la liste.
class _PetForm extends StatefulWidget {
  final Pet? pet;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;
  const _PetForm({
    super.key,
    this.pet,
    required this.onSaved,
    required this.onCancel,
    this.onDelete,
  });

  @override
  State<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends State<_PetForm> {
  late TextEditingController _name;
  late TextEditingController _breed;
  late TextEditingController _allergies;
  late TextEditingController _conditions;
  String _species = 'chien';
  String? _sex; // null, 'male' ou 'femelle' — comme sur le site
  DateTime? _birthdate;
  bool _sterilized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pet?.name ?? '');
    _breed = TextEditingController(text: widget.pet?.breed ?? '');
    _allergies = TextEditingController(text: widget.pet?.allergies ?? '');
    _conditions = TextEditingController(text: widget.pet?.conditions ?? '');
    _species = widget.pet?.species ?? 'chien';
    _sex = widget.pet?.sex;
    _birthdate = widget.pet?.birthdate;
    _sterilized = widget.pet?.sterilized ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  bool get _nomValide => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    // Comme sur le site : sans nom, le bouton (à demi transparent) ne fait rien.
    if (!_nomValide || _saving) return;
    setState(() => _saving = true);
    try {
      await DataService.savePet(
        id: widget.pet?.id,
        name: _name.text,
        species: _species,
        breed: _breed.text,
        sex: _sex,
        birthdate: _birthdate,
        // Le poids ne se saisit pas ici, comme sur le site : il vient des
        // pesées du carnet. On renvoie donc la valeur actuelle, inchangée.
        weightKg: widget.pet?.weightKg,
        sterilized: _sterilized,
        allergies: _allergies.text,
        conditions: _conditions.text,
      );
      if (mounted) widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'enregistrement n'a pas abouti, réessaie.")),
      );
    }
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final premier = DateTime(1990);
    final b = _birthdate;
    final initiale = (b != null && !b.isBefore(premier) && !b.isAfter(maintenant)) ? b : maintenant;
    final picked = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: premier,
      lastDate: maintenant,
    );
    if (picked != null && mounted) setState(() => _birthdate = picked);
  }

  // labelStyle du site : 11 px, gras, capitales espacées, encre 60 %,
  // marges 10 au-dessus et 4 en dessous.
  Widget _etiquette(String texte) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          texte,
          style: karla(11, poids: FontWeight.w700, couleur: _encre60).copyWith(letterSpacing: 0.88),
        ),
      );

  OutlineInputBorder _bord(Color couleur, double epaisseur) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: couleur, width: epaisseur),
      );

  // fieldStyle du site : fond blanc, bord encre 20 %, rayon 10, padding 9/12
  // (+ 1 px de bord). Le texte d'exemple tient sur une ligne, comme dans un
  // <input> ; celui du <textarea> peut passer à la ligne ([lignesIndication]).
  InputDecoration _dec(
    String hint, {
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    int lignesIndication = 1,
  }) =>
      InputDecoration(
        isDense: true,
        hintText: hint,
        hintMaxLines: lignesIndication,
        hintStyle: karla(14.5, couleur: _placeholder),
        filled: true,
        fillColor: Colors.white,
        contentPadding: padding,
        border: _bord(_encre20, 1),
        enabledBorder: _bord(_encre20, 1),
        focusedBorder: _bord(TytoColors.fauve, 2),
      );

  TextStyle get _styleChamp => karla(14.5);

  Widget _champ(TextEditingController c, String hint) => TextField(
        controller: c,
        cursorColor: TytoColors.encre,
        style: _styleChamp,
        decoration: _dec(hint),
      );

  @override
  Widget build(BuildContext context) {
    final poids = widget.pet?.weightKg;
    final valeurSexe = (_sex == 'male' || _sex == 'femelle') ? _sex! : '';
    final b = _birthdate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: decorationPapier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sa marge basse (4) se confond avec les 10 px de l'étiquette suivante.
          Text(
            widget.pet == null ? 'Nouveau compagnon' : 'Modifier ${_name.text}',
            style: fraunces(19),
          ),

          _etiquette('SON NOM *'),
          TextField(
            controller: _name,
            cursorColor: TytoColors.encre,
            style: _styleChamp,
            decoration: _dec('Max, Plume, Caramel…'),
            onChanged: (_) => setState(() {}),
          ),

          _etiquette('ESPÈCE'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _especes)
                GestureDetector(
                  onTap: () => setState(() => _species = e.$1),
                  // 32 px de haut comme sur le site : l'icône et le nom
                  // forment un bloc posé sur la ligne de base, qui laisse
                  // 3 px de jambage dessous (6 + 3 en bas).
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(11, 6, 11, 9),
                    decoration: BoxDecoration(
                      color: e.$1 == _species ? const Color(0x33C99A55) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: e.$1 == _species ? TytoColors.fauve : _encre20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SiteIcon.espece(e.$1, size: 15, color: TytoColors.encre),
                        const SizedBox(width: 6),
                        Text(e.$2, style: karla(13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          _etiquette('RACE (OPTIONNEL)'),
          _champ(_breed, 'Berger australien, européen…'),

          // Sexe et poids côte à côte, comme sur le site.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiquette('SEXE'),
                    Container(
                      height: 39,
                      padding: const EdgeInsets.only(left: 16.5, right: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _encre20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: valeurSexe,
                          isExpanded: true,
                          isDense: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          icon: SvgPicture.string(
                            _svgChevron,
                            width: 9,
                            height: 5.5,
                            colorFilter: const ColorFilter.mode(TytoColors.encre, BlendMode.srcIn),
                          ),
                          style: _styleChamp,
                          items: const [
                            DropdownMenuItem(value: '', child: Text('—')),
                            DropdownMenuItem(value: 'male', child: Text('Mâle')),
                            DropdownMenuItem(value: 'femelle', child: Text('Femelle')),
                          ],
                          onChanged: (v) => setState(() => _sex = (v == null || v.isEmpty) ? null : v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiquette('POIDS ACTUEL'),
                    Container(
                      width: double.infinity,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E9D8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _encre20),
                      ),
                      child: Text(
                        poids != null && poids != 0 ? '${_kg(poids)} kg' : '—',
                        style: karla(14.5, couleur: _encre67),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se met à jour via une pesée dans le Carnet',
                      style: karla(10.5, couleur: _encre53, interligne: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),

          _etiquette('DATE DE NAISSANCE (MÊME APPROXIMATIVE)'),
          GestureDetector(
            onTap: _choisirDate,
            child: Container(
              height: 39,
              padding: const EdgeInsets.only(left: 13, right: 15.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _encre20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b == null
                          ? 'jj/mm/aaaa'
                          : '${b.day.toString().padLeft(2, '0')}/${b.month.toString().padLeft(2, '0')}/${b.year}',
                      style: _styleChamp,
                    ),
                  ),
                  SvgPicture.string(
                    _svgCalendrier,
                    width: 11,
                    height: 12,
                    colorFilter: const ColorFilter.mode(TytoColors.encre, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),

          // Stérilisation : la case du navigateur, libellé en encre 60 %.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _sterilized = !_sterilized),
              // 19 px de haut : la case (13 px + 3 px de marge dessus et
              // dessous) donne la hauteur de la ligne.
              child: SizedBox(
                height: 19,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    _CaseNative(coche: _sterilized),
                    const SizedBox(width: 11),
                    Text('Stérilisé(e) / castré(e)', style: karla(14, poids: FontWeight.w500, couleur: _encre60)),
                  ],
                ),
              ),
            ),
          ),

          _etiquette('ALLERGIES CONNUES'),
          _champ(_allergies, 'poulet, acariens…'),

          _etiquette('ANTÉCÉDENTS, TRAITEMENTS EN COURS'),
          TextField(
            controller: _conditions,
            minLines: 2,
            maxLines: null,
            cursorColor: TytoColors.encre,
            style: _styleChamp,
            // 64 px de haut au repos, comme le textarea du site.
            decoration: _dec(
              'Opéré du genou en 2024, traitement anti-puces mensuel…',
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 20),
              lignesIndication: 2,
            ),
          ),

          // 16 px de marge + les 4 px que le navigateur laisse sous un
          // <textarea> (posé sur la ligne de base du texte).
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BoutonOr(
                  hauteur: 41,
                  opacite: (_nomValide && !_saving) ? 1 : 0.5,
                  onTap: _save,
                  child: Text('Enregistrer', style: karla(14.5, poids: FontWeight.w700, couleur: TytoColors.nuit)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onCancel,
                child: Container(
                  height: 41,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _encre20),
                  ),
                  child: Text('Annuler', style: karla(14)),
                ),
              ),
            ],
          ),

          if (widget.onDelete != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onDelete,
              child: Text(
                'Supprimer ce compagnon',
                style: karla(12.5, couleur: _rougeSupprimer).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: _rougeSupprimer,
                ),
              ),
            ),
            // Le lien est posé sur une ligne de texte de 16 px : le
            // navigateur laisse 1 px de jambage sous lui.
            const SizedBox(height: 1),
          ],
        ],
      ),
    );
  }
}
