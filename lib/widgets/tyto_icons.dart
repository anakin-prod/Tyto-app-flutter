import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

/// Les icônes de Tyto, avec les tracés SVG **exactement identiques** à ceux
/// du site (copiés depuis components/Icons.js). On ne les redessine pas à
/// la main : on reprend les mêmes chemins, pour un rendu strictement pareil.

String _wrap(String inner, {double strokeWidth = 1.6, String viewBox = '0 0 24 24'}) {
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox" fill="none"
     stroke="currentColor" stroke-width="$strokeWidth"
     stroke-linecap="round" stroke-linejoin="round">$inner</svg>''';
}

const _chatPath =
    '<path d="M20.5 11.6a8.2 8.2 0 0 1-8.3 8.2 8.7 8.7 0 0 1-3.7-.8l-5 1.6 1.7-4.8a8 8 0 0 1-1-3.9 8.2 8.2 0 0 1 8.3-8.2 8.2 8.2 0 0 1 8 7.9Z" />';

const _notebookPath = '''
<rect x="5" y="3" width="14" height="18" rx="2.2" />
<path d="M9 3v18" />
<path d="M12.2 8.2h3.6M12.2 12h3.6" />''';

const _chartPath = '''
<path d="M4 3.8v16.4h16.2" />
<rect x="7.2" y="13" width="2.9" height="7.2" rx="0.6" />
<rect x="12" y="8.6" width="2.9" height="11.6" rx="0.6" />
<rect x="16.8" y="15.4" width="2.9" height="4.8" rx="0.6" />''';

const _monitorPath = '''
<rect x="2.8" y="4" width="18.4" height="13" rx="2.2" />
<path d="M6.4 11.3h2.1l1.3-3 2.2 5.6 1.4-2.6h3.9" />
<path d="M9 21h6M12 17v4" />''';

/// La chouette — le dessin EXACT du logo (même grille 120x150, mêmes courbes).
/// Fond transparent : plus de carré autour, contrairement à une image PNG.
const _owlPath = '''
<path d="M60 12 C43 14, 31 27, 29 45 C27 62, 31 85, 37 103 C42 116, 49 127, 60 131 C71 127, 78 116, 83 103 C89 85, 93 62, 91 45 C89 27, 77 14, 60 12 Z" stroke-width="5.5" />
<path d="M38 56 C35 76, 39 97, 47 114" stroke-width="4" />
<path d="M82 56 C85 76, 81 97, 73 114" stroke-width="4" />
<path d="M60 26 C50 23, 40 29, 38 41 C36 54, 46 66, 60 74 C74 66, 84 54, 82 41 C80 29, 70 23, 60 26 Z" stroke-width="5" />
<ellipse cx="50" cy="45" rx="4.4" ry="5.2" fill="currentColor" stroke="none" />
<ellipse cx="70" cy="45" rx="4.4" ry="5.2" fill="currentColor" stroke="none" />
<path d="M60 53 L57 60 L60 66 L63 60 Z" stroke-width="3.6" />''';

/// Le logo Google officiel, avec ses quatre couleurs — pour le bouton
/// « Continuer avec Google », comme sur le site.
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 18});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>
  <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>
  <path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z"/>
  <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: size, height: size);
  }
}


// ---------- Les espèces ----------
// Les mêmes tracés que SPECIES_ICONS du site : chaque animal a son dessin,
// au lieu d'une patte générique pour tout le monde.

const _dogPath = '''
<path d="M8.5 8.5c-.38 1.05-1.08 2.03-2.34 2.5-1.93.72-3.58-.3-3.66-1-.11-.99 1.18-6.53 4-7 1.92-.32 3.65.85 3.65 2.24A7.5 7.5 0 0 1 14 5.28c0-1.39 1.84-2.6 3.77-2.28 2.82.47 4.11 6.01 4 7-.08.7-1.73 1.72-3.66 1-1.26-.47-1.96-1.45-2.34-2.5" />
<path d="M4.42 11.25A13.15 13.15 0 0 0 4 14.56C4 18.73 7.58 21 12 21s8-2.27 8-6.44c0-1.13-.17-2.24-.49-3.31" />
<path d="M8 14v.5" /><path d="M16 14v.5" />
<path d="M11.25 16.25h1.5L12 17z" />''';

const _catPath = '''
<path d="M5.6 10.6c0-3.3 2.9-5.9 6.4-5.9s6.4 2.6 6.4 5.9v1.5c0 3.6-2.9 6.5-6.4 6.5s-6.4-2.9-6.4-6.5v-1.5Z" />
<path d="M6 10.3 5.1 4.6l4.7 2.8" />
<path d="M18 10.3l.9-5.7-4.7 2.8" />
<circle cx="9.6" cy="11.8" r="0.85" fill="currentColor" stroke="none" />
<circle cx="14.4" cy="11.8" r="0.85" fill="currentColor" stroke="none" />
<path d="M12 14.2l-.85 1.05.85.85.85-.85z" />
<path d="M8.9 15.4H5.7M15.1 15.4h3.2M9 17l-2.7 1.1M15 17l2.7 1.1" />''';

const _rabbitPath = '''
<ellipse cx="9.3" cy="6.8" rx="1.75" ry="4.3" transform="rotate(-11 9.3 6.8)" />
<ellipse cx="14.7" cy="6.8" rx="1.75" ry="4.3" transform="rotate(11 14.7 6.8)" />
<ellipse cx="12" cy="15.6" rx="5.6" ry="5.1" />
<circle cx="9.9" cy="14.9" r="0.85" fill="currentColor" stroke="none" />
<circle cx="14.1" cy="14.9" r="0.85" fill="currentColor" stroke="none" />
<circle cx="12" cy="17.3" r="0.75" fill="currentColor" stroke="none" />
<path d="M9.6 18.4H6.8M14.4 18.4h2.8" />''';

const _birdPath = '''
<path d="M3.4 18H12a8 8 0 0 0 8-8V7a4 4 0 0 0-7.3-2.3L2.2 20" />
<circle cx="16.2" cy="7" r="0.85" fill="currentColor" stroke="none" />
<path d="m20 7 2.2.5-2.2.6" />
<path d="M10 18v3.2M14 17.8V21.2" />
<path d="M7 18a6 6 0 0 0 3.9-10.6" />''';

const _rodentPath = '''
<circle cx="7.4" cy="7.8" r="2.8" /><circle cx="16.6" cy="7.8" r="2.8" />
<circle cx="12" cy="14.2" r="5.9" />
<circle cx="9.9" cy="13.2" r="0.85" fill="currentColor" stroke="none" />
<circle cx="14.1" cy="13.2" r="0.85" fill="currentColor" stroke="none" />
<circle cx="12" cy="15.7" r="0.8" fill="currentColor" stroke="none" />
<path d="M9.6 16.9 6.9 17.9M14.4 16.9l2.7 1" />''';

const _reptilePath = '''
<path d="M4.5 20.5h5.5a4.2 4.2 0 0 0 0-8.4H8.8a3.8 3.8 0 0 1 0-7.6h1.4" />
<ellipse cx="13.6" cy="4.5" rx="3.4" ry="2.6" />
<circle cx="14.8" cy="3.9" r="0.7" fill="currentColor" stroke="none" />
<path d="M17 4.5h2.6M19.6 4.5l1.7-1M19.6 4.5l1.7 1" />''';

const _fishPath = '''
<path d="M15.4 8c-1.1-.9-2.5-1.5-4-1.5-3.8 0-7.4 2.5-8.9 5.5 1.5 3 5.1 5.5 8.9 5.5 1.5 0 2.9-.6 4-1.5" />
<path d="M15.4 8 21 5.4c.4 4.4.4 8.8 0 13.2L15.4 16c1.3-1.1 2-2.5 2-4s-.7-2.9-2-4Z" />
<circle cx="7.2" cy="11" r="0.9" fill="currentColor" stroke="none" />''';

const _horsePath = '''
<path d="M3.6 13.8 8.6 7.6c.7-.9 1.6-1.6 2.6-2L10.6 2.4 13 5 14 2.7 15.2 5.9c1.7 1.5 2.8 3.5 3.2 5.8L19.4 21H12l-.4-5.8c-1.6.6-3.4.8-5 .6L4 15.2Z" />
<circle cx="10.4" cy="8.9" r="0.85" fill="currentColor" stroke="none" />
<circle cx="5.3" cy="13.5" r="0.65" fill="currentColor" stroke="none" />
<path d="M14.9 7.9c1.3 1.7 2.1 3.8 2.3 6l.3 3.1" />''';

const _pawPath = '''
<ellipse cx="7.3" cy="9" rx="2" ry="2.6" transform="rotate(-16 7.3 9)" />
<ellipse cx="16.7" cy="9" rx="2" ry="2.6" transform="rotate(16 16.7 9)" />
<ellipse cx="10.4" cy="5.6" rx="1.8" ry="2.4" />
<ellipse cx="13.6" cy="5.6" rx="1.8" ry="2.4" />
<path d="M12 12.4c2.6 0 4.8 2 4.8 4.4 0 2-1.5 3.3-3.4 3.3-.6 0-1-.2-1.4-.2s-.8.2-1.4.2c-1.9 0-3.4-1.3-3.4-3.3 0-2.4 2.2-4.4 4.8-4.4Z" />''';

/// L'icône qui correspond à l'espèce, comme SpeciesIcon sur le site.
class SpeciesIcon extends StatelessWidget {
  final String species;
  final double size;
  final Color? color;
  const SpeciesIcon({super.key, required this.species, this.size = 18, this.color});

  static String _pathFor(String s) {
    switch (s) {
      case 'chien': return _dogPath;
      case 'chat': return _catPath;
      case 'lapin': return _rabbitPath;
      case 'oiseau': return _birdPath;
      case 'rongeur': return _rodentPath;
      case 'reptile': return _reptilePath;
      case 'poisson': return _fishPath;
      case 'cheval': return _horsePath;
      default: return _pawPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _wrap(_pathFor(species), strokeWidth: 1.5),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? TytoColors.lune, BlendMode.srcIn),
    );
  }
}

class TytoIcon extends StatelessWidget {
  final String _svg;
  final double size;
  final Color? color;
  final double _ratio;

  const TytoIcon._(this._svg, {required this.size, this.color, double ratio = 1})
      : _ratio = ratio;

  factory TytoIcon.chat({double size = 18, Color? color}) =>
      TytoIcon._(_wrap(_chatPath), size: size, color: color);

  factory TytoIcon.notebook({double size = 18, Color? color}) =>
      TytoIcon._(_wrap(_notebookPath), size: size, color: color);

  factory TytoIcon.chart({double size = 18, Color? color}) =>
      TytoIcon._(_wrap(_chartPath), size: size, color: color);

  factory TytoIcon.monitor({double size = 18, Color? color}) =>
      TytoIcon._(_wrap(_monitorPath), size: size, color: color);

  /// La chouette du logo. Sa grille est 120x150, donc plus haute que large :
  /// on garde le même rapport que sur le site (largeur = 0.82 x hauteur).
  factory TytoIcon.owl({double size = 18, Color? color}) => TytoIcon._(
        _wrap(_owlPath, strokeWidth: 1.6, viewBox: '0 0 120 150'),
        size: size,
        color: color,
        ratio: 0.82,
      );

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size * _ratio,
      height: size,
      colorFilter: ColorFilter.mode(color ?? TytoColors.lune, BlendMode.srcIn),
    );
  }
}
