import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../models/health_event.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/carnet_synthese_pdf.dart';
import '../services/user_service.dart';
import '../services/pro_service.dart';
import '../services/pdf_service.dart';
import '../widgets/account_gate.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/paw_trails.dart';
import '../widgets/pro_upsell.dart';
import '../widgets/site_icons.dart';
import '../widgets/voice_button.dart';
import '../widgets/weight_chart.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/drawer_navigation.dart';
import 'emergency_sheet.dart';
import 'prescription_screen.dart';
import 'pets_screen.dart';
import 'tableau_entete.dart';
import 'tableau_site.dart';

// Les mêmes types que sur le site (EVENT_TYPES), dans le même ordre.
const _eventTypes = ['vaccin', 'vermifuge', 'antiparasitaire', 'veto', 'poids', 'observation', 'traitement', 'autre'];

/// Le texte et les icônes des boutons verts du site (#0f2a24).
const _encreVerte = Color(0xFF0F2A24);

/// L'icône de calendrier que Chrome dessine au bout des champs de date
/// (<input type="date"> du formulaire), noire, 12 x 13 px.
const _calendrierNavigateur = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 13">'
    '<path fill="#000000" fill-rule="evenodd" d="M1.25 1.25h9.5a1 1 0 0 1 1 1V12a1 1 0 0 1-1 1h-9.5a1 1 0 0 1-1-1V2.25a1 1 0 0 1 1-1ZM1.25 4.4V12h9.5V4.4Z" />'
    '<path fill="#000000" d="M2 0h1v1.6H2ZM9 0h1v1.6H9Z" />'
    '</svg>';

/// La flèche que Chrome dessine au bout des listes déroulantes (<select>),
/// dans la couleur du texte du champ (l'encre).
const _flecheSelectNavigateur = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 9.5 6.5">'
    '<path d="M1 1.2 4.75 5 8.5 1.2" fill="none" stroke="#2A2118" stroke-width="1.8" />'
    '</svg>';

/// L'icône d'un type d'événement : EventIcon du site, avec sa table
/// EVENT_ICONS exacte (tout type inconnu = étiquette).
Widget _iconeEvenement(String type, {required double size, required Color color}) {
  const noms = {
    'vaccin': 'IconSyringe',
    'vermifuge': 'IconDroplet',
    'antiparasitaire': 'IconBug',
    'veto': 'IconStethoscope',
    'poids': 'IconScale',
    'observation': 'IconEye',
    'traitement': 'IconPill',
    'autre': 'IconTag',
  };
  return SiteIcon(noms[type] ?? 'IconTag', size: size, color: color);
}

/// Un nombre écrit comme en JavaScript : 23 et non 23.0.
String _nombre(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Les petits titres dorés en capitales espacées (« À venir »).
Widget _titreSection(String texte) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texte.toUpperCase(),
        style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.fauve).copyWith(letterSpacing: 1.98),
      ),
    );

// ============================================================
// Les données du carnet que DataService ne couvre pas : la récurrence
// (repeat_months) et le bouton « Fait », exactement comme le site.
// ============================================================

class CarnetDonnees {
  static SupabaseClient get _db => Supabase.instance.client;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// addMonths() du site : même report automatique en fin de mois.
  static DateTime ajouterMois(DateTime d, int mois) => DateTime(d.year, d.month + mois, d.day);

  /// La récurrence de chaque événement (id -> nombre de mois). En cas
  /// d'erreur, rien n'est affiché plutôt que de bloquer le carnet.
  static Future<Map<String, int>> recurrences({String? petId}) async {
    try {
      final List<dynamic> lignes = petId == null
          ? await _db.from('health_events').select('id, repeat_months')
          : await _db.from('health_events').select('id, repeat_months').eq('pet_id', petId);
      final resultat = <String, int>{};
      for (final l in lignes) {
        final v = l['repeat_months'];
        if (v is num && v > 0) resultat[l['id'].toString()] = v.toInt();
      }
      return resultat;
    } catch (e) {
      return <String, int>{};
    }
  }

