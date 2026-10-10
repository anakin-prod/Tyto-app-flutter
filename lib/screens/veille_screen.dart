import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/paw_trails.dart';
import '../widgets/pro_upsell.dart';
import '../widgets/site_icons.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/drawer_navigation.dart';
import '../services/user_service.dart';
import 'emergency_sheet.dart';
import 'tableau_entete.dart';
import 'tableau_site.dart';

/// Un bilan de la veille, tel que le renvoie /api/watch.
class _Bilan {
  final String niveau; // alert, watch ou ok
  final String date; // AAAA-MM-JJ
  final String contenu;
  const _Bilan({required this.niveau, required this.date, required this.contenu});

  static _Bilan? lire(dynamic r) {
    if (r is! Map) return null;
    return _Bilan(
      niveau: (r['alert_level'] ?? '').toString(),
      date: (r['report_date'] ?? '').toString(),
      contenu: (r['content'] ?? '').toString(),
    );
  }

  /// JJ/MM/AAAA, comme frDate() du site.
  String get dateFr {
    final p = date.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : date;
  }
}

/// La veille sanitaire Pro, comme l'onglet Veille du site : Tyto relit le
/// journal de tous les compagnons (même route /api/watch que le site) et
/// rend un bilan coloré selon le niveau d'alerte.
class VeilleScreen extends StatefulWidget {
  const VeilleScreen({super.key});

  @override
  State<VeilleScreen> createState() => _VeilleScreenState();
}

class _VeilleScreenState extends State<VeilleScreen> {
  static const _baseUrl = 'https://tytoai.app';

  // Le texte du bouton vert et de ses icônes : #0f2a24.
  static const _encreVerte = Color(0xFF0F2A24);

