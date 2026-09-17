import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../data/lostpet.dart';
import '../services/emergency_service.dart';

/// SOS animal perdu — le plan d'action complet, repris du site :
/// I-CAD, recherche sur le terrain, affiche à partager, conseils par
/// espèce, avertissement anti-arnaque.
class LostPetScreen extends StatefulWidget {
  final Pet pet;
  const LostPetScreen({super.key, required this.pet});

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

  @override
  void dispose() {
    _where.dispose();
    _signs.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
    final picker = ImagePicker();
    // La photo reste sur l'appareil : elle ne sert qu'à composer
    // l'affiche, jamais envoyée à un serveur.
    final choisie = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (choisie != null) setState(() => _photo = File(choisie.path));
  }

  String _todayFr() {
    final n = DateTime.now();
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${n.day} ${mois[n.month - 1]} ${n.year}';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, size: 18, color: TytoColors.urgence),
            const SizedBox(width: 8),
            Text('${p.name} a disparu', style: TytoText.display(size: 18, color: TytoColors.urgence)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TytoColors.papier,
            borderRadius: BorderRadius.circular(14),
            border: const Border(top: BorderSide(color: TytoColors.urgence, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Le plan d'action complet, dans l'ordre qui compte. Courage — la plupart "
                'des animaux perdus sont retrouvés.',
                style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6)),
              ),
              const SizedBox(height: 14),

              _bloc(
                titre: estChienOuChat
                    ? '1. Déclare la perte sur I-CAD — le fichier national officiel'
                    : '1. Bon à savoir',
                enfant: estChienOuChat
                    ? RichText(
                        text: TextSpan(
                          style: TytoText.body(size: 13, color: TytoColors.encre).copyWith(height: 1.6),
                          children: [
                            TextSpan(
                              text: "C'est LE réflexe qui retrouve les animaux : vétérinaires, fourrières et "
                                  "refuges consultent ce fichier chaque jour. Si quelqu'un trouve ${p.name} "
                                  'et fait lire sa puce, tu seras contacté.\n',
                            ),
                            const TextSpan(
                              text: "Il te faut son numéro d'identification",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: " (sur sa carte d'identification, ou demande à ton vétérinaire).\n"),
                            const TextSpan(text: 'i-cad.fr', style: TextStyle(fontWeight: FontWeight.w700)),
                            const TextSpan(text: ' — déclarer la perte · tél. 09 77 40 30 77\n'),
                            const TextSpan(
                              text: "L'appli officielle Filalapat (par I-CAD) montre aussi les animaux trouvés autour de toi.",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        'Le fichier national I-CAD ne couvre que les chiens, chats et furets — pour '
                        "${p.name}, concentre-toi sur les étapes suivantes : elles sont d'autant plus importantes.",
                        style: TytoText.body(size: 13, color: TytoColors.encre).copyWith(height: 1.6),
                      ),
              ),

              _bloc(
                titre: '2. Préviens le terrain',
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appelle les vétérinaires du secteur, les refuges, et ta mairie pour obtenir le '
                      'numéro de la fourrière.\nImportant : une fourrière ne garde un animal que 8 jours '
                      "ouvrés — appelle-la régulièrement, ne te contente pas d'un seul appel.",
                      style: TytoText.body(size: 13, color: TytoColors.encre).copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: EmergencyService.findVet,
                      icon: const Icon(Icons.local_hospital_outlined, size: 14, color: TytoColors.encre),
                      label: Text('Vétérinaires près de moi', style: TytoText.ui(size: 12.5, color: TytoColors.encre)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: TytoColors.encre.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ],
                ),
              ),

              _bloc(
                titre: "3. L'affiche et l'annonce à partager",
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _champ(_where, 'Dernier lieu où il a été vu (quartier, rue, ville)'),
                    const SizedBox(height: 7),
                    _champ(_signs, 'Signes distinctifs (couleur, collier, tache...)'),
                    const SizedBox(height: 7),
                    _champ(_phone, "Ton numéro de téléphone (affiché sur l'annonce)", clavier: TextInputType.phone),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _choisirPhoto,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 14, color: TytoColors.encre.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            _photo != null ? 'Photo ajoutée — appuie pour changer' : 'Ajouter sa photo (reste sur ton appareil)',
                            style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _generation ? null : _genererAffiche,
                          icon: _generation
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.print_outlined, size: 15, color: Colors.white),
                          label: Text("Générer l'affiche", style: TytoText.ui(size: 13, weight: FontWeight.w700, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TytoColors.urgence,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _copierAnnonce,
                          icon: Icon(_copie ? Icons.check_rounded : Icons.copy_rounded, size: 14, color: TytoColors.encre),
                          label: Text(_copie ? 'Copié !' : "Copier l'annonce",
                              style: TytoText.ui(size: 13, weight: FontWeight.w700, color: TytoColors.encre)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: TytoColors.encre.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Colle l'annonce dans les groupes Facebook de ta ville (cherche « animaux perdus + "
                      'ta ville »), Filalapat, et les groupes WhatsApp de quartier.',
                      style: TytoText.ui(size: 11, color: TytoColors.encre.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),

              _bloc(
                titre: '4. Comment chercher un ${p.species} — les bons réflexes',
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lostAdviceFor(p.species)
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text('•  $a', style: TytoText.body(size: 13, color: TytoColors.encre).copyWith(height: 1.6)),
                          ))
                      .toList(),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(13),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: TytoColors.urgence.withOpacity(0.06),
                  border: Border.all(color: TytoColors.urgence.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: TytoColors.urgence),
                        const SizedBox(width: 6),
                        Text('Vol ou arnaque', style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: TytoColors.encre)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Si tu penses qu'il a été volé : dépose plainte (police ou gendarmerie) d'abord, "
                      'puis signale-le à I-CAD avec le récépissé.\n$lostScamWarning',
                      style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.8)).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),

              Text(
                'Quand ${p.name} sera retrouvé, pense à le déclarer « retrouvé » sur I-CAD, et à retirer '
                'tes annonces. Bonne chance — on croise les plumes.',
                style: TytoText.ui(size: 11, color: TytoColors.encre.withOpacity(0.55)).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bloc({required String titre, required Widget enfant}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TytoText.ui(size: 14, weight: FontWeight.w700, color: TytoColors.encre)),
          const SizedBox(height: 6),
          enfant,
        ],
      ),
    );
  }

  Widget _champ(TextEditingController c, String hint, {TextInputType? clavier}) {
    return TextField(
      controller: c,
      keyboardType: clavier,
      style: TytoText.ui(size: 13.5, color: TytoColors.encre),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TytoText.ui(size: 13.5, color: TytoColors.encre.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2))),
      ),
    );
  }
}