  /// Ajout au carnet (addEvent du site), avec la récurrence choisie.
  static Future<void> enregistrer({
    required String petId,
    required String type,
    required String label,
    required DateTime eventDate,
    DateTime? nextDue,
    double? valueNum,
    String? notes,
    int? repeatMonths,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final ligne = <String, dynamic>{
      'user_id': user.id,
      'pet_id': petId,
      'type': type,
      'label': label.trim().isNotEmpty ? label.trim() : libelleDuType(type),
      'created_by_email': user.email,
      'event_date': _iso(eventDate),
      'next_due': nextDue == null ? null : _iso(nextDue),
      'value_num': valueNum,
      'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
    };
    if (repeatMonths != null) ligne['repeat_months'] = repeatMonths;
    await _db.from('health_events').insert(ligne);
    // Une pesée met aussi à jour le poids du profil, comme sur le site.
    if (type == 'poids' && valueNum != null) {
      await _db.from('pets').update({'weight_kg': valueNum}).eq('id', petId);
    }
  }

  /// « Fait » (markDone du site) : l'acte est noté aujourd'hui, le
  /// suivant est programmé s'il est récurrent, et l'ancien rappel est levé.
  static Future<void> marquerFait(HealthEvent ev, int? repeatMonths) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final ligne = <String, dynamic>{
      'user_id': user.id,
      'pet_id': ev.petId,
      'created_by_email': user.email,
      'type': ev.type,
      'label': ev.libelle,
      'event_date': _iso(aujourdhui),
      'next_due': repeatMonths == null ? null : _iso(ajouterMois(aujourdhui, repeatMonths)),
    };
    if (repeatMonths != null) ligne['repeat_months'] = repeatMonths;
    await _db.from('health_events').insert(ligne);
    await _db.from('health_events').update({'next_due': null}).eq('id', ev.id);
  }
}

// ============================================================
// L'écran
// ============================================================

/// Le carnet de santé, disposé comme l'onglet Carnet du site : choix du
/// compagnon, observation rapide, rappels à venir, ajout au carnet,
/// courbe de poids puis l'historique.
class CarnetScreen extends StatefulWidget {
  final Pet? pet;
  const CarnetScreen({super.key, this.pet});

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

/// Un bouton contour de la rangée Export / Ordonnance / Synthèse.
class _Fantome {
  final String icone;
  final String texte;
  final bool cadenas;
  final bool vert;
  final bool charge;
  final VoidCallback onTap;
  const _Fantome({
    required this.icone,
    required this.texte,
    required this.cadenas,
    required this.vert,
    required this.charge,
    required this.onTap,
  });
}

class _CarnetScreenState extends State<CarnetScreen> {
  List<HealthEvent> _events = [];
  Map<String, int> _recurrences = {};
  List<Pet> _pets = [];
  Pet? _selected;
  bool _loading = true;
  bool _isPro = false;
  bool _isPremium = false;
  bool _synthLoading = false;
  bool _exportLoading = false;
  bool _impression = false;
  bool _ajout = false; // le formulaire « Ajouter au carnet » est ouvert
  final _obsController = TextEditingController();
  bool _obsEnvoi = false;
  VetReport? _synthese;

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.pet;
    _load();
  }

