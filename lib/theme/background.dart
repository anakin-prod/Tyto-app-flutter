import 'package:flutter/material.dart';
import 'colors.dart';

/// Le fond de l'application, strictement celui du site :
///   radial-gradient(1100px 560px at 72% -12%, NUIT2 0%, NUIT 58%)
/// C'est une grande ellipse (1100 x 560 px) centrée à 72 % de la largeur et
/// 12 % au-dessus du haut de l'écran : la lueur s'étale sur toute la
/// largeur, puis se fond vers le bleu nuit.
///
/// (Un dégradé circulaire Flutter ne peut pas faire cette ellipse : il
/// laissait le côté gauche trop sombre. On la dessine donc à la main.)
class TytoBackground extends StatelessWidget {
  final Widget child;
  const TytoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _FondPainter(),
      child: child,
    );
  }
}

class _FondPainter extends CustomPainter {
  const _FondPainter();

  static const double _rx = 1100;
  static const double _ry = 560;

  @override
  void paint(Canvas canvas, Size size) {
    final ecran = Offset.zero & size;
    canvas.drawRect(ecran, Paint()..color = TytoColors.nuit);

    final centre = Offset(size.width * 0.72, size.height * -0.12);
    final etirement = _rx / _ry;

    canvas.save();
    canvas.clipRect(ecran);
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(etirement, 1.0);

    final cercle = Rect.fromCircle(center: Offset.zero, radius: _ry);
    final pinceau = Paint()
      ..shader = const RadialGradient(
        radius: 0.5, // la moitié du carré englobant = le rayon de 560
        colors: [TytoColors.nuit2, TytoColors.nuit],
        stops: [0.0, 0.58],
      ).createShader(cercle);

    // Le rectangle à peindre, exprimé dans l'espace étiré.
    canvas.drawRect(
      Rect.fromLTRB(
        -centre.dx / etirement,
        -centre.dy,
        (size.width - centre.dx) / etirement,
        size.height - centre.dy,
      ),
      pinceau,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FondPainter ancien) => false;
}
