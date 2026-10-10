import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../models/pet.dart';
import '../data/lostpet.dart';
import '../services/emergency_service.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/animaux_styles.dart';

/// SOS animal perdu — le plan d'action complet, repris du site :
/// I-CAD, recherche sur le terrain, affiche à partager, conseils par
/// espèce, avertissement anti-arnaque.
class LostPetScreen extends StatefulWidget {
  final Pet pet;
  const LostPetScreen({super.key, required this.pet});

  /// Ouvre la fenêtre par-dessus l'écran courant, comme sur le site (le
  /// voile laisse deviner la page derrière).
  static Future<void> ouvrir(BuildContext context, Pet pet) {
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => LostPetScreen(pet: pet),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<LostPetScreen> createState() => _LostPetScreenState();
}

class _LostPetScreenState extends State<LostPetScreen> {
  final _where = TextEditingController();
  final _signs = TextEditingController();
  final _phone = TextEditingController();
  File? _photo;
  bool _copie = false;
  bool _generation = false;
  // Le lien « i-cad.fr — déclarer la perte » du site.
  late final TapGestureRecognizer _lienIcad = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.parse('https://www.i-cad.fr'), mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _where.dispose();
    _signs.dispose();
    _phone.dispose();
    _lienIcad.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
    final picker = ImagePicker();
    // La photo reste sur l'appareil : elle ne sert qu'à composer
    // l'affiche, jamais envoyée à un serveur.
    final choisie = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (choisie != null) setState(() => _photo = File(choisie.path));
  }

  /// La date du jour comme frDate(todayISO()) sur le site : 09/10/2026.
  String _todayFr() {
    final n = DateTime.now();
    String deux(int v) => v.toString().padLeft(2, '0');
    return '${deux(n.day)}/${deux(n.month)}/${n.year}';
  }

  String _buildLostText() {
    final p = widget.pet;
    final sp = p.species.isNotEmpty ? p.species[0].toUpperCase() + p.species.substring(1) : 'Animal';
    final buf = StringBuffer('PERDU — $sp');
    if (p.breed != null && p.breed!.trim().isNotEmpty) buf.write(' ${p.breed}');
    buf.write(' répondant au nom de ${p.name}');
    if (_where.text.trim().isNotEmpty) buf.write(', vu pour la dernière fois vers ${_where.text.trim()}');
    buf.write(', le ${_todayFr()}.');
    if (_signs.text.trim().isNotEmpty) buf.write(' Signes distinctifs : ${_signs.text.trim()}.');
    if (_phone.text.trim().isNotEmpty) {
      buf.write(" Si vous l'apercevez, merci de me contacter au ${_phone.text.trim()}.");
    }
    buf.write(' Merci de partager, chaque partage compte !');
    return buf.toString();
  }

