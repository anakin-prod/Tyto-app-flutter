import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'colors.dart';

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
