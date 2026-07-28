import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Le ciel du tiroir. Chaque étoile s'allume doucement, scintille un
/// moment, s'éteint — puis renaît à un autre endroit. Le rythme reste
/// lent et discret, dans l'esprit des animations du site.
class StarField extends StatefulWidget {
  final int nombre;
  const StarField({super.key, this.nombre = 18});

  @override
  State<StarField> createState() => _StarFieldState();
}

class _Etoile {
  double x, y, taille;
  int naissanceMs, dureeMs;
  double phase; // décale le scintillement pour qu'elles ne pulsent pas ensemble
  _Etoile({
    required this.x,
    required this.y,
    required this.taille,
    required this.naissanceMs,
    required this.dureeMs,
    required this.phase,
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
      // On étale les naissances dans le temps : au démarrage, le ciel se
      // remplit progressivement au lieu que tout apparaisse d'un coup.
      for (var i = 0; i < widget.nombre; i++) {
        _etoiles.add(_naitre(decalageMs: -_rnd.nextInt(6000)));
      }
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() {
          final t = _horloge.elapsedMilliseconds;
          for (var i = 0; i < _etoiles.length; i++) {
            final e = _etoiles[i];
            if (t - e.naissanceMs > e.dureeMs) {
              // Son temps est fini : elle renaît ailleurs.
              _etoiles[i] = _naitre();
            }
          }
        });
      });
    });
  }

  _Etoile _naitre({int decalageMs = 0}) {
    return _Etoile(
      x: 0.04 + _rnd.nextDouble() * 0.92,
      y: 0.04 + _rnd.nextDouble() * 0.92,
      taille: 1.0 + _rnd.nextDouble() * 0.9,
      naissanceMs: _horloge.elapsedMilliseconds + decalageMs,
      dureeMs: 7000 + _rnd.nextInt(6000), // entre 7 et 13 secondes de vie
      phase: _rnd.nextDouble(),
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
      // Animations réduites : un ciel fixe et discret.
      return CustomPaint(painter: _CielPainter(_etoilesFixes(), 0));
    }
    return CustomPaint(
      painter: _CielPainter(_etoiles, _horloge.elapsedMilliseconds),
    );
  }

  List<_Etoile> _etoilesFixes() {
    if (_etoiles.isNotEmpty) return _etoiles;
    for (var i = 0; i < widget.nombre; i++) {
      _etoiles.add(_naitre());
    }
    return _etoiles;
  }
}

class _CielPainter extends CustomPainter {
  final List<_Etoile> etoiles;
  final int maintenantMs;
  _CielPainter(this.etoiles, this.maintenantMs);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final e in etoiles) {
      final age = maintenantMs - e.naissanceMs;
      if (age < 0) continue; // pas encore née

      final t = age / e.dureeMs;
      if (t > 1) continue;

      // Apparition douce sur les 15 premiers %, disparition sur les 25 derniers.
      double enveloppe;
      if (t < 0.15) {
        enveloppe = t / 0.15;
      } else if (t > 0.75) {
        enveloppe = (1 - t) / 0.25;
      } else {
        enveloppe = 1;
      }

      // Le scintillement exact du site (animation "starTwinkle") :
      // cycle de 3,6 s, opacité qui va de 0,2 à 0,75 et revient,
      // chaque étoile décalée par rapport aux autres.
      final cycle = ((maintenantMs / 3600.0) + e.phase) % 1.0;
      // 0 % et 100 % -> 0,2   |   50 % -> 0,75
      final scintille = cycle < 0.5
          ? 0.2 + 0.55 * (cycle / 0.5)
          : 0.75 - 0.55 * ((cycle - 0.5) / 0.5);

      final opacite = (scintille * enveloppe).clamp(0.0, 1.0);
      if (opacite <= 0.01) continue;

      paint.color = TytoColors.lune.withOpacity(opacite);
      canvas.drawCircle(
        Offset(e.x * size.width, e.y * size.height),
        e.taille,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CielPainter old) => true;
}
