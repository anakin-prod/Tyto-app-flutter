import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

/// Les empreintes qui traversent le fond, reprises de components/PawTrails.js.
///
/// Une seule horloge pilote toute la scène et calcule l'opacité de chaque
/// empreinte à partir de son âge. Chaque empreinte n'a donc pas d'animation
/// propre : impossible qu'elles se désynchronisent ou se coupent entre elles.

const double _opacite = 0.4;
const double _taille = 30;
const int _dureeMs = 5000; // temps qu'une empreinte reste visible
const int _intervalleMs = 4000; // temps entre deux nouvelles pistes
const int _vieMs = _dureeMs + 4000; // au bout de quoi la piste est retirée
const double _ecartMini = 26; // distance minimale entre deux pistes actives

const _patteChat = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#EDE7D6">
  <ellipse cx="12" cy="16.5" rx="5.6" ry="4.6" />
  <ellipse cx="5.8" cy="9.4" rx="2.1" ry="2.7" transform="rotate(-18 5.8 9.4)" />
  <ellipse cx="10" cy="6.6" rx="2.1" ry="2.8" transform="rotate(-6 10 6.6)" />
  <ellipse cx="14.4" cy="6.8" rx="2.1" ry="2.8" transform="rotate(7 14.4 6.8)" />
  <ellipse cx="18.4" cy="9.8" rx="2.1" ry="2.7" transform="rotate(19 18.4 9.8)" />
</svg>''';

const _patteChien = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#EDE7D6">
  <path d="M12 11.4c3.5 0 6.6 2.6 6.6 5.3 0 2.2-2 3.3-4 3.3-1 0-1.8-.3-2.6-.3s-1.6.3-2.6.3c-2 0-4-1.1-4-3.3 0-2.7 3.1-5.3 6.6-5.3z" />
  <ellipse cx="4.6" cy="8.6" rx="2.3" ry="3" transform="rotate(-22 4.6 8.6)" />
  <ellipse cx="9.4" cy="5.2" rx="2.3" ry="3.1" transform="rotate(-8 9.4 5.2)" />
  <ellipse cx="14.6" cy="5.2" rx="2.3" ry="3.1" transform="rotate(8 14.6 5.2)" />
  <ellipse cx="19.4" cy="8.6" rx="2.3" ry="3" transform="rotate(22 19.4 8.6)" />
</svg>''';

const _patteOiseau = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#EDE7D6" stroke-width="1.9" stroke-linecap="round">
  <path d="M12 17 L12 5" />
  <path d="M12 13.5 L4.6 5.8" />
  <path d="M12 13.5 L19.4 5.8" />
  <path d="M12 17 L12 20.6" />
</svg>''';

const _patteCheval = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#EDE7D6" stroke-width="3.1" stroke-linecap="round">
  <path d="M6.4 17.5 A6.6 7.2 0 1 1 17.6 17.5" />
</svg>''';

const _patteLapin = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#EDE7D6">
  <ellipse cx="12" cy="15" rx="3.4" ry="7" />
  <ellipse cx="8.2" cy="6.4" rx="1.7" ry="2.3" transform="rotate(-14 8.2 6.4)" />
  <ellipse cx="12" cy="5.2" rx="1.7" ry="2.4" />
  <ellipse cx="15.8" cy="6.4" rx="1.7" ry="2.3" transform="rotate(14 15.8 6.4)" />