  Future<void> _copierAnnonce() async {
    await Clipboard.setData(ClipboardData(text: _buildLostText()));
    setState(() => _copie = true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _copie = false);
    });
  }

  /// L'affiche remplace l'impression du site : on la dessine hors-écran
  /// (via l'Overlay), on la capture en image, puis on la partage —
  /// vers WhatsApp, les Fichiers, ou une appli d'impression.
  Future<void> _genererAffiche() async {
    if (_generation) return;
    setState(() => _generation = true);

    // On force le décodage complet de la photo AVANT de dessiner l'affiche :
    // sans ça, une photo un peu lourde n'avait pas fini de se charger au
    // moment de la capture, et apparaissait vide sur l'affiche partagée.
    if (_photo != null) {
      try {
        await precacheImage(FileImage(_photo!), context);
      } catch (e) {
        // Une photo illisible ne doit pas empêcher de générer l'affiche
        // sans elle.
      }
    }

    // L'affiche du site est écrite en Arial : Arimo en a exactement les
    // mesures. On attend qu'elle soit chargée (sans bloquer si le réseau
    // manque : l'affiche part alors avec la police du téléphone).
    try {
      GoogleFonts.arimo(fontWeight: FontWeight.w400);
      GoogleFonts.arimo(fontWeight: FontWeight.w700);
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 4));
    } catch (e) {
      // police indisponible : on continue
    }
    if (!mounted) return;

    final key = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000, // hors de l'écran visible, mais bien dessiné
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(key: key, child: _PosterAffiche(pet: widget.pet, photo: _photo, where: _where.text, signs: _signs.text, phone: _phone.text, dateFr: _todayFr())),
        ),
      ),
    );

    try {
      Overlay.of(context).insert(entry);
      // On laisse deux images passer pour être sûr que tout (police,
      // photo) a fini de se dessiner avant la capture.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/affiche_${widget.pet.name}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());

      entry.remove();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Affiche pour ${widget.pet.name}, disparu·e.',
      );
    } catch (e) {
      entry.remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La génération de l'affiche n'a pas abouti, réessaie.")),
      );
    } finally {
      if (mounted) setState(() => _generation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pet;
    final estChienOuChat = p.species == 'chien' || p.species == 'chat';
    final corps = karla(13, interligne: 1.6);
    const gras = TextStyle(fontWeight: FontWeight.w700);

    // La fenêtre du site : voile rgba(10,14,24,0.8), carte papier de 520 px
    // au plus, haute de 85 % de l'écran au plus, qui défile à l'intérieur.
    // Toucher le voile la ferme, comme sur le site.
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
                    maxWidth: 520,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FenetrePapier(
                      lisere: TytoColors.urgence,
                      padding: EdgeInsets.zero,
                      // Ce qui défile reste dans l'arrondi intérieur de la
                      // carte (12 px moins le bord : 4 px en haut, 1 px ailleurs).
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.elliptical(11, 8),
                          topRight: Radius.elliptical(11, 8),
                          bottomLeft: Radius.circular(11),
                          bottomRight: Radius.circular(11),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const IconeTrait.alerte(size: 18, color: TytoColors.urgence),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('${p.name} a disparu', style: fraunces(19, couleur: TytoColors.urgence)),
                                  ),
                                  const SizedBox(width: 8),
                                  CroixFermerAnimaux(onTap: () => Navigator.pop(context)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Le plan d'action complet, dans l'ordre qui compte. Courage — la plupart "
                                'des animaux perdus sont retrouvés.',
                                style: karla(12.5, couleur: encreA(0x99)),
                              ),
                              const SizedBox(height: 14),

                              estChienOuChat
                                  ? _bloc(
                                      titre: '1. Déclare la perte sur I-CAD — le fichier national officiel',
                                      enfant: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "C'est LE réflexe qui retrouve les animaux : vétérinaires, fourrières et "
                                                  "refuges consultent ce fichier chaque jour. Si quelqu'un trouve ${p.name} "
                                                  'et fait lire sa puce, tu seras contacté.\nIl te faut son ',
                                            ),
                                            const TextSpan(text: "numéro d'identification", style: gras),
                                            const TextSpan(
                                              text: " (sur sa carte d'identification, ou demande à ton vétérinaire).\n",
                                            ),
                                            TextSpan(
                                              text: 'i-cad.fr — déclarer la perte',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                decoration: TextDecoration.underline,
                                                decorationColor: TytoColors.encre,
                                              ),
                                              recognizer: _lienIcad,
                                            ),
                                            const TextSpan(text: " · tél. 09 77 40 30 77\nL'appli officielle "),
                                            const TextSpan(text: 'Filalapat', style: gras),
                                            const TextSpan(text: ' (par I-CAD) montre aussi les animaux trouvés autour de toi.'),
                                          ],
                                        ),
                                        style: corps,
                                      ),
                                    )
                                  : _bloc(
                                      titre: '1. Bon à savoir',
                                      enfant: Text(
                                        'Le fichier national I-CAD ne couvre que les chiens, chats et furets — pour '
                                        "${p.name}, concentre-toi sur les étapes suivantes : elles sont d'autant plus importantes.",
                                        style: corps,
                                      ),
                                    ),

                              _bloc(
                                titre: '2. Préviens le terrain',
                                enfant: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      const TextSpan(
                                        children: [
                                          TextSpan(text: 'Appelle les '),
                                          TextSpan(text: 'vétérinaires du secteur', style: gras),
                                          TextSpan(text: ', les '),
                                          TextSpan(text: 'refuges', style: gras),
                                          TextSpan(text: ', et ta '),
                                          TextSpan(text: 'mairie', style: gras),
                                          TextSpan(text: ' pour obtenir le numéro de la fourrière.\n'),
                                          TextSpan(text: 'Important :', style: gras),
                                          TextSpan(
                                            text: ' une fourrière ne garde un animal que 8 jours ouvrés — appelle-la '
                                                "régulièrement, ne te contente pas d'un seul appel.",
                                          ),
                                        ],
                                      ),
                                      style: corps,
                                    ),
                                    const SizedBox(height: 8),
                                    BoutonPilule(
                                      texte: 'Vétérinaires près de moi',
                                      onTap: EmergencyService.findVet,
                                      bord: const Color(0x442A2118),
                                      encre: TytoColors.encre,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      taille: 12.5,
                                      gras: false,
                                      icone: const IconeTrait.croix(size: 13, color: TytoColors.encre),
                                      ecart: 6,
                                    ),
                                  ],
                                ),
                              ),

                              _bloc(
                                titre: "3. L'affiche et l'annonce à partager",
                                enfant: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _champ(_where, 'Dernier lieu où il a été vu (quartier, rue, ville)'),
                                    const SizedBox(height: 7),
                                    _champ(_signs, 'Signes distinctifs (couleur, collier, tache...)'),
                                    const SizedBox(height: 7),
                                    _champ(_phone, "Ton numéro de téléphone (affiché sur l'annonce)", clavier: TextInputType.phone),
                                    // 7 px de marge + 1 px : le libellé est posé
                                    // sur la ligne de texte du navigateur.
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _choisirPhoto,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconeTrait.appareil(size: 14, color: encreA(0xAA)),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _photo != null
                                                    ? 'Photo ajoutée — appuie pour changer'
                                                    : 'Ajouter sa photo (reste sur ton appareil)',
                                                style: karla(12.5, couleur: encreA(0xAA)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        BoutonPilule(
                                          texte: "Générer l'affiche",
                                          onTap: _genererAffiche,
                                          actif: !_generation,
                                          opaciteInactive: 0.6,
                                          fond: TytoColors.urgence,
                                          encre: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                          taille: 13,
                                          ecart: 6,
                                          icone: _generation
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const IconeTrait.imprimante(size: 14, color: Colors.white),
                                        ),
                                        BoutonPilule(
                                          texte: _copie ? 'Copié !' : "Copier l'annonce",
                                          onTap: _copierAnnonce,
                                          bord: const Color(0x442A2118),
                                          encre: TytoColors.encre,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                          taille: 13,
                                          ecart: 6,
                                          icone: _copie ? const IconeTrait.coche(size: 14, color: TytoColors.encre) : null,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Colle l'annonce dans les groupes Facebook de ta ville (cherche « animaux perdus + "
                                      'ta ville »), Filalapat, et les groupes WhatsApp de quartier.',
                                      style: karla(11, couleur: encreA(0x77)),
                                    ),
                                  ],
                                ),
                              ),

                              _bloc(
                                titre: '4. Comment chercher un ${p.species.isNotEmpty ? p.species : 'animal'} — les bons réflexes',
                                enfant: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  // La puce ronde du navigateur : 4 px, à 3 px
                                  // du bord, son centre 4 px au-dessus de la
                                  // ligne de base de la première ligne.
                                  children: lostAdviceFor(p.species)
                                      .map((a) => Padding(
                                            padding: const EdgeInsets.only(bottom: 5),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 3, top: 9.2),
                                                    child: Align(
                                                      alignment: Alignment.topLeft,
                                                      child: Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration: const BoxDecoration(
                                                          color: TytoColors.encre,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(child: Text(a, style: karla(13, interligne: 1.65))),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0x0DC9553F),
                                  border: Border.all(color: const Color(0x66C9553F)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const IconeTrait.alerte(size: 13, color: TytoColors.encre),
                                        const SizedBox(width: 6),
                                        Text('Vol ou arnaque', style: karla(13.5, poids: FontWeight.w700)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text.rich(
                                      const TextSpan(
                                        children: [
                                          TextSpan(text: "Si tu penses qu'il a été "),
                                          TextSpan(text: 'volé', style: gras),
                                          TextSpan(
                                            text: " : dépose plainte (police ou gendarmerie) d'abord, puis signale-le "
                                                'à I-CAD avec le récépissé.\n$lostScamWarning',
                                          ),
                                        ],
                                      ),
                                      style: karla(12.5, interligne: 1.6),
                                    ),
                                  ],
                                ),
                              ),

                              Text(
                                'Quand ${p.name} sera retrouvé, pense à le déclarer « retrouvé » sur I-CAD, et à retirer '
                                'tes annonces. Bonne chance — on croise les plumes.',
                                style: karla(11, couleur: encreA(0x77), interligne: 1.4),
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
      ),
    );
  }

  /// Un bloc du plan d'action : bord encre à 15 %, fond blanc à 33 %.
  Widget _bloc({required String titre, required Widget enfant}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x262A2118)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titre, style: karla(14, poids: FontWeight.w700)),
          const SizedBox(height: 6),
          enfant,
        ],
      ),
    );
  }

  /// Un champ blanc du site (35 px de haut). Comme dans un <input>, le
  /// texte d'exemple trop long reste sur une ligne et se coupe au bord
  /// (espaces insécables : il ne passe pas à la ligne).
  Widget _champ(TextEditingController c, String hint, {TextInputType? clavier}) {
    return TextField(
      controller: c,
      keyboardType: clavier,
      cursorColor: TytoColors.encre,
      style: karla(13.5),
      decoration: decorationChampPapier(
        indication: hint,
        taille: 13.5,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ).copyWith(
        hintText: hint.replaceAll(' ', '\u00A0'),
        hintMaxLines: 1,
        hintStyle: karla(13.5, couleur: couleurIndication).copyWith(overflow: TextOverflow.clip),
      ),
    );
  }
}

