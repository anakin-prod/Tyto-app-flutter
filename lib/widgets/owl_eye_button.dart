import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// L'œil de Tyto — le bouton pour joindre une photo dans le chat, sous
/// la forme d'un œil de chouette doré qui cligne, plutôt qu'une icône
/// générique d'image. Le clignement suit exactement le même rythme que
/// la chouette du logo (cycle de 6,5 secondes, un clin d'œil bref).
class OwlEyeButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final bool actif; // grisé si la fonction n'est pas accessible (non Premium)

  const OwlEyeButton({
    super.key,
    required this.onTap,
    this.size = 26,
    this.actif = true,
  });

  @override
  State<OwlEyeButton> createState() => _OwlEyeButtonState();
}

class _OwlEyeButtonState extends State<OwlEyeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Le même cycle de 6,5 s que le clignement de la chouette du logo.
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Les étapes exactes de "blink", reprises de owl_sketch.dart : l'œil
  /// reste ouvert presque tout le temps, puis s'écrase brièvement.
  double _ouverture(double t) {
    const debut = 0.93, creux = 0.955, fin = 1.0;
    const ferme = 0.08;
    if (t < debut) return 1;
    if (t < creux) return 1 - (1 - ferme) * ((t - debut) / (creux - debut));
    return ferme + (1 - ferme) * ((t - creux) / (fin - creux));
  }

  @override
  Widget build(BuildContext context) {
    final couleur = widget.actif ? TytoColors.fauve : TytoColors.brume;
    return IconButton(
      onPressed: widget.onTap,
      tooltip: widget.actif ? "L'œil de Tyto — joindre une photo" : 'Joindre une photo (Premium)',
      icon: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return _oeil(1, couleur);
          }
          return _oeil(_ouverture(_c.value), couleur);
        },
      ),
    );
  }

  /// L'œil en amande, exactement la même forme que celui du logo — juste
  /// isolé, agrandi, et coloré comme les autres éléments dorés de l'app.
  Widget _oeil(double ouverture, Color couleur) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _OeilPainter(ouverture: ouverture, couleur: couleur),
      ),
    );
  }
}

class _OeilPainter extends CustomPainter {
  final double ouverture;
  final Color couleur;
  _OeilPainter({required this.ouverture, required this.couleur});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final rx = size.width * 0.42;
    final ry = size.height * 0.42 * ouverture;
    final peinture = Paint()..color = couleur;
    canvas.drawOval(Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2), peinture);

    // Un fin contour, comme le trait du logo, pour qu'il reste lisible
    // même presque fermé.
    final contour = Paint()
      ..color = couleur.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2), contour);
  }

  @override
  bool shouldRepaint(covariant _OeilPainter old) =>
      old.ouverture != ouverture || old.couleur != couleur;
}