</svg>''';

const _especes = [_patteChat, _patteChien, _patteOiseau, _patteCheval, _patteLapin];

class _Piste {
  final int naissanceMs;
  final int especeIdx;
  final double x0, y0, angle, ecart, lateral;
  final int n;
  _Piste({
    required this.naissanceMs,
    required this.especeIdx,
    required this.x0,
    required this.y0,
    required this.angle,
    required this.n,
    required this.ecart,
    required this.lateral,
  });
}

class PawTrails extends StatefulWidget {
  const PawTrails({super.key});

  @override
  State<PawTrails> createState() => _PawTrailsState();
}

class _PawTrailsState extends State<PawTrails> {
  final List<_Piste> _pistes = [];
  final _rnd = Random();
  final _horloge = Stopwatch()..start();
  Timer? _rafraichir;
  Timer? _naissance;
  bool _actif = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // On respecte le réglage système « réduire les animations ».
      if (MediaQuery.of(context).disableAnimations) {
        setState(() => _actif = false);
        return;
      }
      _ajouterPiste();
      // Une seule horloge redessine la scène ; l'opacité de chaque
      // empreinte se déduit de son âge, rien n'est animé séparément.
      _rafraichir = Timer.periodic(const Duration(milliseconds: 60), (_) {
        if (!mounted) return;
        setState(() {
          _pistes.removeWhere((p) => _horloge.elapsedMilliseconds - p.naissanceMs > _vieMs);
        });
      });
      _naissance = Timer.periodic(const Duration(milliseconds: _intervalleMs), (_) {
        if (mounted) _ajouterPiste();
      });
    });
  }

  @override
  void dispose() {
    _rafraichir?.cancel();
    _naissance?.cancel();
    super.dispose();
  }

  _Piste _tirerPiste() {
    // Direction libre : les pistes ne filent pas toutes dans le même sens.
    final angle = _rnd.nextDouble() * 360;
    final n = 4 + _rnd.nextInt(3);
    final ecart = 4.5 + _rnd.nextDouble() * 3;
    // Départ calculé pour que la piste entière reste à l'écran.
    final rad = angle * pi / 180;
    final porteeX = cos(rad) * ecart * (n - 1);
    final porteeY = sin(rad) * ecart * (n - 1);
    final minX = max(2.0, 2 - porteeX);
    final maxX = min(92.0, 92 - porteeX);
    final minY = max(2.0, 2 - porteeY);
    final maxY = min(88.0, 88 - porteeY);
    return _Piste(
      naissanceMs: _horloge.elapsedMilliseconds,
      especeIdx: _rnd.nextInt(_especes.length),
      x0: minX + _rnd.nextDouble() * max(0.0, maxX - minX),
      y0: minY + _rnd.nextDouble() * max(0.0, maxY - minY),
      angle: angle,
      n: n,
      ecart: ecart,
      lateral: 1.6 + _rnd.nextDouble() * 1.2,
    );
  }

  void _ajouterPiste() {
    // On essaie plusieurs emplacements et on garde le plus éloigné des
    // pistes déjà en cours, pour éviter qu'elles se chevauchent.
    _Piste? choisie;
    double meilleureDistance = -1;
    for (var essai = 0; essai < 10; essai++) {
      final candidate = _tirerPiste();
      double distance = double.infinity;
      for (final a in _pistes) {
        final d = sqrt(pow(candidate.x0 - a.x0, 2) + pow(candidate.y0 - a.y0, 2));
        if (d < distance) distance = d;
      }
      if (distance > meilleureDistance) {
        meilleureDistance = distance;
        choisie = candidate;
      }
      if (distance >= _ecartMini) break;
    }
    if (choisie == null || !mounted) return;
    setState(() => _pistes.add(choisie!));
  }

  /// Les étapes de l'animation « pasEmpreinte » du site :
  /// 0 % invisible → 18 % visible → 62 % visible → 100 % invisible.
  double _opaciteA(int ageMs) {
    if (ageMs < 0 || ageMs > _dureeMs) return 0;
    final t = ageMs / _dureeMs;
    if (t < 0.18) return _opacite * (t / 0.18);
    if (t < 0.62) return _opacite;
    return _opacite * (1 - (t - 0.62) / 0.38);
  }

  @override
  Widget build(BuildContext context) {
    if (!_actif) return const SizedBox.shrink();
    final maintenant = _horloge.elapsedMilliseconds;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final empreintes = <Widget>[];

          for (final p in _pistes) {
            final rad = p.angle * pi / 180;
            final dx = cos(rad), dy = sin(rad);
            final px = -dy, py = dx;
            // Les empreintes d'une même piste se posent l'une après l'autre,
            // mais restent visibles ensemble : c'est ce qui dessine la trace.
            final decalage = _dureeMs / (p.n * 1.7);

            for (var i = 0; i < p.n; i++) {
              final age = maintenant - p.naissanceMs - (i * decalage).round();
              final o = _opaciteA(age);
              if (o <= 0) continue; // rien à dessiner pour celle-ci

              final cote = i % 2 == 0 ? 1 : -1;
              final left = (p.x0 + dx * p.ecart * i + px * p.lateral * cote) / 100 * w;
              final top = (p.y0 + dy * p.ecart * i + py * p.lateral * cote) / 100 * h;

              empreintes.add(Positioned(
                left: left,
                top: top,
                child: Opacity(
                  opacity: o,
                  child: Transform.rotate(
                    angle: (p.angle + 90 + cote * 7) * pi / 180,
                    child: SvgPicture.string(
                      _especes[p.especeIdx],
                      width: _taille,
                      height: _taille,
                      colorFilter: const ColorFilter.mode(TytoColors.lune, BlendMode.srcIn),
                    ),
                  ),
                ),
              ));
            }
          }

          return Stack(children: empreintes);
        },
      ),
    );
  }
}
