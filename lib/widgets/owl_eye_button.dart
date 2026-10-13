import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// L'œil de Tyto — le bouton pour joindre une photo dans le chat : un rond
/// de 38 px au fin liseré, avec l'œil doré de la chouette qui cligne,
/// exactement comme sur le site (ellipse rx 8 / ry 9,5 sur une grille de
/// 24, dans un carré de 19 px, animation "blink", ici toutes les 4 s au lieu de 6,5 s : comme la chouette,
/// il cligne un peu plus souvent que sur le site).
class OwlEyeButton extends StatefulWidget {
  /// null : bouton désactivé (quota épuisé), comme le bouton « disabled »
  /// du site — il ne réagit plus au toucher.
  final VoidCallback? onTap;

  /// Le côté du dessin de l'œil : 22 px (19 px sur le site), un peu plus grand
  /// pour qu'il se voie mieux dans le rond de 38 px.
  final double size;

  /// La fonction est-elle accessible (Premium) ? Sur le site, l'œil reste
  /// doré dans tous les cas : seul le message d'aide change.
  final bool actif;

  const OwlEyeButton({
    super.key,
    required this.onTap,
    this.size = 22,
    this.actif = true,
  });

  @override
  State<OwlEyeButton> createState() => _OwlEyeButtonState();
}

class _OwlEyeButtonState extends State<OwlEyeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _cycleMs = 4000;

  @override
  void initState() {
    super.initState();
    // Le même cycle de 4 s que le clignement de la chouette du logo.
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: _cycleMs))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Les étapes exactes de "blink" : l'œil reste ouvert presque tout le
  /// temps, puis s'écrase brièvement (0 % → 93 % ouvert, 95,5 % à 8 %),
  /// avec la courbe « ease » que le navigateur applique entre deux étapes.
  double _ouverture(double t) {
    // Le clignement dure 0,455 s, comme sur le site, quelle que soit la longueur du cycle.
    const debut = 1 - 455 / _cycleMs;
    const creux = debut + 455 * (25 / 70) / _cycleMs;
    const fin = 1.0;
    const ferme = 0.08;
    if (t < debut) return 1;
    if (t < creux) return 1 - (1 - ferme) * Curves.ease.transform((t - debut) / (creux - debut));
    final double p = ((t - creux) / (fin - creux)).clamp(0.0, 1.0).toDouble();
    return ferme + (1 - ferme) * Curves.ease.transform(p);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "L'œil de Tyto : analyser une photo",
      child: Semantics(
        button: true,
        label: 'Envoyer une photo',
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Le même fin liseré que le bouton du site (LUNE + "30").
              border: Border.all(color: TytoColors.lune.withOpacity(0.19)),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
                  return _oeil(1);
                }
                return _oeil(_ouverture(_c.value));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _oeil(double ouverture) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _OeilPainter(ouverture: ouverture, couleur: TytoColors.fauve),
      ),
    );
  }
}

/// L'ellipse pleine du site, aplatie verticalement autour de son centre
/// pendant le clignement (transform: scaleY).
class _OeilPainter extends CustomPainter {
  final double ouverture;
  final Color couleur;
  _OeilPainter({required this.ouverture, required this.couleur});

  @override
  void paint(Canvas canvas, Size size) {
    final echelle = size.width / 24;
    final centre = Offset(size.width / 2, size.height / 2);
    final peinture = Paint()
      ..color = couleur
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: 16 * echelle, height: 19 * echelle * ouverture),
      peinture,
    );
  }

  @override
  bool shouldRepaint(covariant _OeilPainter old) =>
      old.ouverture != ouverture || old.couleur != couleur;
}
