import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'colors.dart';

class TytoText {
  /// Mode jour : le texte bleu sur ivoire gagne un cran d'épaisseur (comme
  /// les dessins). Le texte ivoire, doré ou posé sur un bouton ne change pas.
  static FontWeight _poids(FontWeight w, Color? couleur, {FontWeight max = FontWeight.w700}) {
    final c = couleur ?? TytoColors.lune;
    if (!TytoColors.estTraitSombre(c) || w.index >= max.index) return w;
    return FontWeight.values[w.index + 1];
  }

  static TextStyle display({double size = 20, FontWeight weight = FontWeight.w700, Color? color}) {
    return GoogleFonts.fraunces(fontSize: size, fontWeight: _poids(weight, color, max: FontWeight.w800), color: color ?? TytoColors.lune);
  }

  static TextStyle body({double size = 15, Color? color}) {
    return GoogleFonts.newsreader(fontSize: size, fontWeight: _poids(FontWeight.w400, color), color: color ?? TytoColors.lune);
  }

  // Poids par défaut 400, comme sur le site (Karla sans font-weight = normal).
  // Le site ne charge Karla qu'en 400, 500 et 700 : un texte demandé en 600
  // s'y affiche en 700. On fait pareil pour que l'app soit identique.
  static TextStyle ui({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) {
    final poids = weight == FontWeight.w600 ? FontWeight.w700 : weight;
    return GoogleFonts.karla(fontSize: size, fontWeight: _poids(poids, color), color: color ?? TytoColors.lune);
  }
}
