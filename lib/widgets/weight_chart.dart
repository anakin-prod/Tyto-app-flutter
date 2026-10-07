import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Une pesée : une date et un poids en kilos.
class PointPoids {
  final DateTime date;
  final double kg;
  const PointPoids(this.date, this.kg);
}

/// La courbe de poids du carnet — la même que sur le site (mêmes marges,
/// mêmes graduations, même dégradé), pour que les deux se ressemblent.
/// Elle n'apparaît qu'à partir de deux pesées.
class WeightChart extends StatelessWidget {
  /// Triés par date croissante.
  final List<PointPoids> points;
  const WeightChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    final diff = points.last.kg - points.first.kg;
    final couleurDiff = diff > 0
        ? const Color(0xFF8A5A2E)
        : diff < 0
            ? const Color(0xFF2E6A55)
            : const Color(0xFF888888);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: TytoColors.papier,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
        boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Courbe de poids', style: TytoText.display(size: 15, color: TytoColors.encre)),
                Text(
                  '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
                  style: TytoText.ui(size: 12, weight: FontWeight.w700, color: couleurDiff),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Le dessin est calculé dans un repère de 320 x 150, comme sur le
          // site, puis mis à l'échelle : le rapport est conservé.
          AspectRatio(
            aspectRatio: 320 / 150,
            child: CustomPaint(painter: _PoidsPainter(points)),
          ),
        ],
      ),
    );
  }
}

class _PoidsPainter extends CustomPainter {
  final List<PointPoids> points;
  _PoidsPainter(this.points);

  static const double _w = 320, _h = 150, _padL = 34, _padB = 22, _padT = 12, _padR = 10;
  static const _or = Color(0xFFC99A55);

  String _jourMois(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  void _texte(Canvas canvas, String t, Offset position, {required bool alignerADroite, bool centrerVertical = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(fontSize: 9, color: TytoColors.encre.withOpacity(0.6)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = alignerADroite ? position.dx - tp.width : position.dx;
    final y = centrerVertical ? position.dy - tp.height / 2 : position.dy - tp.height;
    tp.paint(canvas, Offset(x, y));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);

    final xs = points.map((p) => p.date.millisecondsSinceEpoch.toDouble()).toList();
    final ys = points.map((p) => p.kg).toList();
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    // Un poids qui ne bouge pas : on ouvre l'échelle pour avoir une ligne
    // plate au milieu plutôt qu'une division par zéro.
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final ecartY = maxY - minY;
    minY = math.max(0.0, minY - ecartY * 0.15);
    maxY = maxY + ecartY * 0.15;

    final largeurX = (maxX - minX) == 0 ? 1.0 : (maxX - minX);
    final hauteurY = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    double px(double t) => _padL + ((t - minX) / largeurX) * (_w - _padL - _padR);
    double py(double v) => _padT + (1 - (v - minY) / hauteurY) * (_h - _padT - _padB);

    // Trois lignes de repère avec leur valeur
    final grille = Paint()
      ..color = TytoColors.encre.withOpacity(0.10)
      ..strokeWidth = 1;
    for (final v in [minY, (minY + maxY) / 2, maxY]) {
      canvas.drawLine(Offset(_padL, py(v)), Offset(_w - _padR, py(v)), grille);
      _texte(canvas, v.toStringAsFixed(1), Offset(_padL - 5, py(v)), alignerADroite: true, centrerVertical: true);
    }

    // La courbe, puis la zone dégradée en dessous
    final courbe = Path()..moveTo(px(xs[0]), py(ys[0]));
    for (var i = 1; i < points.length; i++) {
      courbe.lineTo(px(xs[i]), py(ys[i]));
    }
    final zone = Path.from(courbe)
      ..lineTo(px(maxX), _h - _padB)
      ..lineTo(px(minX), _h - _padB)
      ..close();
    canvas.drawPath(
      zone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_or.withOpacity(0.35), _or.withOpacity(0.02)],
        ).createShader(const Rect.fromLTWH(0, 0, _w, _h)),
    );
    canvas.drawPath(
      courbe,
      Paint()
        ..color = _or
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Un point par pesée
    for (var i = 0; i < points.length; i++) {
      final centre = Offset(px(xs[i]), py(ys[i]));
      canvas.drawCircle(centre, 3, Paint()..color = _or);
      canvas.drawCircle(
        centre,
        3,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Première et dernière date, sous la courbe
    _texte(canvas, _jourMois(points.first.date), Offset(px(minX), _h - 4), alignerADroite: false);
    _texte(canvas, _jourMois(points.last.date), Offset(px(maxX), _h - 4), alignerADroite: true);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PoidsPainter ancien) => ancien.points != points;
}