  Future<void> _load({bool silencieux = false}) async {
    if (!AuthService.isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    if (!silencieux) setState(() => _loading = true);
    try {
      final token = AuthService.currentSession?.accessToken;
      if (token != null) {
        final profil = await UserService.fetchMe(token);
        if (mounted) {
          _isPro = profil.pro;
          _isPremium = profil.premium;
        }
      }
      final pets = await DataService.loadPets();
      final choisi = _selected == null
          ? (pets.isNotEmpty ? pets.first : null)
          : pets.firstWhere((p) => p.id == _selected!.id, orElse: () => _selected!);
      final events = choisi == null ? <HealthEvent>[] : await DataService.loadEvents(choisi.id);
      final recurrences = choisi == null ? <String, int>{} : await CarnetDonnees.recurrences(petId: choisi.id);
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _selected = choisi;
        _events = events;
        _recurrences = recurrences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Recharge l'historique du compagnon affiché, sans écran de chargement.
  Future<void> _rechargerEvenements() async {
    final p = _selected;
    if (p == null) return;
    try {
      final events = await DataService.loadEvents(p.id);
      final recurrences = await CarnetDonnees.recurrences(petId: p.id);
      if (!mounted || _selected?.id != p.id) return;
      setState(() {
        _events = events;
        _recurrences = recurrences;
      });
    } catch (e) {
      // On garde l'affichage précédent.
    }
  }

  Future<void> _selectPet(Pet p) async {
    if (p.id == _selected?.id) return;
    setState(() {
      _selected = p;
      // La synthèse ne concerne que le compagnon pour qui elle a été
      // générée : elle disparaît quand on change d'animal.
      _synthese = null;
      _synthLoading = false;
    });
    await _rechargerEvenements();
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  /// Le bouton URGENCE de l'en-tête : la fenêtre d'urgence connaît le
  /// compagnon affiché, comme sur le site.
  void _ouvrirUrgence() {
    final p = _selected;
    EmergencySheet.ouvrir(context, petId: p?.id, petName: p?.name, petWeight: p?.weightKg);
  }

  /// Le dossier PDF, disponible pour tout compte connecté (pas besoin
  /// d'être Pro) — généré sur l'appareil, puis proposé au partage.
  Future<void> _exporterPdf() async {
    if (_selected == null || _exportLoading) return;
    setState(() => _exportLoading = true);
    try {
      final fichier = await PdfService.genererDossier(pet: _selected!, evenements: _events);
      if (!mounted) return;
      await Share.shareXFiles([XFile(fichier.path)], text: 'Dossier de ${_selected!.name}, par Tyto.');
    } catch (e) {
      _message("L'export n'a pas abouti, réessaie.");
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  /// Fonction Pro : photographier une ordonnance pour en extraire les
  /// traitements. Sans abonnement Pro, on explique ce que c'est.
  Future<void> _ouvrirOrdonnance() async {
    if (!_isPro) return ProUpsell.afficher(context);
    if (_selected == null) return;
    final ajoute = await PrescriptionScreen.ouvrir(context, _selected!);
    if (ajoute == true) _rechargerEvenements();
  }

  /// Fonction Pro : la synthèse rédigée par Tyto pour le vétérinaire.
  Future<void> _genererSynthese() async {
    if (!_isPro) return ProUpsell.afficher(context);
    if (_selected == null || _synthLoading) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _synthLoading = true;
      _synthese = null;
    });
    final r = await ProService.vetReport(accessToken: token, petId: _selected!.id);
    if (!mounted) return;
    setState(() {
      _synthLoading = false;
      _synthese = r;
    });
    if (r == null) _message("La synthèse n'a pas pu être générée. Réessaie dans un instant.");
  }

  /// « Imprimer » (printVetReport du site) : la synthèse mise en page
  /// comme la page imprimable du site, en PDF, puis proposée au partage
  /// — d'où elle s'imprime ou s'envoie au vétérinaire.
  Future<void> _imprimerSynthese() async {
    final s = _synthese;
    if (s == null || _impression) return;
    final nom = (s.petName?.trim().isNotEmpty ?? false) ? s.petName!.trim() : (_selected?.name ?? '');
    setState(() => _impression = true);
    try {
      final fichier = await CarnetSynthesePdf.generer(nomAnimal: nom, contenu: s.content);
      if (!mounted) return;
      await Share.shareXFiles([XFile(fichier.path)], text: 'Synthèse vétérinaire — $nom');
    } catch (e) {
      _message("L'impression n'a pas abouti, réessaie.");
    } finally {
      if (mounted) setState(() => _impression = false);
    }
  }

  /// Noter une observation du quotidien en quelques mots (appétit, humeur,
  /// démarche…), sans passer par le formulaire complet — comme sur le site.
  Future<void> _noterObservation() async {
    final texte = _obsController.text.trim();
    if (texte.isEmpty || _selected == null || _obsEnvoi) return;
    setState(() => _obsEnvoi = true);
    try {
      await DataService.saveEvent(
        petId: _selected!.id,
        type: 'observation',
        eventDate: DateTime.now(),
        notes: texte,
        label: 'Observation',
      );
      _obsController.clear();
      await _rechargerEvenements();
    } catch (e) {
      _message("La note n'a pas pu être enregistrée, réessaie.");
    } finally {
      if (mounted) setState(() => _obsEnvoi = false);
    }
  }

  Future<bool> _enregistrer(_Saisie s) async {
    final pet = _selected;
    if (pet == null) return false;
    try {
      await CarnetDonnees.enregistrer(
        petId: pet.id,
        type: s.type,
        label: s.label,
        eventDate: s.eventDate,
        nextDue: s.nextDue,
        valueNum: s.valueNum,
        notes: s.notes,
        repeatMonths: s.repeatMonths,
      );
    } catch (e) {
      _message("L'enregistrement n'a pas abouti, réessaie.");
      return false;
    }
    if (!mounted) return true;
    setState(() => _ajout = false);
    await _rechargerEvenements();
    return true;
  }

  Future<void> _marquerFait(HealthEvent ev) async {
    try {
      await CarnetDonnees.marquerFait(ev, _recurrences[ev.id]);
    } catch (e) {
      _message("L'enregistrement n'a pas abouti, réessaie.");
      return;
    }
    await _rechargerEvenements();
  }

  Future<void> _supprimer(HealthEvent ev) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        title: Text('Supprimer cet événement ?', style: TytoText.display(size: 17)),
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
      await DataService.deleteEvent(ev.id);
    } catch (e) {
      _message("La suppression n'a pas abouti, réessaie.");
      return;
    }
    await _rechargerEvenements();
  }

  /// « Créer son profil » : comme le site, on passe sur Mes animaux avec
  /// le formulaire « Nouveau compagnon » déjà ouvert.
  void _versNouveauCompagnon() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PetsScreen(nouveauCompagnon: true)),
    );
  }

  /// Les pesées, de la plus ancienne à la plus récente, pour la courbe.
  List<PointPoids> get _pesees {
    final liste = [
      for (final e in _events)
        if (e.type == 'poids' && e.valueNum != null && e.valueNum != 0) PointPoids(e.eventDate, e.valueNum!),
    ];
    liste.sort((a, b) => a.date.compareTo(b.date));
    return liste;
  }

  /// Les rappels des 60 prochains jours pour ce compagnon (loadUpcoming).
  List<HealthEvent> get _aVenir {
    final liste = _events.where((e) {
      if (e.nextDue == null) return false;
      final d = joursAvant(e.nextDue!);
      return d >= 0 && d <= 60;
    }).toList();
    liste.sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    return liste.take(20).toList();
  }

  // ---------- Les blocs de la page ----------

  /// Pas encore de compagnon : la carte du site avec « Créer son profil ».
  Widget _carteSansAnimal() {
    return FenetrePapier(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Text(
            "Le carnet de santé suit les vaccins, vermifuges, pesées et visites de ton compagnon — et t'envoie des rappels. Commence par créer son profil !",
            textAlign: TextAlign.center,
            style: interligne(TytoText.body(size: 15.5, color: TytoColors.encre), 1.55),
          ),
          const SizedBox(height: 14),
          // Libellé « inline-flex » commençant par une icône : le navigateur
          // laisse 2,5 px sous la ligne (bouton de 41,5 px).
          TableauBouton(
            fond: TytoColors.fauve,
            echellePresse: 0.98,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            hauteurContenu: 19.5,
            hauteurLigne: 17,
            onTap: _versNouveauCompagnon,
            child: libelleBouton(
              icone: const SiteIcon('IconPlus', size: 14, color: TytoColors.nuit),
              ecart: 6,
              texte: 'Créer son profil',
              taille: 14.5,
              couleur: TytoColors.nuit,
            ),
          ),
        ],
      ),
    );
  }

  /// Les pastilles des compagnons, qui défilent à l'horizontale.
  Widget _petSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _pets.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              _pastille(_pets[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// Une pastille : padding 6 / 13, et comme le libellé est une ligne
  /// « inline-flex » qui commence par une icône, 2,5 px vides sous la
  /// ligne de 15 px (31,5 px de haut en tout, comme sur le site).
  Widget _pastille(Pet p) {
    final on = p.id == _selected?.id;
    return GestureDetector(
      onTap: () => _selectPet(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: on ? TytoColors.fauve.withAlpha(0x26) : TytoColors.lune.withAlpha(0x0d),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? TytoColors.fauve : TytoColors.lune.withAlpha(0x2e)),
        ),
        child: SizedBox(
          height: 17.5,
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: 1,
            child: SizedBox(
              height: 15,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SiteIcon.espece(p.species, size: 14, color: TytoColors.lune),
                  const SizedBox(width: 6),
                  Text(
                    p.name,
                    style: TytoText.ui(size: 13, weight: on ? FontWeight.w700 : FontWeight.w400, color: TytoColors.lune),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Le champ d'observation rapide et son bouton « Noter ».
  Widget _carteObservation() {
    OutlineInputBorder bord(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _obsController,
              enabled: !_obsEnvoi,
              style: TytoText.ui(size: 13.5, weight: FontWeight.w400, color: TytoColors.lune),
              cursorColor: TytoColors.fauve,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _noterObservation(),
              decoration: InputDecoration(
                hintText: 'Noter une observation sur ${_selected?.name ?? ''}…',
                hintStyle: TytoText.ui(size: 13.5, weight: FontWeight.w400, color: couleurIndication),
                filled: true,
                fillColor: TytoColors.nuit2,
                isDense: true,
                // padding CSS 10 / 13, plus le bord d'1 px.
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: bord(TytoColors.lune.withAlpha(0x30), 1),
                enabledBorder: bord(TytoColors.lune.withAlpha(0x30), 1),
                disabledBorder: bord(TytoColors.lune.withAlpha(0x30), 1),
                focusedBorder: bord(TytoColors.fauve, 2),
              ),
            ),
          ),
          // La dictée de l'observation est réservée au Pro, comme sur le site.
          if (_isPro) ...[
            const SizedBox(width: 8),
            VoiceButton(
              size: 38,
              title: "Dicter l'observation",
              onText: (t) {
                _obsController.text = t;
                _obsController.selection = TextSelection.fromPosition(TextPosition(offset: t.length));
              },
            ),
          ],
          const SizedBox(width: 8),
          // « Noter » reste pâle (opacité 0,4) tant que le champ est vide.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _obsController,
            builder: (context, valeur, _) {
              final actif = valeur.text.trim().isNotEmpty && !_obsEnvoi;
              return TableauBouton(
                fond: TytoColors.fauve,
                echellePresse: 0.98,
                opacite: actif ? 1.0 : 0.4,
                hauteur: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onTap: actif ? _noterObservation : null,
                child: Text('Noter', style: TytoText.ui(size: 13, weight: FontWeight.w700, color: TytoColors.nuit)),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Une ligne « À venir » : dorée à 3 jours ou moins, neutre sinon.
  Widget _ligneAVenir(HealthEvent ev) {
    final d = joursAvant(ev.nextDue!);
    final proche = d <= 3;
    final mois = _recurrences[ev.id];
    final quand = d == 0 ? "aujourd'hui" : d == 1 ? 'demain' : 'dans $d jours';
    const brume = TextStyle(color: TytoColors.brume);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: proche ? TytoColors.fauve.withAlpha(0x26) : TytoColors.lune.withAlpha(0x0d),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: proche ? TytoColors.fauve.withAlpha(0x88) : TytoColors.lune.withAlpha(0x26)),
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
                  TextSpan(text: ' — ${dateFr(ev.nextDue!)} '),
                  TextSpan(text: '($quand)', style: brume),
                  if (mois != null) TextSpan(text: ' · tous les $mois mois', style: brume),
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

  Widget _blocAVenir(List<HealthEvent> liste) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titreSection('À venir'),
          for (final ev in liste) _ligneAVenir(ev),
        ],
      ),
    );
  }

  /// « Ajouter au carnet » en pleine largeur, puis Export / Ordonnance /
  /// Synthèse qui se partagent la ligne et passent à la ligne au besoin.
  Widget _blocActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableauBouton(
            pleineLargeur: true,
            fond: TytoColors.fauve,
            echellePresse: 0.98,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            hauteurContenu: 19.5,
            hauteurLigne: 17,
            onTap: () => setState(() => _ajout = true),
            child: libelleBouton(
              icone: const SiteIcon('IconPlus', size: 14, color: TytoColors.nuit),
              ecart: 6,
              texte: 'Ajouter au carnet',
              taille: 14.5,
              couleur: TytoColors.nuit,
            ),
          ),
          const SizedBox(height: 8),
          _rangeeFantomes(),
        ],
      ),
    );
  }

  Widget _rangeeFantomes() {
    final actions = [
      _Fantome(
        icone: 'IconDocument',
        texte: 'Export',
        cadenas: false,
        vert: false,
        charge: _exportLoading,
        onTap: _exporterPdf,
      ),
      _Fantome(
        icone: 'IconCamera',
        texte: 'Ordonnance',
        cadenas: !_isPro,
        vert: _isPro,
        charge: false,
        onTap: _ouvrirOrdonnance,
      ),
      _Fantome(
        icone: 'IconStethoscope',
        texte: 'Synthèse',
        cadenas: !_isPro,
        vert: _isPro,
        charge: _synthLoading,
        onTap: _genererSynthese,
      ),
    ];
    final style = TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.brume);
    return LayoutBuilder(
      builder: (context, contraintes) {
        // Largeur naturelle de chaque bouton (flex: 1 1 auto du site).
        final largeurs = <double>[];
        for (final a in actions) {
          final tp = TextPainter(
            text: TextSpan(text: a.charge ? '…' : a.texte, style: style),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final w = 2 + 28 + tp.width + (a.charge ? 0 : 14 + 5) + (a.cadenas ? 5 + 12 : 0);
          largeurs.add(w.ceilToDouble() + 1);
        }
        // Répartition en lignes (flex-wrap: wrap, écart de 8).
        final maxW = contraintes.maxWidth;
        final lignes = <List<int>>[];
        var courante = <int>[];
        var occupe = 0.0;
        for (var i = 0; i < largeurs.length; i++) {
          final besoin = courante.isEmpty ? largeurs[i] : occupe + 8 + largeurs[i];
          if (courante.isNotEmpty && besoin > maxW) {
            lignes.add(courante);
            courante = [i];
            occupe = largeurs[i];
          } else {
            courante.add(i);
            occupe = besoin;
          }
        }
        if (courante.isNotEmpty) lignes.add(courante);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var l = 0; l < lignes.length; l++)
              Padding(
                padding: EdgeInsets.only(top: l == 0 ? 0 : 8),
                child: Row(children: _ligneFantomes(lignes[l], actions, largeurs, maxW)),
              ),
          ],
        );
      },
    );
  }

  /// Chaque bouton d'une ligne garde sa largeur naturelle et reçoit une
  /// part égale de la place restante (flex-grow: 1).
  List<Widget> _ligneFantomes(List<int> indices, List<_Fantome> actions, List<double> largeurs, double maxW) {
    var somme = 0.0;
    for (final i in indices) {
      somme += largeurs[i];
    }
    final libre = math.max(0.0, maxW - somme - 8 * (indices.length - 1));
    final bonus = libre / indices.length;
    final enfants = <Widget>[];
    for (var k = 0; k < indices.length; k++) {
      if (k > 0) enfants.add(const SizedBox(width: 8));
      final i = indices[k];
      enfants.add(Expanded(
        flex: math.max(1, ((largeurs[i] + bonus) * 10).round()),
        child: _boutonFantome(actions[i]),
      ));
    }
    return enfants;
  }

  /// ghostBtn du site (padding 10 / 14, 13 px) : 39,5 px de haut, car le
  /// libellé « inline-flex » commence par une icône (ligne de 15 px posée
  /// en haut d'une zone de 17,5 px).
  Widget _boutonFantome(_Fantome a) {
    final couleur = a.vert ? TytoColors.vert : TytoColors.brume;
    final bord = a.vert ? TytoColors.vert.withAlpha(0x88) : TytoColors.lune.withAlpha(0x33);
    final texte = TytoText.ui(size: 13, weight: FontWeight.w400, color: couleur);
    return TableauBouton(
      onTap: a.charge ? null : a.onTap,
      bord: bord,
      pleineLargeur: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      // « … » seul (sans icône) : le bouton reste étiré à la hauteur de
      // ses voisins, le texte centré.
      hauteurContenu: a.charge ? null : 17.5,
      hauteurLigne: a.charge ? null : 15,
      hauteur: a.charge ? 39.5 : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.charge)
            Text('…', style: texte)
          else ...[
            SiteIcon(a.icone, size: 14, color: couleur),
            const SizedBox(width: 5),
            Flexible(
              child: Text(a.texte, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: texte),
            ),
          ],
          // Le cadenas rappelle que la fonction demande le plan Pro.
          if (a.cadenas) ...[
            const SizedBox(width: 5),
            SiteIcon('IconLock', size: 12, color: couleur),
          ],
        ],
      ),
    );
  }

  /// La synthèse affichée sur le papier ivoire, comme sur le site.
  Widget _carteSynthese() {
    final morceaux = _synthese!.content.split('**');
    final base = interligne(TytoText.body(size: 15, color: TytoColors.encre), 1.65);
    final gras = interligne(
      GoogleFonts.newsreader(fontSize: 15, fontWeight: FontWeight.w700, color: TytoColors.encre),
      1.65,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FenetrePapier(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SiteIcon('IconStethoscope', size: 17, color: TytoColors.encre),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text('Synthèse pour le vétérinaire', style: TytoText.display(size: 17, color: TytoColors.encre)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Le bouton vert « Imprimer » (padding 6 / 12, 12 px gras) :
                // ligne de 14 px en haut d'une zone de 16 px.
                TableauBouton(
                  fond: TytoColors.vert,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  hauteurContenu: 16,
                  hauteurLigne: 14,
                  onTap: _imprimerSynthese,
                  child: libelleBouton(
                    icone: const SiteIcon('IconPrinter', size: 12, color: _encreVerte),
                    ecart: 5,
                    texte: 'Imprimer',
                    taille: 12,
                    couleur: _encreVerte,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _synthese = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '×',
                      style: styleSysteme(context, size: 18, color: TytoColors.encre.withAlpha(0x88)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < morceaux.length; i++) TextSpan(text: morceaux[i], style: i.isOdd ? gras : null),
                ],
              ),
              style: base,
            ),
          ],
        ),
      ),
    );
  }

  /// Un événement de l'historique, sur papier, avec son icône et la croix.
  Widget _carteEvenement(HealthEvent e) {
    final mois = _recurrences[e.id];
    final kg = (e.valueNum != null && e.valueNum != 0) ? ' — ${_nombre(e.valueNum!)} kg' : '';
    final sous = StringBuffer(dateFr(e.eventDate));
    if (e.nextDue != null) sous.write(' · rappel le ${dateFr(e.nextDue!)}');
    if (mois != null) sous.write(' · tous les $mois mois');
    final notes = e.notes?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FenetrePapier(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Opacity(
                opacity: 0.75,
                child: _iconeEvenement(e.type, size: 18, color: TytoColors.nuit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.libelle}$kg', style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.encre)),
                  Text(
                    sous.toString(),
                    style: TytoText.ui(size: 12, weight: FontWeight.w400, color: TytoColors.encre.withAlpha(0x99)),
                  ),
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(notes, style: TytoText.body(size: 12.5, color: TytoColors.encre)),
                    ),
                ],
              ),
            ),
            // La croix (police système du bouton, 15 px, padding 2) garde
            // sa place du site ; la zone de toucher déborde vers la gauche
            // et le bas, sans rien décaler.
            const SizedBox(width: 2),
            Semantics(
              button: true,
              label: 'Supprimer',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _supprimer(e),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 2, 8),
                  child: Text('×', style: styleSysteme(context, size: 15, color: TytoColors.encre.withAlpha(0x66))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenu() {
    final pet = _selected;
    if (pet == null) {
      return [
        _petSelector(),
        Text(
          'Choisis un compagnon ci-dessus.',
          style: TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.brume),
        ),
      ];
    }
    final aVenir = _aVenir;
    final pesees = _pesees;
    return [
      _petSelector(),
      _carteObservation(),
      if (aVenir.isNotEmpty) _blocAVenir(aVenir),
      if (_ajout)
        _EventForm(
          key: ValueKey('formulaire-${pet.id}'),
          isPro: _isPro,
          onSave: _enregistrer,
          onCancel: () => setState(() => _ajout = false),
        )
      else ...[
        _blocActions(),
        if (_synthese != null) _carteSynthese(),
      ],
      if (pesees.length >= 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: WeightChart(points: pesees),
        ),
      if (_events.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Le carnet de ${pet.name} est encore vide.',
            textAlign: TextAlign.center,
            style: TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.brume),
          ),
        )
      else
        for (final e in _events) _carteEvenement(e),
    ];
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
              children: _pets.isEmpty ? [_carteSansAnimal()] : _contenu(),
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
        activeId: 'carnet',
        onSelect: (id) => handleDrawerNavigation(context, 'carnet', id),
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
          Positioned.fill(child: _corps()),
        ],
      ),
    );
  }
}