  bool _loading = true;
  bool _running = false;
  _Bilan? _bilan;
  bool _isPro = false;
  bool _isPremium = false;
  Pet? _premier; // le compagnon actif par défaut, pour la fenêtre d'urgence

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    final token = AuthService.currentSession?.accessToken;
    if (token != null) {
      final profil = await UserService.fetchMe(token);
      if (mounted) setState(() { _isPro = profil.pro; _isPremium = profil.premium; });
      // Le dernier bilan, s'il existe (loadWatch du site).
      if (profil.pro) {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/api/watch'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (res.statusCode == 200) {
            final d = jsonDecode(res.body);
            final bilan = d is Map ? _Bilan.lire(d['report']) : null;
            if (mounted) setState(() => _bilan = bilan);
          }
        } catch (e) {
          // Pas de bilan affiché : on peut toujours relancer la veille.
        }
      }
    }
    if (mounted) setState(() => _loading = false);
    try {
      final pets = await DataService.loadPets();
      if (mounted && pets.isNotEmpty) setState(() => _premier = pets.first);
    } catch (e) {
      // Sans compagnon connu, la fenêtre d'urgence demande l'espèce et le poids.
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  void _ouvrirUrgence() {
    final p = _premier;
    EmergencySheet.ouvrir(context, petId: p?.id, petName: p?.name, petWeight: p?.weightKg);
  }

  /// runWatch du site : réservé au plan Pro, sinon on présente l'offre.
  Future<void> _runWatch() async {
    if (_loading || _running) return;
    if (!_isPro) return ProUpsell.afficher(context);
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    setState(() => _running = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/watch'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      final d = jsonDecode(res.body);
      final bilan = (res.statusCode == 200 && d is Map) ? _Bilan.lire(d['report']) : null;
      if (bilan != null) {
        if (mounted) setState(() => _bilan = bilan);
      } else if (d is Map && d['error'] == 'no_pets') {
        _message("Ajoute d'abord au moins un compagnon.");
      } else {
        _message("La veille n'a pas pu être générée. Réessaie dans un instant.");
      }
    } catch (e) {
      _message("La veille n'a pas pu être générée. Réessaie dans un instant.");
    }
    if (mounted) setState(() => _running = false);
  }

  /// La ligne d'astuce sous le bouton. Sur le site, l'ampoule (13 px) est
  /// un élément flexible à côté d'un long texte : le navigateur la rétrécit
  /// d'autant que le texte déborde (7,8 px de large sur un téléphone de
  /// 390 px). On refait le même calcul pour la même petite ampoule.
  Widget _astuce() {
    const texte =
        "Plus tu notes d'observations dans le Carnet (à la voix, c'est plus rapide), plus la veille est pertinente.";
    final couleur = TytoColors.encre.withAlpha(0x88);
    final style = interligne(TytoText.ui(size: 11.5, color: couleur), 1.4);
    return LayoutBuilder(
      builder: (context, contraintes) {
        final mesure = TextPainter(
          text: TextSpan(text: texte, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final largeurTexte = mesure.width;
        final depasse = 13 + 6 + largeurTexte - contraintes.maxWidth;
        final double ampoule = depasse > 0 ? math.max(0.0, 13 - depasse * 13 / (13 + largeurTexte)) : 13.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SizedBox(
                width: ampoule,
                height: 13,
                child: Center(child: SiteIcon('IconBulb', size: ampoule, color: couleur)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(texte, style: style)),
          ],
        );
      },
    );
  }

  /// La carte de présentation : titre, pastille PRO, texte, bouton vert.
  Widget _carteVeille() {
    const encre = TytoColors.encre;
    // Le libellé du bouton : avec une icône, le navigateur laisse 3 px
    // sous la ligne (42 px de haut) ; sans icône (« Tyto examine… »),
    // le bouton ne fait plus que 39 px.
    final bouton = TableauBouton(
      pleineLargeur: true,
      fond: TytoColors.vert,
      opacite: _running ? 0.6 : 1.0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      hauteurContenu: _running ? 17 : 20,
      hauteurLigne: 17,
      onTap: _running ? null : _runWatch,
      child: libelleBouton(
        icone: _running
            ? null
            : SiteIcon(_bilan != null ? 'IconRefresh' : 'IconMonitor', size: 15, color: _encreVerte),
        ecart: 7,
        texte: _running
            ? 'Tyto examine tes animaux…'
            : _bilan != null
                ? 'Relancer la veille'
                : 'Lancer la veille du jour',
        taille: 14,
        couleur: _encreVerte,
      ),
    );
    return FenetrePapier(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ligne de titre : 26,5 px de haut sur le site, le titre calé en
          // haut, la pastille PRO centrée.
          SizedBox(
            height: 26.5,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      height: 24,
                      child: Row(
                        children: [
                          const SiteIcon('IconMonitor', size: 19, color: encre),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Veille sanitaire',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TytoText.display(size: 19, color: encre),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: TytoColors.vert.withAlpha(0x33),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: TytoColors.vert),
                  ),
                  child: Text(
                    'PRO',
                    style: TytoText.ui(size: 10.5, weight: FontWeight.w700, color: const Color(0xFF1C4A40))
                        .copyWith(letterSpacing: 0.63),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Tyto relit le journal de '),
                TextSpan(
                  text: 'tous tes compagnons',
                  style: GoogleFonts.newsreader(fontSize: 15, fontWeight: FontWeight.w700, color: encre),
                ),
                const TextSpan(
                  text: " et repère ce que personne n'a le temps de croiser : tendances de poids, baisses "
                      "d'appétit répétées, symptômes communs à plusieurs animaux, échéances oubliées.",
                ),
              ],
            ),
            style: interligne(TytoText.body(size: 15, color: encre), 1.55),
          ),
          const SizedBox(height: 12),
          bouton,
          const SizedBox(height: 8),
          _astuce(),
        ],
      ),
    );
  }

  /// Le bilan, sur papier, avec le filet gauche de 4 px de la couleur du
  /// niveau (le reste du bord : 1 px d'encre à 15 %).
  Widget _carteBilan(_Bilan b) {
    const encre = TytoColors.encre;
    final filet = b.niveau == 'alert'
        ? const Color(0xFFC9553F)
        : b.niveau == 'watch'
            ? TytoColors.fauve
            : TytoColors.vert;
    final teinte = b.niveau == 'alert'
        ? TytoColors.urgence
        : b.niveau == 'watch'
            ? const Color(0xFFA35A2E)
            : const Color(0xFF2E6A55);
    final icone = b.niveau == 'alert'
        ? 'IconAlert'
        : b.niveau == 'watch'
            ? 'IconEye'
            : 'IconCheck';
    final titre = b.niveau == 'alert'
        ? 'Action requise'
        : b.niveau == 'watch'
            ? 'Points à surveiller'
            : 'Rien à signaler';
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        // ombre CSS 0 3px 14px rgba(0,0,0,.28) (flou de 14 px = 11,3 ici)
        boxShadow: [BoxShadow(color: Color(0x47000000), offset: Offset(0, 3), blurRadius: 11.3)],
      ),
      child: CustomPaint(
        painter: _FiletGauchePainter(filet),
        child: Padding(
          // bord 4 / 1 / 1 / 1 + padding 12 16 14
          padding: const EdgeInsets.fromLTRB(20, 13, 17, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SiteIcon(icone, size: 18, color: teinte),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(titre, style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: encre)),
                  ),
                  const SizedBox(width: 8),
                  Text(b.dateFr, style: TytoText.ui(size: 11.5, color: encre.withAlpha(0x88))),
                ],
              ),
              const SizedBox(height: 8),
              Text(b.contenu, style: interligne(TytoText.body(size: 15.5, color: encre), 1.65)),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: encre.withAlpha(0x1a))),
                ),
                child: Text(
                  'Tyto signale, il ne diagnostique pas. En cas de doute, consulte un vétérinaire.',
                  style: interligne(TytoText.ui(size: 11, color: encre.withAlpha(0x77)), 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Comme le site, la rubrique s'affiche aussi sans compte : le bouton
  /// présente alors l'offre Pro.
  Widget _corps() {
    return SingleChildScrollView(
      // 8 px sous l'en-tête + 16 px, comme le site ; 720 px au plus.
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 688),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _carteVeille(),
              const SizedBox(height: 14),
              if (_bilan != null) _carteBilan(_bilan!),
              if (_bilan == null && !_running && !_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "Aucun bilan pour l'instant — lance la veille pour commencer.",
                    textAlign: TextAlign.center,
                    style: TytoText.ui(size: 14, color: TytoColors.brume),
                  ),
                ),
            ],
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
        activeId: 'veille',
        onSelect: (id) => handleDrawerNavigation(context, 'veille', id),
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

/// Le contour de la carte du bilan, dessiné comme le navigateur : filet
/// gauche de 4 px dans la couleur du niveau, 1 px d'encre à 15 % ailleurs,
/// rayon 12, et dans les coins la couleur de gauche s'arrête sur la
/// diagonale qui joint le coin extérieur au coin intérieur.
class _FiletGauchePainter extends CustomPainter {
  final Color filet;
  _FiletGauchePainter(this.filet);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ext = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final interieur = RRect.fromLTRBAndCorners(
      4,
      1,
      w - 1,
      h - 1,
      topLeft: const Radius.elliptical(8, 11),
      bottomLeft: const Radius.elliptical(8, 11),
      topRight: const Radius.circular(11),
      bottomRight: const Radius.circular(11),
    );
    canvas.drawRRect(ext, Paint()..color = TytoColors.papier);
    final anneau = Path.combine(
      PathOperation.difference,
      Path()..addRRect(ext),
      Path()..addRRect(interieur),
    );
    final gauche = Path()
      ..moveTo(0, 0)
      ..lineTo(48, 12)
      ..lineTo(48, h - 12)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      Path.combine(PathOperation.difference, anneau, gauche),
      Paint()..color = const Color(0x262A2118),
    );
    canvas.drawPath(Path.combine(PathOperation.intersect, anneau, gauche), Paint()..color = filet);
  }

  @override
  bool shouldRepaint(covariant _FiletGauchePainter old) => old.filet != filet;
}
