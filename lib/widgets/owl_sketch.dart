import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

/// Le logo officiel de Tyto : le tracé SVG **copié à l'identique** depuis
/// components/OwlSketch.js du site — avec le perchoir, les pattes, les
/// plumes et tous les détails. Ce n'est PAS l'icône abrégée du menu.
class OwlSketch extends StatefulWidget {
  /// Largeur du logo. La hauteur vaut 1.25 x la largeur, comme sur le site.
  final double size;
  final Color? ink;

  /// La couleur des yeux (par défaut la même que le trait). Sert par exemple
  /// à avoir des yeux dorés sur un logo ivoire.
  final Color? eyeColor;

  /// Les petits détails (perchoir, pattes, plumes). Sur le site, ils sont
  /// affichés par défaut ; on peut les retirer aux très petites tailles.
  final bool detail;

  /// Pour les très petits logos (sans [detail]) : garde quand même le
  /// perchoir et les pattes, dessinés un peu plus épais pour rester visibles,
  /// sans les plumes. Le logo garde ainsi sa silhouette perchée.
  final bool perchoirEtPattes;

  /// Quand Tyto réfléchit, elle cligne beaucoup plus vite (1,7 s au lieu
  /// de 6,5 s) — exactement comme sur le site.
  final bool thinking;

  const OwlSketch({
    super.key,
    this.size = 40,
    this.ink,
    this.eyeColor,
    this.detail = true,
    this.perchoirEtPattes = false,
    this.thinking = false,
  });

  @override
  State<OwlSketch> createState() => _OwlSketchState();
}