// ============================================================
// Le formulaire « Ajouter au carnet » (EventForm du site), sur papier,
// directement dans la page.
// ============================================================

class _Saisie {
  final String type;
  final String label;
  final DateTime eventDate;
  final DateTime? nextDue;
  final double? valueNum;
  final String notes;
  final int? repeatMonths;
  const _Saisie({
    required this.type,
    required this.label,
    required this.eventDate,
    this.nextDue,
    this.valueNum,
    required this.notes,
    this.repeatMonths,
  });
}

class _EventForm extends StatefulWidget {
  /// Le micro des notes n'apparaît que pour les comptes Pro : sur un
  /// téléphone, l'afficher déclenche aussitôt la demande d'accès au micro.
  final bool isPro;
  final Future<bool> Function(_Saisie saisie) onSave;
  final VoidCallback onCancel;
  const _EventForm({super.key, required this.onSave, required this.onCancel, this.isPro = false});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  static const _repetitions = <int, String>{
    0: 'Non, une seule fois',
    1: 'Tous les mois',
    2: 'Tous les 2 mois',
    3: 'Tous les 3 mois',
    6: 'Tous les 6 mois',
    12: 'Tous les ans',
  };

  String _type = 'vaccin';
  final _label = TextEditingController(text: 'Vaccin');
  DateTime _eventDate = DateTime.now();
  DateTime? _nextDue;
  int _repeat = 0;
  final _value = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _label.addListener(_maj);
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _label.removeListener(_maj);
    _label.dispose();
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Changer de type remplace l'intitulé, sauf s'il a été personnalisé.
  void _choisirType(String t) {
    final actuel = _label.text;
    if (actuel.isEmpty || actuel == libelleDuType(_type)) _label.text = libelleDuType(t);
    setState(() => _type = t);
  }

