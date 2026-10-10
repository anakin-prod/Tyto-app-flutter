import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import '../services/data_service.dart';
import '../models/soin.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/site_icons.dart';
import 'nouveau_soin_screen.dart';
import 'tableau_site.dart';

/// Une ligne lue sur l'ordonnance par /api/prescription, avec le degré
/// de confiance de la lecture (« low » = lecture incertaine).
class _LigneLue {
  final String medication;
  final String? dose;
  final int? timesPerDay;
  final int? durationDays;
  final String? notes;
  final bool incertaine;
  final bool checked;
  const _LigneLue({
    required this.medication,
    this.dose,
    this.timesPerDay,
    this.durationDays,
    this.notes,
    required this.incertaine,
    required this.checked,
  });
}

/// Le résultat de la lecture, tel que le site le reçoit : lisible ou non,
/// l'avertissement éventuel et les lignes ; ou un message d'erreur.
class _Lecture {
  final bool readable;
  final String? warning;
  final List<_LigneLue> lignes;
  final String? erreur;
  const _Lecture({required this.readable, this.warning, required this.lignes}) : erreur = null;
  const _Lecture.echec(String this.erreur)
      : readable = false,
        warning = null,
        lignes = const [];
}

/// readPrescription du site : la même route, les mêmes messages d'erreur.
Future<_Lecture> _lireOrdonnance({
  required String accessToken,
  required String base64Image,
  required String mediaType,
}) async {
  int? entier(dynamic v) => v is num ? v.toInt() : null;
  try {
    final res = await http.post(
      Uri.parse('https://tytoai.app/api/prescription'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
      body: jsonEncode({'image': base64Image, 'mediaType': mediaType}),
    );
    Map<String, dynamic> d = const {};
    try {
      final j = jsonDecode(res.body);
      if (j is Map<String, dynamic>) d = j;
    } catch (e) {
      // Réponse illisible : traitée comme un échec ci-dessous.
    }
    if (res.statusCode != 200) {
      return _Lecture.echec(
        d['error'] == 'image_too_large'
            ? "Cette photo est trop lourde — réessaie avec une photo un peu moins grande."
            : "La lecture de l'ordonnance a échoué. Réessaie avec une photo plus nette.",
      );
    }
    final readable = d['readable'] == true;
    final warning = d['warning'];
    return _Lecture(
      readable: readable,
      warning: warning is String && warning.trim().isNotEmpty ? warning : null,
      lignes: [
        for (final l in (d['lines'] is List ? d['lines'] as List : const []))
          if (l is Map)
            _LigneLue(
              medication: (l['medication'] ?? '').toString(),
              dose: l['dose']?.toString(),
              timesPerDay: entier(l['times_per_day']),
              durationDays: entier(l['duration_days']),
              notes: l['notes']?.toString(),
              incertaine: l['confidence'] == 'low',
              // Pré-cochée seulement si la lecture globale est fiable.
              checked: readable,
            ),
      ],
    );
  } catch (e) {
    return const _Lecture.echec("La lecture de l'ordonnance a échoué. Réessaie dans un instant.");
  }
}

/// Fonction Pro : photographier une ordonnance, laisser Tyto la lire, puis
/// vérifier — et corriger — chaque ligne avant de l'ajouter au carnet de
/// santé. Rien n'est enregistré sans que tu aies coché la ligne : une
/// lecture automatique peut se tromper, c'est toi qui valides.
class PrescriptionScreen extends StatefulWidget {
  final Pet pet;
  const PrescriptionScreen({super.key, required this.pet});

  /// Ouvre la fenêtre par-dessus l'écran courant, comme sur le site (le
  /// voile laisse deviner la page derrière). Renvoie true si des
  /// traitements ont été ajoutés.
  static Future<bool?> ouvrir(BuildContext context, Pet pet) {
    return Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
      opaque: false,
      pageBuilder: (_, __, ___) => PrescriptionScreen(pet: pet),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

/// Une ligne lue sur l'ordonnance, modifiable comme sur le site.
class _LigneEditable {
  final TextEditingController medicament;
  final TextEditingController dose;
  final TextEditingController fois;
  final TextEditingController jours;
  final String? notes;
  final bool incertaine;
  bool checked;

  _LigneEditable(_LigneLue l)
      : medicament = TextEditingController(text: l.medication),
        dose = TextEditingController(text: l.dose ?? ''),
        fois = TextEditingController(text: l.timesPerDay?.toString() ?? ''),
        jours = TextEditingController(text: l.durationDays?.toString() ?? ''),
        notes = l.notes,
        incertaine = l.incertaine,
        checked = l.checked;

  int? get timesPerDay => int.tryParse(fois.text.trim());
  int? get durationDays => int.tryParse(jours.text.trim());

  void dispose() {
    medicament.dispose();
    dose.dispose();
    fois.dispose();
    jours.dispose();
  }
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  File? _photo;
  PhotoCompressee? _compressee;
  bool _lecture = false;
  bool _enregistrement = false;
  _Lecture? _resultat;
  List<_LigneEditable> _lignes = [];

  @override
  void dispose() {
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  void _viderLignes() {
    final anciennes = _lignes;
    _lignes = [];
    // Les champs encore affichés se détachent à la prochaine image : on
    // ne libère leurs contrôleurs qu'après.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in anciennes) {
        l.dispose();
      }
    });
  }

  /// « Prendre ou choisir une photo » : appareil photo ou galerie.
  Future<void> _choisirSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: const Color(0x660A0E18),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FenetrePapier(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BoutonDore(
                  texte: 'Prendre une photo',
                  icone: const IconeTrait.appareil(size: 15, color: TytoColors.nuit),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                BoutonPilule(
                  texte: 'Choisir dans la galerie',
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  bord: const Color(0x332A2118),
                  encre: TytoColors.encre,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  taille: 13.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (source != null) await _choisirPhoto(source);
  }

  Future<void> _choisirPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final choisie = await picker.pickImage(source: source, imageQuality: 100);
    if (choisie == null) return;

    final fichier = File(choisie.path);
    final compressee = await compresserPhoto(fichier);
    if (!mounted) return;
    if (compressee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cette image n'a pas pu être lue. Réessaie avec une autre photo.")),
      );
      return;
    }
    setState(() {
      _photo = fichier;
      _compressee = compressee;
      _resultat = null;
      _viderLignes();
    });
  }

  void _reprendre() {
    setState(() {
      _photo = null;
      _compressee = null;
      _resultat = null;
      _viderLignes();
    });
  }

  Future<void> _lire() async {
    if (_compressee == null || _lecture) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _lecture = true;
      _resultat = null;
      _viderLignes();
    });
    final r = await _lireOrdonnance(
      accessToken: token,
      base64Image: _compressee!.base64,
      mediaType: _compressee!.mediaType,
    );
    if (!mounted) return;
    final erreur = r.erreur;
    setState(() {
      _lecture = false;
      _resultat = erreur != null ? null : r;
      if (erreur == null) _lignes = r.lignes.map((l) => _LigneEditable(l)).toList();
    });
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
    }
  }

  List<_LigneEditable> get _aEnregistrer =>
      _lignes.where((l) => l.checked && l.medicament.text.trim().isNotEmpty).toList();

  Future<void> _enregistrer() async {
    final lignes = _aEnregistrer;
    if (lignes.isEmpty || _enregistrement) return;

    setState(() => _enregistrement = true);
    try {
      for (final l in lignes) {
        // confirmPrescription du site : 1 prise par jour et 1 jour quand
        // rien n'est indiqué, un rappel aujourd'hui au-delà d'un jour.
        final fois = (l.timesPerDay == null || l.timesPerDay == 0) ? 1 : l.timesPerDay!;
        final jours = (l.durationDays == null || l.durationDays == 0) ? 1 : l.durationDays!;
        final parts = <String>[
          '${fois}x/jour',
          'pendant $jours jour${jours > 1 ? 's' : ''}',
          if (l.notes != null && l.notes!.trim().isNotEmpty) l.notes!.trim(),
        ];

        final dose = l.dose.text.trim();
        final titre = l.medicament.text.trim() + (dose.isNotEmpty ? ' — $dose' : '');

        await DataService.saveEvent(
          petId: widget.pet.id,
          type: 'traitement',
          eventDate: DateTime.now(),
          nextDue: jours > 1 ? aujourdhui() : null,
          label: titre,
          notes: '${parts.join(' · ')} (ordonnance photographiée, à vérifier)',
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lignes.length} traitement${lignes.length > 1 ? 's ajoutés' : ' ajouté'} au carnet.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'enregistrement n'a pas abouti, réessaie.")),
      );
    }
  }

  /// Heures proposées par défaut selon le nombre de prises par jour. C'est
  /// seulement un point de départ : l'écran suivant permet de tout corriger.
  List<String> _heuresPar(int? foisParJour) {
    final f = foisParJour ?? 1;
    switch (f) {
      case 0:
      case 1:
        return ['09:00'];
      case 2:
        return ['08:00', '20:00'];
      case 3:
        return ['08:00', '14:00', '21:00'];
      case 4:
        return ['08:00', '12:00', '16:00', '20:00'];
      default:
        final n = f.clamp(5, 8).toInt();
        final pas = 14 ~/ n;
        return [
          for (var i = 0; i < n; i++) '${(7 + i * pas).toString().padLeft(2, '0')}:00',
        ];
    }
  }

  /// Transforme les lignes cochées en dossier de soin avec rappels.
  Future<void> _creerDossier() async {
    final lignes = _aEnregistrer;
    if (lignes.isEmpty) return;
    final debut = aujourdhui();
    final traitements = <NouveauTraitement>[
      for (final l in lignes)
        NouveauTraitement(
          nom: l.medicament.text.trim(),
          dose: l.dose.text.trim().isNotEmpty ? l.dose.text.trim() : null,
          heures: _heuresPar(l.timesPerDay),
          tousLesJours: 1,
          debut: debut,
          fin: l.durationDays != null && l.durationDays! > 0
              ? debut.add(Duration(days: l.durationDays! - 1))
              : null,
          notes: (l.notes != null && l.notes!.trim().isNotEmpty) ? l.notes!.trim() : null,
        ),
    ];
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NouveauSoinScreen(
          pets: [widget.pet],
          petInitial: widget.pet,
          traitementsInitiaux: traitements,
          depuisOrdonnance: true,
        ),
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // La fenêtre du site : voile rgba(10,14,24,0.8), carte papier de 480 px
    // au plus, haute de 90 % de l'écran au plus. Toucher le voile la ferme.
    return Scaffold(
      backgroundColor: const Color(0xCC0A0E18),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FenetrePapier(
                      padding: EdgeInsets.zero,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _entete(),
                            const SizedBox(height: 10),
                            if (_photo == null) ..._etatVide(),
                            if (_photo != null && _resultat == null) ..._etatPhoto(),
                            if (_resultat != null) ..._etatResultat(),
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.only(top: 8),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0x1A2A2118))),
                              ),
                              child: Text(
                                "Tyto retranscrit, il n'interprète pas. La responsabilité du traitement administré "
                                'reste celle du soigneur — vérifie toujours avec l\'ordonnance originale.',
                                style: interligne(TytoText.ui(size: 10.5, weight: FontWeight.w400, color: encreA(0x77)), 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entete() {
    return Row(
      children: [
        const SiteIcon('IconCamera', size: 18, color: TytoColors.encre),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Lire une ordonnance', style: TytoText.display(size: 19, color: TytoColors.encre)),
        ),
        const SizedBox(width: 8),
        BoutonFermerCroix(onTap: () => Navigator.pop(context)),
      ],
    );
  }

  List<Widget> _etatVide() {
    // Le gras du site (<strong>) : la vraie graisse 700 de Newsreader.
    final gras = GoogleFonts.newsreader(fontSize: 15, fontWeight: FontWeight.w700, color: TytoColors.encre);
    return [
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "Photographie l'ordonnance de "),
            TextSpan(text: widget.pet.name, style: gras),
            const TextSpan(text: '. Tyto en propose une lecture — '),
            TextSpan(text: 'tu valides ou corriges chaque ligne', style: gras),
            const TextSpan(text: ' avant que rien ne soit enregistré.'),
          ],
        ),
        style: interligne(TytoText.body(size: 15, color: TytoColors.encre), 1.55),
      ),
      const SizedBox(height: 16),
      // Libellé « inline-flex » qui commence par une icône de 15 px : le
      // navigateur laisse 3 px sous la ligne (bouton de 42 px).
      TableauBouton(
        pleineLargeur: true,
        fond: TytoColors.fauve,
        echellePresse: 0.98,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        hauteurContenu: 20,
        hauteurLigne: 17,
        onTap: _choisirSource,
        child: libelleBouton(
          icone: const SiteIcon('IconCamera', size: 15, color: TytoColors.nuit),
          ecart: 7,
          texte: 'Prendre ou choisir une photo',
          taille: 14.5,
          couleur: TytoColors.nuit,
        ),
      ),
    ];
  }

  List<Widget> _etatPhoto() {
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(_photo!, width: double.infinity, fit: BoxFit.fitWidth),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: BoutonPilule(
                texte: 'Reprendre',
                onTap: _reprendre,
                actif: !_lecture,
                opaciteInactive: 1,
                bord: const Color(0x33EDE7D6),
                encre: TytoColors.brume,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                taille: 12,
                gras: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: BoutonDore(
                texte: _lecture ? "Tyto lit l'ordonnance…" : "Lire l'ordonnance",
                onTap: _lire,
                actif: !_lecture,
                opaciteInactive: 0.6,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _etatResultat() {
    final r = _resultat!;
    final coches = _lignes.where((l) => l.checked).length;
    final pret = coches > 0 && !_enregistrement;
    return [
      if (!r.readable)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x1F8A3A2E),
            border: Border.all(color: const Color(0x88C96A55)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "${r.warning ?? "L'ordonnance n'a pas pu être lue clairement."} Essaie une photo plus nette, bien éclairée et bien cadrée.",
            style: interligne(TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.encre), 1.5),
          ),
        ),
      if (_lignes.isNotEmpty) ...[
        Text(
          'Vérifie chaque ligne avant de valider — Tyto peut se tromper, surtout sur une écriture '
          'difficile à lire. Décoche ce qui est incertain ou incorrect.',
          style: interligne(TytoText.ui(size: 12.5, weight: FontWeight.w400, color: encreA(0x99)), 1.45),
        ),
        const SizedBox(height: 10),
        ..._lignes.map(_ligne),
        const SizedBox(height: 6),
        // Avec la coche en tête, 2,5 px vides sous la ligne (41,5 px) ;
        // « Enregistrement… » seul : 39 px.
        TableauBouton(
          pleineLargeur: true,
          fond: TytoColors.fauve,
          echellePresse: 0.98,
          opacite: pret ? 1.0 : 0.5,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          hauteurContenu: _enregistrement ? null : 19.5,
          hauteurLigne: _enregistrement ? null : 17,
          onTap: pret ? _enregistrer : null,
          child: libelleBouton(
            icone: _enregistrement ? null : const SiteIcon('IconCheck', size: 14, color: TytoColors.nuit),
            ecart: 6,
            texte: _enregistrement ? 'Enregistrement…' : 'Valider et ajouter au carnet',
            taille: 14.5,
            couleur: TytoColors.nuit,
          ),
        ),
        // En plus du site : transformer l'ordonnance en dossier de soins
        // avec rappels de prise.
        const SizedBox(height: 8),
        BoutonPilule(
          texte: 'Créer un dossier de soins avec rappels',
          onTap: _creerDossier,
          actif: pret,
          bord: const Color(0x332A2118),
          encre: TytoColors.encre,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          taille: 13.5,
        ),
      ] else if (r.readable)
        Text(
          "Aucun traitement n'a pu être identifié sur cette photo.",
          style: interligne(TytoText.ui(size: 12.5, weight: FontWeight.w400, color: encreA(0x99)), 1.45),
        ),
      const SizedBox(height: 10),
      LienDiscret(texte: 'Reprendre une autre photo', onTap: _reprendre, centre: true),
    ];
  }

  Widget _ligne(_LigneEditable l) {
    final champ = TytoText.ui(size: 12.5, weight: FontWeight.w400, color: Colors.black);
    InputDecoration petit(String indication) => decorationChampPapier(
          indication: indication,
          taille: 12.5,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          rayon: 6,
          bord: const Color(0x222A2118),
        );
    const traitBas = UnderlineInputBorder(borderSide: BorderSide(color: Color(0x222A2118)));
    void basculer() => setState(() => l.checked = !l.checked);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: basculer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: l.checked ? Colors.white : const Color(0x08000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x222A2118)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 3),
              child: _CaseNavigateur(coche: l.checked),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: l.medicament,
                    style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: Colors.black),
                    decoration: const InputDecoration(
                      isDense: true,
                      // padding 2 / 0 et le trait d'1 px dessous : 22 px.
                      contentPadding: EdgeInsets.fromLTRB(0, 2, 0, 3),
                      border: traitBas,
                      enabledBorder: traitBas,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: TytoColors.fauve, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, contraintes) {
                      final dose = TextField(controller: l.dose, style: champ, decoration: petit('dose'));
                      final fois = SizedBox(
                        width: 64,
                        child: TextField(
                          controller: l.fois,
                          keyboardType: TextInputType.number,
                          style: champ,
                          decoration: petit('x/jour'),
                        ),
                      );
                      final jours = SizedBox(
                        width: 64,
                        child: TextField(
                          controller: l.jours,
                          keyboardType: TextInputType.number,
                          style: champ,
                          decoration: petit('jours'),
                        ),
                      );
                      // Le retour à la ligne du site (flex-wrap, écart de 6) :
                      // « dose » ne descend pas sous 164 px. Tout tient sur
                      // une ligne dès 310 px ; dès 240 px, seuls « jours »
                      // passe dessous ; en deçà, les deux petits champs.
                      final w = contraintes.maxWidth;
                      if (w >= 310) {
                        return Row(children: [
                          Expanded(child: dose),
                          const SizedBox(width: 6),
                          fois,
                          const SizedBox(width: 6),
                          jours,
                        ]);
                      }
                      if (w >= 240) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Expanded(child: dose), const SizedBox(width: 6), fois]),
                            const SizedBox(height: 6),
                            jours,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dose,
                          const SizedBox(height: 6),
                          Row(children: [fois, const SizedBox(width: 6), jours]),
                        ],
                      );
                    },
                  ),
                  // « Lecture incertaine » : 11 px gras, roux, l'icône
                  // centrée sur le texte (qui passe sur deux lignes sur un
                  // téléphone). Sur une seule ligne, le navigateur laisse
                  // 2 px dessous (zone de 15 px pour une ligne de 13).
                  if (l.incertaine)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 15),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            children: [
                              const SiteIcon('IconAlert', size: 11, color: Color(0xFFA35A2E)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  "Lecture incertaine — vérifie sur l'ordonnance originale",
                                  style: TytoText.ui(size: 11, weight: FontWeight.w700, color: const Color(0xFFA35A2E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// La case à cocher du navigateur (13 px, bleu #0075FF une fois cochée),
/// telle qu'elle apparaît dans la fenêtre du site.
class _CaseNavigateur extends StatelessWidget {
  final bool coche;
  const _CaseNavigateur({required this.coche});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: coche ? const Color(0xFF0075FF) : Colors.white,
        borderRadius: BorderRadius.circular(2.5),
        border: coche ? null : Border.all(color: const Color(0xFF767676)),
      ),
      child: coche ? CustomPaint(painter: _CochePainter()) : null,
    );
  }
}

class _CochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final chemin = Path()
      ..moveTo(w * 0.22, w * 0.52)
      ..lineTo(w * 0.42, w * 0.72)
      ..lineTo(w * 0.78, w * 0.3);
    canvas.drawPath(chemin, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
