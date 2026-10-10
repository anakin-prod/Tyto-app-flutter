import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/site_icons.dart';

// ============================================================
// Petites briques communes au tableau des rappels, à la veille,
// à l'équipe et à la fenêtre d'urgence, reprises au pixel du site.
// ============================================================

/// Une interligne CSS (line-height) : l'espace en plus se répartit à
/// parts égales au-dessus et au-dessous du texte, comme dans un navigateur.
TextStyle interligne(TextStyle s, double h) =>
    s.copyWith(height: h, leadingDistribution: TextLeadingDistribution.even);

/// La police « système » que le navigateur donne aux boutons du site
/// quand aucune police n'est précisée (« Retirer », « Copier », « × »…) :
/// Roboto sur Android, San Francisco sur iPhone.
TextStyle styleSysteme(
  BuildContext context, {
  required double size,
  FontWeight weight = FontWeight.w400,
  required Color color,
}) {
  final base = Theme.of(context).typography.black.bodyMedium;
  return TextStyle(
    fontFamily: base?.fontFamily ?? 'Roboto',
    fontFamilyFallback: base?.fontFamilyFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

/// Nombre de jours entre aujourd'hui et la date (négatif = passé),
/// comme daysUntil() du site.
int joursAvant(DateTime date) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(date.year, date.month, date.day);
  return (b.difference(a).inHours / 24).round();
}

/// JJ/MM/AAAA, comme frDate() du site.
String dateFr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Un bouton en pilule du site, mesuré sur le vrai rendu du navigateur.
///
/// [padding] est le padding CSS (le bord d'1 px éventuel s'ajoute tout
/// seul, comme en CSS). Quand le libellé du site est une ligne
/// « inline-flex » qui commence par une icône, le navigateur laisse
/// quelques pixels vides sous la ligne : [hauteurContenu] est alors la
/// hauteur mesurée de la zone de contenu, et [hauteurLigne] celle de la
/// ligne, posée en haut de cette zone. [hauteur] impose la hauteur totale
/// (bouton étiré par son voisin), le libellé restant centré.
class TableauBouton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? fond;
  final Color? bord;
  final EdgeInsets padding;
  final double? hauteurContenu;
  final double? hauteurLigne;
  final double? hauteur;
  final double opacite;

  /// Échelle sous le doigt : 0,98 pour les boutons dorés (.gold:active),
  /// 1 pour les autres (aucun effet).
  final double echellePresse;
  final bool pleineLargeur;

  const TableauBouton({
    super.key,
    required this.child,
    required this.onTap,
    required this.padding,
    this.fond,
    this.bord,
    this.hauteurContenu,
    this.hauteurLigne,
    this.hauteur,
    this.opacite = 1,
    this.echellePresse = 1,
    this.pleineLargeur = false,
  });

  @override
  State<TableauBouton> createState() => _TableauBoutonState();
}

class _TableauBoutonState extends State<TableauBouton> {
  bool _enfonce = false;

  void _poser(bool v) {
    if (widget.echellePresse == 1 || widget.onTap == null || _enfonce == v) return;
    setState(() => _enfonce = v);
  }

  @override
  Widget build(BuildContext context) {
    final double? facteur = widget.pleineLargeur ? null : 1.0;
    Widget contenu = Center(widthFactor: facteur, heightFactor: 1.0, child: widget.child);
    final ligne = widget.hauteurLigne;
    if (ligne != null) {
      contenu = SizedBox(height: ligne, child: Center(widthFactor: facteur, child: widget.child));
    }
    final zone = widget.hauteurContenu;
    if (zone != null) {
      contenu = SizedBox(
        height: zone,
        child: Align(alignment: Alignment.topCenter, widthFactor: facteur, child: contenu),
      );
    }
    final bord = widget.bord;
    Widget corps = Container(
      height: widget.hauteur,
      padding: widget.padding,
      alignment: widget.hauteur != null ? Alignment.center : null,
      decoration: BoxDecoration(
        color: widget.fond,
        borderRadius: BorderRadius.circular(999),
        border: bord == null ? null : Border.all(color: bord),
      ),
      child: contenu,
    );
    if (widget.pleineLargeur) corps = SizedBox(width: double.infinity, child: corps);
    return Opacity(
      opacity: widget.opacite,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _poser(true),
        onTapUp: (_) => _poser(false),
        onTapCancel: () => _poser(false),
        child: AnimatedScale(
          scale: _enfonce ? widget.echellePresse : 1.0,
          duration: const Duration(milliseconds: 120),
          child: corps,
        ),
      ),
    );
  }
}

/// Le libellé d'un bouton du site : icône facultative, écart, texte Karla.
Widget libelleBouton({
  Widget? icone,
  double ecart = 7,
  required String texte,
  required double taille,
  required Color couleur,
  FontWeight graisse = FontWeight.w700,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icone != null) ...[icone, SizedBox(width: ecart)],
      Flexible(
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: TytoText.ui(size: taille, weight: graisse, color: couleur),
        ),
      ),
    ],
  );
}

/// Le bouton doré « Fait » des rappels (coche 12 px, 12 px gras).
class BoutonFait extends StatelessWidget {
  final VoidCallback onTap;
  const BoutonFait({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TableauBouton(
      onTap: onTap,
      fond: TytoColors.fauve,
      echellePresse: 0.98,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      child: libelleBouton(
        icone: const SiteIcon('IconCheck', size: 12, color: TytoColors.nuit),
        ecart: 4,
        texte: 'Fait',
        taille: 12,
        couleur: TytoColors.nuit,
      ),
    );
  }
}