  /// Choisir une répétition propose la date du rappel si elle est vide.
  void _choisirRepetition(int mois) {
    setState(() {
      _repeat = mois;
      if (mois > 0 && _nextDue == null) _nextDue = CarnetDonnees.ajouterMois(_eventDate, mois);
    });
  }

  Future<void> _enregistrer() async {
    if (_label.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_Saisie(
      type: _type,
      label: _label.text.trim(),
      eventDate: _eventDate,
      nextDue: _nextDue,
      valueNum: _type == 'poids' ? double.tryParse(_value.text.trim().replaceAll(',', '.')) : null,
      notes: _notes.text,
      repeatMonths: _repeat > 0 ? _repeat : null,
    ));
    if (!ok && mounted) setState(() => _saving = false);
  }

  /// fieldStyle du site : blanc, filet d'encre à 20 %, arrondi de 10,
  /// padding 9 / 12 (plus le bord d'1 px), 14,5 px.
  InputDecoration _dec(String hint) => decorationChampPapier(
        indication: hint,
        taille: 14.5,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      );

  TextStyle get _champ => TytoText.ui(size: 14.5, weight: FontWeight.w400, color: TytoColors.encre);

  BoxDecoration get _cadreChamp => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TytoColors.encre.withAlpha(0x33)),
      );

  /// labelStyle du site : petites capitales espacées, encre à 60 %.
  Widget _etiquette(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          t.toUpperCase(),
          style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withAlpha(0x99))
              .copyWith(letterSpacing: 0.88),
        ),
      );

  Widget _aide(String t) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          t,
          style: interligne(TytoText.ui(size: 11.5, weight: FontWeight.w400, color: TytoColors.encre.withAlpha(0x88)), 1.4),
        ),
      );

  /// Une puce de type : padding 6 / 11 ; le libellé « inline-flex » qui
  /// commence par une icône de 15 px laisse 3 px sous la ligne (32 px).
  Widget _puceType(String t) {
    final on = t == _type;
    return GestureDetector(
      onTap: () => _choisirType(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? TytoColors.fauve.withAlpha(0x33) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? TytoColors.fauve : TytoColors.encre.withAlpha(0x33)),
        ),
        child: SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: 1,
            child: SizedBox(
              height: 15,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconeEvenement(t, size: 15, color: TytoColors.encre),
                  const SizedBox(width: 6),
                  Text(libelleDuType(t), style: TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.encre)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Un champ de date comme le <input type="date"> de Chrome : 39 px de
  /// haut, chaque partie de la date entourée d'1 px, l'icône de
  /// calendrier noire au bout.
  Widget _champDate(String label, DateTime? valeur, ValueChanged<DateTime> choisir) {
    final parties = valeur == null
        ? const ['jj', 'mm', 'aaaa']
        : [
            valeur.day.toString().padLeft(2, '0'),
            valeur.month.toString().padLeft(2, '0'),
            valeur.year.toString(),
          ];
    Widget partie(String t) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(t, style: _champ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiquette(label),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: valeur ?? _eventDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) choisir(d);
          },
          child: Container(
            height: 39,
            padding: const EdgeInsets.only(left: 12, right: 3.25),
            decoration: _cadreChamp,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          partie(parties[0]),
                          Text('/', style: _champ),
                          partie(parties[1]),
                          Text('/', style: _champ),
                          partie(parties[2]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: SvgPicture.string(_calendrierNavigateur, width: 12, height: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// La liste « Répéter » comme le <select> de Chrome : 39 px de haut, le
  /// texte 4 px plus loin que dans un champ texte, la flèche à 5 px du bord.
  Widget _choixRepetition() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6.5, 3.5, 6.5),
      decoration: _cadreChamp,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _repeat,
          isExpanded: true,
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
          icon: SvgPicture.string(_flecheSelectNavigateur, width: 9.5, height: 6.5),
          style: _champ,
          items: [
            for (final e in _repetitions.entries)
              DropdownMenuItem<int>(value: e.key, child: Text(e.value, style: _champ)),
          ],
          onChanged: (v) {
            if (v != null) _choisirRepetition(v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pret = _label.text.trim().isNotEmpty && !_saving;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FenetrePapier(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ajouter au carnet', style: TytoText.display(size: 18, color: TytoColors.encre)),
            _etiquette('Type'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in _eventTypes) _puceType(t)],
            ),
            _etiquette('Intitulé *'),
            TextField(
              controller: _label,
              style: _champ,
              cursorColor: TytoColors.fauve,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Vaccin rage, Pipette anti-puces…'),
            ),
            if (_type == 'poids') ...[
              _etiquette('Poids mesuré (kg)'),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: _champ,
                cursorColor: TytoColors.fauve,
                decoration: _dec('12.8'),
              ),
              _aide('Chaque pesée datée alimente la courbe de poids et met à jour le poids affiché sur le profil.'),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _champDate('Fait le', _eventDate, (d) => setState(() => _eventDate = d))),
                const SizedBox(width: 10),
                Expanded(child: _champDate('Rappel le (optionnel)', _nextDue, (d) => setState(() => _nextDue = d))),
              ],
            ),
            _etiquette('Répéter'),
            _choixRepetition(),
            // Le texte du site, « site » devenant « app » ; l'app prévient
            // en plus sur le téléphone, le jour même.
            _aide(
              "Renseigne « Rappel le » pour recevoir une alerte (dans l'app et par email) 7 jours avant puis la veille, "
              "et sur le téléphone le jour même. Ex. : vaccins souvent 1 an après, vermifuges 3 à 6 mois.",
            ),
            _etiquette('Notes (optionnel)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _notes,
                    style: _champ,
                    cursorColor: TytoColors.fauve,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec('Chez Dr Martin, lot n°…'),
                  ),
                ),
                if (widget.isPro) ...[
                  const SizedBox(width: 8),
                  VoiceButton(
                    size: 38,
                    title: 'Dicter la note',
                    onText: (t) {
                      _notes.text = t;
                      _notes.selection = TextSelection.fromPosition(TextPosition(offset: _notes.text.length));
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TableauBouton(
                      pleineLargeur: true,
                      fond: TytoColors.fauve,
                      echellePresse: 0.98,
                      opacite: pret ? 1.0 : 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      onTap: pret ? _enregistrer : null,
                      child: Text(
                        'Enregistrer',
                        style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.nuit),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TableauBouton(
                    bord: TytoColors.encre.withAlpha(0x33),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    onTap: widget.onCancel,
                    child: Text('Annuler', style: TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.encre)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
