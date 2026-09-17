import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Le ciel du tiroir — deuxième version, pensée pour se sentir dessinée
/// plutôt que générée : quelques étoiles bien plus lumineuses que les
/// autres (des "repères"), reliées par de très fines lignes de
/// constellation, comme sur une carte céleste ancienne. Le reste scintille
/// discrètement en fond, à son propre rythme, et renaît ailleurs.
class StarField extends StatefulWidget {
  final int nombre;
  const StarField({super.key, this.nombre = 22});

  @override
  State<StarField> createState() => _StarFieldState();
}

class _Etoile {
  double x, y, taille;
  int naissanceMs, dureeMs;
  double phase;
  bool repere; // une étoile "repère" : plus grande, plus lumineuse
  _Etoile({
    required this.x,
    required this.y,
    required this.taille,
    required this.naissanceMs,
    required this.dureeMs,
    required this.phase,
    required this.repere,
  });
}

class _StarFieldState extends State<StarField> {
  final _rnd = Random();
  final _horloge = Stopwatch()..start();
  final List<_Etoile> _etoiles = [];
  Timer? _timer;
  bool _actif = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        setState(() => _actif = false);
        return;
      }
      for (var i = 0; i < widget.nombre; i++) {
        _etoiles.add(_naitre(decalageMs: -_rnd.nextInt(6000), repere: i < 4));
      }
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (!mounted) return;
        setState(() {
          final t = _horloge.elapsedMilliseconds;
          for (var i = 0; i < _etoiles.length; i++) {
            final e = _etoiles[i];
            if (t - e.naissanceMs > e.dureeMs) {
              _etoiles[i] = _naitre(repere: e.repere);
            }
          }
        });
      });
    });
  }

  _Etoile _naitre({int decalageMs = 0, bool repere = false}) {
    return _Etoile(
      x: 0.05 + _rnd.nextDouble() * 0.9,
      y: 0.05 + _rnd.nextDouble() * 0.9,
      // Les repères sont nettement plus grands : 2 à 3 échelles bien
      // distinctes, plutôt que des points tous à peu près pareils.
      taille: repere ? 2.2 + _rnd.nextDouble() * 0.8 : 0.7 + _rnd.nextDouble() * 0.7,
      naissanceMs: _horloge.elapsedMilliseconds + decalageMs,
      dureeMs: repere ? 16000 + _rnd.nextInt(8000) : 7000 + _rnd.nextInt(6000),
      phase: _rnd.nextDouble(),
      repere: repere,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_actif) {
      return CustomPaint(painter: _CielPainter(_etoilesFixes(), 0));
    }
    return CustomPaint(painter: _CielPainter(_etoiles, _horloge.elapsedMilliseconds));
  }

  List<_Etoile> _etoilesFixes() {
    if (_etoiles.isNotEmpty) return _etoiles;
    for (var i = 0; i < widget.nombre; i++) {
      _etoiles.add(_naitre(repere: i < 4));
    }
    return _etoiles;
  }
}

class _CielPainter extends CustomPainter {
  final List<_Etoile> etoiles;
  final int maintenantMs;
  _CielPainter(this.etoiles, this.maintenantMs);

  double _opacite(_Etoile e, int age) {
    if (age < 0 || age > e.dureeMs) return 0;
    final t = age / e.dureeMs;
    double enveloppe;
    if (t < 0.15) {
      enveloppe = t / 0.15;
    } else if (t > 0.75) {
      enveloppe = (1 - t) / 0.25;
    } else {
      enveloppe = 1;
    }
    final cycle = ((maintenantMs / 3600.0) + e.phase) % 1.0;
    final scintille = cycle < 0.5 ? 0.2 + 0.55 * (cycle / 0.5) : 0.75 - 0.55 * ((cycle - 0.5) / 0.5);
    final base = e.repere ? scintille * 1.15 : scintille;
    return (base * enveloppe).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Les repères visibles maintenant, pour tracer les constellations.
    final visibles = <_Etoile>[];
    final opacites = <double>[];
    for (final e in etoiles) {
      final age = maintenantMs - e.naissanceMs;
      final o = _opacite(e, age);
      if (o > 0.01) {
        visibles.add(e);
        opacites.add(o);
      }
    }

    // De fines lignes reliant les repères proches, comme une carte du
    // ciel — le détail qui donne l'impression d'un vrai tracé, pas
    // d'un simple dégradé avec des points dessus.
    final reperes = <int>[];
    for (var i = 0; i < visibles.length; i++) {
      if (visibles[i].repere) reperes.add(i);
    }
    final ligne = Paint()
      ..color = TytoColors.fauve.withOpacity(0.14)
      ..strokeWidth = 0.6;
    for (var a = 0; a < reperes.length; a++) {
      for (var b = a + 1; b < reperes.length; b++) {
        final e1 = visibles[reperes[a]];
        final e2 = visibles[reperes[b]];
        final p1 = Offset(e1.x * size.width, e1.y * size.height);
        final p2 = Offset(e2.x * size.width, e2.y * size.height);
        final d = (p1 - p2).distance;
        if (d < size.width * 0.42) {
          final intensite = min(opacites[reperes[a]], opacites[reperes[b]]) * 0.5;
          canvas.drawLine(p1, p2, ligne..color = TytoColors.fauve.withOpacity(intensite * 0.28));
        }
      }
    }

    final point = Paint();
    for (var i = 0; i < visibles.length; i++) {
      final e = visibles[i];
      final o = opacites[i];
      final centre = Offset(e.x * size.width, e.y * size.height);
      if (e.repere) {
        // Un halo doux autour des repères — elles brillent, ne clignotent
        // pas juste sur place.
        point
          ..color = TytoColors.fauve.withOpacity(o * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
        canvas.drawCircle(centre, e.taille * 2.4, point);
        point.maskFilter = null;
        point.color = TytoColors.lune.withOpacity(o);
        canvas.drawCircle(centre, e.taille, point);
      } else {
        point.color = TytoColors.lune.withOpacity(o * 0.8);
        canvas.drawCircle(centre, e.taille, point);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CielPainter old) => true;
}