/// L'affiche elle-même — la version image de la page imprimable du site.
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

  @override
  Widget build(BuildContext context) {
    final sp = pet.species.isNotEmpty ? pet.species[0].toUpperCase() + pet.species.substring(1) : 'Animal';
    return Container(
      width: 720,
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('PERDU',
              style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFFB3261E))),
          Text(
            sp + (pet.breed != null && pet.breed!.trim().isNotEmpty ? ' — ${pet.breed}' : '') + ' « ${pet.name} »',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, color: Colors.black, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(photo!, height: 320, fit: BoxFit.contain),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 70),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF999999), width: 3, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('Collez ici une photo de ${pet.name}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF777777))),
            ),
          const SizedBox(height: 14),
          if (signs.trim().isNotEmpty)
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Signes distinctifs : ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: signs.trim()),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, color: Colors.black, height: 1.5),
            ),
          if (where.trim().isNotEmpty)
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Vu pour la dernière fois : ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: where.trim()),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, color: Colors.black, height: 1.5),
            ),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Depuis le : ', style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: dateFr),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, color: Colors.black, height: 1.5),
          ),
          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 3), borderRadius: BorderRadius.circular(12)),
              child: Text("Si vous l'apercevez : ${phone.trim()}",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
          const SizedBox(height: 18),
          const Text('Affiche générée avec tytoai.app', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
        ],
      ),
    );
  }
}
