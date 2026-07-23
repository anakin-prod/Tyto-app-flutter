import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'colors.dart';

/// Les 3 polices du site, dans leurs rôles respectifs :
/// - Fraunces : le titre "Tyto", les gros titres (DISPLAY sur le site)
/// - Newsreader : le texte des réponses de l'IA (BODY sur le site)
/// - Karla : les boutons, menus, interface (UI sur le site)
class TytoText {
  static TextStyle display({double size = 20, FontWeight weight = FontWeight.w700, Color? color}) {
    return GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color ?? TytoColors.lune);
  }

  static TextStyle body({double size = 15, Color? color}) {
    return GoogleFonts.newsreader(fontSize: size, color: color ?? TytoColors.lune);
  }

  static TextStyle ui({double size = 14, FontWeight weight = FontWeight.w500, Color? color}) {
    return GoogleFonts.karla(fontSize: size, fontWeight: weight, color: color ?? TytoColors.lune);
  }
}
