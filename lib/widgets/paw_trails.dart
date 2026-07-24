import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

/// Les empreintes qui traversent le fond, reprises de components/PawTrails.js.
/// Quelques traces apparaissent, se suivent, s'effacent, puis une autre piste
/// démarre ailleurs avec une autre espèce et une autre direction.
/// Purement décoratif : cette couche ne capte aucun clic.

const double _opacite = 0.4;
const double _taille = 30;
const int _dureeSec = 5; // temps qu'une empreinte reste visible
const int _intervalleSec = 4; // temps entre deux nouvelles pistes
const double _ecartMini = 26; // distance minimale entre deux pistes actives

// Les empreintes, une par espèce — mêmes tracés que sur le site.
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
  final int id;
  final int especeIdx;
  final double x0, y0, angle, ecart, lateral;
  final int n;
  _Piste({
    required this.id,
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
  int _cle = 0;
  bool _actif = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On respecte le réglage système « réduire les animations ».
      if (MediaQuery.of(context).disableAnimations) {
        setState(() => _actif = false);
        return;
      }
      _nouvellePiste();
      _boucle();
    });
  }

  void _boucle() {
    Future.delayed(const Duration(seconds: _intervalleSec), () {
      if (!mounted || !_actif) return;
      _nouvellePiste();
      _boucle();
    });
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
      id: _cle++,
      especeIdx: _rnd.nextInt(_especes.length),
      x0: minX + _rnd.nextDouble() * max(0.0, maxX - minX),
      y0: minY + _rnd.nextDouble() * max(0.0, maxY - minY),
      angle: angle,
      n: n,
      ecart: ecart,
      lateral: 1.6 + _rnd.nextDouble() * 1.2,
    );
  }

  void _nouvellePiste() {
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
    Future.delayed(const Duration(seconds: _dureeSec + 4), () {
      if (!mounted) return;
      setState(() => _pistes.removeWhere((q) => q.id == choisie!.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_actif) return const SizedBox.shrink();
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
            for (var i = 0; i < p.n; i++) {
              final cote = i % 2 == 0 ? 1 : -1;
              final left = (p.x0 + dx * p.ecart * i + px * p.lateral * cote) / 100 * w;
              final top = (p.y0 + dy * p.ecart * i + py * p.lateral * cote) / 100 * h;
              empreintes.add(Positioned(
                left: left,
                top: top,
                child: _Empreinte(
                  svg: _especes[p.especeIdx],
                  rotation: (p.angle + 90 + cote * 7) * pi / 180,
                  delai: Duration(milliseconds: (i * (_dureeSec * 1000 / (p.n * 1.7))).round()),
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

/// Une empreinte : elle apparaît, reste un moment, puis s'efface —
/// exactement le rythme de l'animation "pasEmpreinte" du site.
class _Empreinte extends StatefulWidget {
  final String svg;
  final double rotation;
  final Duration delai;
  const _Empreinte({required this.svg, required this.rotation, required this.delai});

  @override
  State<_Empreinte> createState() => _EmpreinteState();
}

class _EmpreinteState extends State<_Empreinte> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: _dureeSec));
    // 0% invisible → 18% visible → 62% visible → 100% invisible
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: _opacite), weight: 18),
      TweenSequenceItem(tween: ConstantTween(_opacite), weight: 44),
      TweenSequenceItem(tween: Tween(begin: _opacite, end: 0.0), weight: 38),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(widget.delai, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Transform.rotate(
        angle: widget.rotation,
        child: SvgPicture.string(
          widget.svg,
          width: _taille,
          height: _taille,
          colorFilter: const ColorFilter.mode(TytoColors.lune, BlendMode.srcIn),
        ),
      ),
    );
  }
}
