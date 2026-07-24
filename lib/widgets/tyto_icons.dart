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
