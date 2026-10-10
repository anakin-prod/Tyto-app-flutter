import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

// ============================================================
// Les briques des fenêtres secondaires du site (urgence, animal
// perdu, ordonnance, offres, suppression de compte) : la carte
// « papier », les icônes au trait et les boutons en pilule.
// Valeurs reprises de app/page.js (paperCard, goldBtn, ghostBtn…).
// ============================================================

/// Encre du site avec son opacité, écrite comme sur le site (ENCRE + "aa").
Color encreA(int alpha) => TytoColors.encre.withAlpha(alpha);

/// La couleur des textes d'exemple des champs (navigateur : #757575).
const Color couleurIndication = Color(0xFF757575);

/// La carte « papier » du site (paperCard) : fond ivoire, bord 1 px encre
/// à 15 %, rayon 12, ombre 0 3px 14px rgba(0,0,0,.28). Avec [lisere], le
/// bord du haut fait 4 px dans cette couleur (borderTop des fenêtres
/// d'urgence, de suppression, de l'offre Pro), raccordé dans les coins
/// comme le dessine un navigateur.
class FenetrePapier extends StatelessWidget {
  final Widget child;
  final Color? lisere;
  final EdgeInsets padding;

  const FenetrePapier({
    super.key,
    required this.child,
    this.lisere,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    final haut = lisere != null ? 4.0 : 1.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        // flou CSS de 14 px = écart-type 7 ; Flutter : 7 = r x 0,577 + 0,5
        boxShadow: [BoxShadow(color: Color(0x47000000), offset: Offset(0, 3), blurRadius: 11.3)],
      ),
      child: CustomPaint(
        painter: _PapierPainter(lisere),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            1 + padding.left,
            haut + padding.top,
            1 + padding.right,
            1 + padding.bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PapierPainter extends CustomPainter {
  final Color? lisere;
  _PapierPainter(this.lisere);

  @override
  void paint(Canvas canvas, Size size) {
    final haut = lisere != null ? 4.0 : 1.0;
    final ext = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final interieur = RRect.fromLTRBAndCorners(
      1,
      haut,
      size.width - 1,
      size.height - 1,
      topLeft: Radius.elliptical(11, 12 - haut),
      topRight: Radius.elliptical(11, 12 - haut),
      bottomLeft: const Radius.circular(11),
      bottomRight: const Radius.circular(11),
    );
    canvas.drawRRect(ext, Paint()..color = TytoColors.papier);
    final anneau = Path.combine(
      PathOperation.difference,
      Path()..addRRect(ext),
      Path()..addRRect(interieur),
    );
    final bord = Paint()..color = const Color(0x262A2118);
    if (lisere == null) {
      canvas.drawPath(anneau, bord);
      return;
    }
    // La couleur du haut s'arrête sur la diagonale qui part du coin
    // extérieur selon le rapport des épaisseurs (1 px sur 4 px).
    final dx = 12 / haut;
    final dessus = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - dx, 12)
      ..lineTo(dx, 12)
      ..close();
    canvas.drawPath(Path.combine(PathOperation.difference, anneau, dessus), bord);
    canvas.drawPath(Path.combine(PathOperation.intersect, anneau, dessus), Paint()..color = lisere!);
  }

  @override
  bool shouldRepaint(covariant _PapierPainter old) => old.lisere != lisere;
}

/// Les icônes au trait du site (components/Icons.js), mêmes tracés,
/// grille 24 x 24, trait de 1,6 (1,9 pour la coche).
class IconeTrait extends StatelessWidget {
  final String trace;
  final double size;
  final Color color;
  final double epaisseur;

  const IconeTrait.alerte({super.key, required this.size, required this.color})
      : trace = _alerte,
        epaisseur = 1.6;
  const IconeTrait.croix({super.key, required this.size, required this.color})
      : trace = _croix,
        epaisseur = 1.6;
  const IconeTrait.appareil({super.key, required this.size, required this.color})
      : trace = _appareil,
        epaisseur = 1.6;
  const IconeTrait.imprimante({super.key, required this.size, required this.color})
      : trace = _imprimante,
        epaisseur = 1.6;
  const IconeTrait.bouclier({super.key, required this.size, required this.color})
      : trace = _bouclier,
        epaisseur = 1.6;
  const IconeTrait.coche({super.key, required this.size, required this.color})
      : trace = _coche,
        epaisseur = 1.9;

  static const _alerte =
      '<path d="M12 3.6 21.2 19.4a1.2 1.2 0 0 1-1 1.8H3.8a1.2 1.2 0 0 1-1-1.8L12 3.6Z" />'
      '<path d="M12 9.4v4.3" />'
      '<circle cx="12" cy="17.2" r="0.9" fill="currentColor" stroke="none" />';
  static const _croix =
      '<rect x="3.4" y="3.4" width="17.2" height="17.2" rx="3.2" />'
      '<path d="M12 7.8v8.4M7.8 12h8.4" />';
  static const _appareil =
      '<path d="M3.4 8.6A1.6 1.6 0 0 1 5 7h2.4l1.3-2.1h6.6L16.6 7H19a1.6 1.6 0 0 1 1.6 1.6v8.8A1.6 1.6 0 0 1 19 19H5a1.6 1.6 0 0 1-1.6-1.6V8.6Z" />'
      '<circle cx="12" cy="12.9" r="3.4" />';
  static const _imprimante =
      '<path d="M7 8.6V3.8h10v4.8" />'
      '<rect x="3.6" y="8.6" width="16.8" height="7" rx="1.6" />'
      '<path d="M7 13.6h10v6.6H7z" />';
  static const _bouclier =
      '<path d="M12 2.8 4.8 5.9v5.3c0 4.4 3 8.5 7.2 9.9 4.2-1.4 7.2-5.5 7.2-9.9V5.9L12 2.8Z" />'
      '<path d="M8.9 11.9l2.1 2.2 4.1-4.4" />';
  static const _coche = '<path d="M4.6 12.6 9.4 17.4 19.4 6.8" />';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="$epaisseur" stroke-linecap="round" '
      'stroke-linejoin="round">$trace</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Un bouton en pilule du site (borderRadius 999) : fond, bord d'1 px
/// éventuel, texte Karla, icône facultative. [actif] à false reproduit
/// l'opacité des boutons désactivés du site.
class BoutonPilule extends StatelessWidget {
  final String texte;
  final VoidCallback? onTap;
  final Color? fond;
  final Color encre;
  final Color? bord;
  final EdgeInsets padding;
  final double taille;
  final bool gras;
  final Widget? icone;
  final double ecart;
  final bool actif;
  final double opaciteInactive;

  const BoutonPilule({
    super.key,
    required this.texte,
    required this.onTap,
    required this.encre,
    required this.padding,
    required this.taille,
    this.fond,
    this.bord,
    this.gras = true,
    this.icone,
    this.ecart = 7,
    this.actif = true,
    this.opaciteInactive = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: actif ? 1 : opaciteInactive,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: actif ? onTap : null,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fond,
            borderRadius: BorderRadius.circular(999),
            border: bord == null ? null : Border.all(color: bord!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icone != null) ...[icone!, SizedBox(width: ecart)],
              Flexible(
                child: Text(
                  texte,
                  textAlign: TextAlign.center,
                  style: TytoText.ui(
                    size: taille,
                    weight: gras ? FontWeight.w700 : FontWeight.w400,
                    color: encre,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le bouton doré du site (goldBtn) : fauve, texte nuit, 14,5 px gras,
/// padding 11 x 22. Comme la classe « gold » du site, il se tasse
/// légèrement sous le doigt (scale 0,98 en 0,12 s), seulement s'il est actif.
class BoutonDore extends StatefulWidget {
  final String texte;
  final VoidCallback? onTap;
  final Widget? icone;
  final double ecart;
  final bool actif;
  final double opaciteInactive;

  const BoutonDore({
    super.key,
    required this.texte,
    required this.onTap,
    this.icone,
    this.ecart = 7,
    this.actif = true,
    this.opaciteInactive = 0.5,
  });

  @override
  State<BoutonDore> createState() => _BoutonDoreState();
}

class _BoutonDoreState extends State<BoutonDore> {
  bool _appuye = false;

  void _presse(bool valeur) {
    if (_appuye != valeur) setState(() => _appuye = valeur);
  }

  @override
  Widget build(BuildContext context) {
    final actif = widget.actif && widget.onTap != null;
    return Listener(
      onPointerDown: actif ? (_) => _presse(true) : null,
      onPointerUp: (_) => _presse(false),
      onPointerCancel: (_) => _presse(false),
      child: AnimatedScale(
        scale: _appuye ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.ease,
        child: BoutonPilule(
          texte: widget.texte,
          onTap: widget.onTap,
          fond: TytoColors.fauve,
          encre: TytoColors.nuit,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          taille: 14.5,
          icone: widget.icone,
          ecart: widget.ecart,
          actif: widget.actif,
          opaciteInactive: widget.opaciteInactive,
        ),
      ),
    );
  }
}

/// Le petit lien souligné des fenêtres (« Plus tard », « Reprendre une
/// autre photo »…) : 12,5 px, encre à 53 %.
class LienDiscret extends StatelessWidget {
  final String texte;
  final VoidCallback onTap;
  final bool centre;

  const LienDiscret({super.key, required this.texte, required this.onTap, this.centre = false});

  @override
  Widget build(BuildContext context) {
    final lien = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        texte,
        style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: encreA(0x88)).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: encreA(0x88),
        ),
      ),
    );
    return centre ? Center(child: lien) : Align(alignment: Alignment.centerLeft, child: lien);
  }
}

/// Le bouton « × » qui ferme les fenêtres du site (20 px, encre à 53 %).
class BoutonFermerCroix extends StatelessWidget {
  final VoidCallback onTap;
  const BoutonFermerCroix({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // Police système, comme le bouton du site (pas Newsreader hérité du thème).
        child: Text(
          '×',
          style: TextStyle(
            fontFamily: Theme.of(context).typography.black.bodyMedium?.fontFamily ?? 'Roboto',
            fontFamilyFallback: Theme.of(context).typography.black.bodyMedium?.fontFamilyFallback,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.15,
            leadingDistribution: TextLeadingDistribution.even,
            color: encreA(0x88),
          ),
        ),
      ),
    );
  }
}

/// L'habillage des champs blancs du site : bord 1 px, rayon, padding CSS
/// (+1 px pour le bord, compté à part en CSS), contour doré de 2 px au
/// focus comme le :focus-visible du site.
InputDecoration decorationChampPapier({
  required String indication,
  required double taille,
  required EdgeInsets padding,
  double rayon = 10,
  Color bord = const Color(0x332A2118),
  double? hauteurLigne,
}) {
  OutlineInputBorder cadre(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayon),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: indication,
    hintStyle: TytoText.ui(size: taille, weight: FontWeight.w400, color: couleurIndication)
        .copyWith(height: hauteurLigne),
    hintMaxLines: 6,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.fromLTRB(
      padding.left + 1,
      padding.top + 1,
      padding.right + 1,
      padding.bottom + 1,
    ),
    border: cadre(bord, 1),
    enabledBorder: cadre(bord, 1),
    disabledBorder: cadre(bord, 1),
    focusedBorder: cadre(TytoColors.fauve, 2),
  );
}

/// Le contenu d'une fenêtre ouverte avec showDialog : marge du voile du
/// site, largeur maximale, remontée au-dessus du clavier, défilement si
/// la fenêtre dépasse l'écran.
class CadreDialogue extends StatelessWidget {
  final double marge;
  final double largeurMax;
  final Widget child;

  const CadreDialogue({super.key, required this.marge, required this.largeurMax, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.decelerate,
      padding: MediaQuery.viewInsetsOf(context),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(marge),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: largeurMax),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