/// L'affiche elle-même — la page imprimable du site (openLostPoster),
/// dessinée en image avec les mêmes mesures : page de 720 px + 20 px de
/// marge, texte #111 centré, en Arial (Arimo, aux mêmes dimensions).
class _PosterAffiche extends StatelessWidget {
  final Pet pet;
  final File? photo;
  final String where, signs, phone, dateFr;
  const _PosterAffiche({
    required this.pet,
    required this.photo,
    required this.where,
    required this.signs,
    required this.phone,
    required this.dateFr,
  });

  static const _noir = Color(0xFF111111);

  static TextStyle _arial(double taille, {bool gras = false, Color couleur = _noir, double? interligne, double? espacement}) {
    return GoogleFonts.arimo(
      fontSize: taille,
      fontWeight: gras ? FontWeight.w700 : FontWeight.w400,
      color: couleur,
      height: interligne,
      letterSpacing: espacement,
    ).copyWith(leadingDistribution: TextLeadingDistribution.even);
  }

  @override
  Widget build(BuildContext context) {
    final sp = pet.species.isNotEmpty ? pet.species[0].toUpperCase() + pet.species.substring(1) : 'Animal';
    final breed = pet.breed;
    final aBreed = breed != null && breed.trim().isNotEmpty;

    // .info : les lignes séparées par <br/>, l'intitulé en gras.
    final infos = <InlineSpan>[];
    void ligne(String intitule, String valeur) {
      if (infos.isNotEmpty) infos.add(const TextSpan(text: '\n'));
      infos.add(TextSpan(text: intitule, style: _arial(19, gras: true, interligne: 1.5)));
      infos.add(TextSpan(text: ' $valeur'));
    }

    if (signs.trim().isNotEmpty) ligne('Signes distinctifs :', signs.trim());
    if (where.trim().isNotEmpty) ligne('Vu pour la dernière fois :', where.trim());
    ligne('Depuis le :', dateFr);

    return Container(
      width: 760,
      color: Colors.white,
      // padding 20 du corps + 6 de marge au-dessus du titre PERDU.
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // h1 : 64 px, gras, lettres espacées de 6 px, rouge #B3261E.
          Text('PERDU',
              textAlign: TextAlign.center,
              style: _arial(64, gras: true, couleur: const Color(0xFFB3261E), espacement: 6)),
          // marges 6 (sous h1) et 4 (sur h2) confondues : 6 px.
          const SizedBox(height: 6),
          Text(
            '$sp${aBreed ? ' — $breed' : ''} « ${pet.name} »',
            textAlign: TextAlign.center,
            style: _arial(30, gras: true),
          ),
          const SizedBox(height: 10),
          if (photo != null) ...[
            // img : bord 3 px #111, coins de 8 px, 46 % de la hauteur de page au plus.
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _noir, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 714, maxHeight: 480),
                  child: Image.file(photo!, fit: BoxFit.contain),
                ),
              ),
            ),
            // l'image est posée sur une ligne de texte : 3 px dessous, puis
            // la marge de 12 px du bloc d'informations.
            const SizedBox(height: 15),
          ] else ...[
            // .ph : cadre en tirets 3 px #999, 70 px dessus et dessous.
            CustomPaint(
              foregroundPainter: const _CadreTirets(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 73),
                child: Text(
                  'Collez ici une photo de ${pet.name}',
                  textAlign: TextAlign.center,
                  style: _arial(15, couleur: const Color(0xFF777777)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text.rich(
            TextSpan(children: infos),
            textAlign: TextAlign.center,
            style: _arial(19, interligne: 1.5),
          ),
          if (phone.trim().isNotEmpty) ...[
            // 12 px sous les informations + 8 px de marge au-dessus.
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _noir, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Si vous l'apercevez : ${phone.trim()}",
                textAlign: TextAlign.center,
                style: _arial(30, gras: true),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Affiche générée avec tytoai.app', style: _arial(11, couleur: const Color(0xFF999999))),
        ],
      ),
    );
  }
}

/// Le cadre en tirets de l'emplacement photo (border: 3px dashed #999,
/// coins de 8 px) : des tirets de 9 px espacés de 9 px, comme le dessine
/// le navigateur pour un bord de 3 px.
class _CadreTirets extends CustomPainter {
  const _CadreTirets();

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = const Color(0xFF999999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final cadre = RRect.fromRectAndRadius((Offset.zero & size).deflate(1.5), const Radius.circular(6.5));
    final trace = Path()..addRRect(cadre);
    for (final mesure in trace.computeMetrics()) {
      double d = 0;
      while (d < mesure.length) {
        canvas.drawPath(mesure.extractPath(d, d + 9), pinceau);
        d += 18;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