class _OwlSketchState extends State<OwlSketch> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  // Quand elle réfléchit : la même durée que l'animation "blink" du site
  // (1,7 s). Au repos, elle cligne un peu plus souvent que sur le site : toutes
  // les 4 secondes environ au lieu de 6,5 s.
  Duration get _duree => widget.thinking
      ? const Duration(milliseconds: 1700)
      : const Duration(milliseconds: 4000);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _duree)..repeat();
  }

  @override
  void didUpdateWidget(covariant OwlSketch old) {
    super.didUpdateWidget(old);
    if (old.thinking != widget.thinking) {
      _c.duration = _duree;
      _c
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Un clignement : l'œil reste ouvert presque tout le temps, puis s'écrase
  /// à 8 % de sa hauteur en un clin d'œil. Le clignement lui-même dure
  /// toujours 0,455 s (comme sur le site, où il occupe 7 % de 6,5 s), que le
  /// cycle soit court ou long : seul l'intervalle entre deux clignements change.
  double _ouvertureOeil(double t) {
    final d = _duree.inMilliseconds.toDouble();
    final clignement = widget.thinking ? 0.07 * d : 455.0;
    final debut = 1 - clignement / d;
    final creux = debut + clignement * (25 / 70) / d; // il se ferme vite, se rouvre plus doucement
    const ferme = 0.08;
    if (t < debut) return 1;
    if (t < creux) return 1 - (1 - ferme) * ((t - debut) / (creux - debut));
    return ferme + (1 - ferme) * ((t - creux) / (1 - creux));
  }

  /// Les traits sont un peu épaissis : à petite taille, le tracé fin d'origine
  /// se pixélise. Le gain est plus fort pour les petits logos.
  String _epaissir(String svg) {
    final k = (widget.size <= 60 ? 1.3 : 1.15) * TytoColors.epaisseur(widget.ink ?? TytoColors.lune);
    return svg.replaceAllMapped(RegExp(r'stroke-width="([0-9.]+)"'),
        (m) => 'stroke-width="${(double.parse(m[1]!) * k).toStringAsFixed(2)}"');
  }

  String _svg(String hex, double ouverture) => _epaissir(_svgBrut(hex, ouverture));

  String _svgBrut(String hex, double ouverture) {
    final yeux = widget.eyeColor == null
        ? hex
        : '#${widget.eyeColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    // Petit logo : le perchoir et les pattes sont tracés plus épais (trait de
    // 2,6 au lieu de 1,6 / 1,3), sinon ils disparaissent à 17-19 px.
    final petit = !widget.detail && widget.perchoirEtPattes;
    final perch = widget.detail
        ? '<path d="M20 145 C40 140.5, 84 141.5, 101 144.5" stroke="$hex" stroke-width="1.6" stroke-linecap="round" opacity="0.65" />'
        : petit
            ? '<path d="M20 145 C40 140.5, 84 141.5, 101 144.5" stroke="$hex" stroke-width="2.6" stroke-linecap="round" opacity="0.8" />'
            : '';

    final plumes = widget.detail
        ? '''
<g stroke="$hex" stroke-width="0.8" opacity="0.5" stroke-linecap="round">
  <path d="M42 82 l5 -2.5 M43 90 l5 -2.5 M45 98 l5 -2.5" />
  <path d="M78 82 l-5 -2.5 M77 90 l-5 -2.5 M75 98 l-5 -2.5" />
  <path d="M46 33 l3 3 M52 20 l1.5 3 M68 20 l-1.5 3 M74 33 l-3 3" />
  <path d="M56 84 l2 2 M64 86 l-2 2 M60 94 l0 2.5 M54 104 l2 2 M66 104 l-2 2" />
</g>'''
        : '';

    final pattes = (widget.detail || petit)
        ? '''
<g stroke="$hex" stroke-width="${petit ? '2.6' : '1.3'}" stroke-linecap="round">
  <path d="M52 130 L50 141 M50 141 L46 146 M50 141 L50 147 M50 141 L54 146" />
  <path d="M68 130 L70 141 M70 141 L66 146 M70 141 L70 147 M70 141 L74 146" />
</g>'''
        : '';

    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 150" fill="none">
  $perch
  <path d="M60 12 C43 14, 31 27, 29 45 C27 62, 31 85, 37 103 C42 116, 49 127, 60 131 C71 127, 78 116, 83 103 C89 85, 93 62, 91 45 C89 27, 77 14, 60 12 Z"
        stroke="$hex" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" />
  <path d="M31 47 C29.5 63, 33.5 84, 39 100" stroke="$hex" stroke-width="0.9" opacity="0.3" />
  <path d="M89 47 C90.5 63, 86.5 84, 81 100" stroke="$hex" stroke-width="0.9" opacity="0.3" />
  <path d="M38 56 C35 76, 39 97, 47 114" stroke="$hex" stroke-width="1.2" stroke-linecap="round" />
  <path d="M82 56 C85 76, 81 97, 73 114" stroke="$hex" stroke-width="1.2" stroke-linecap="round" />
  <path d="M47 114 C49 118, 52 121, 56 123 M73 114 C71 118, 68 121, 64 123"
        stroke="$hex" stroke-width="1" stroke-linecap="round" />
  <path d="M60 26 C50 23, 40 29, 38 41 C36 54, 46 66, 60 74 C74 66, 84 54, 82 41 C80 29, 70 23, 60 26 Z"
        stroke="$hex" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
  <path d="M60 27 L60 52" stroke="$hex" stroke-width="0.9" opacity="0.45" />
  <ellipse cx="50" cy="45" rx="3.4" ry="${(4.2 * ouverture).toStringAsFixed(2)}" fill="$yeux" />
  <ellipse cx="70" cy="45" rx="3.4" ry="${(4.2 * ouverture).toStringAsFixed(2)}" fill="$yeux" />
  <path d="M60 52 L57.4 59 L60 65 L62.6 59 Z" stroke="$hex" stroke-width="1.1" stroke-linejoin="round" />
  $plumes
  $pattes
</svg>''';
  }

  @override
  Widget build(BuildContext context) {
    final hex = '#${(widget.ink ?? TytoColors.lune).value.toRadixString(16).padLeft(8, '0').substring(2)}';
    // Si l'appareil est réglé sur « animations réduites », on garde les
    // yeux grands ouverts plutôt que de faire clignoter le logo.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return SvgPicture.string(
        _svg(hex, 1),
        width: widget.size,
        height: widget.size * 1.25,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return SvgPicture.string(
          _svg(hex, _ouvertureOeil(_c.value)),
          width: widget.size,
          height: widget.size * 1.25, // même proportion que sur le site
        );
      },
    );
  }
}
