import 'package:flutter/material.dart';

class TytoColors {
  static const nuit = Color(0xFF151C2C);
  static const nuit2 = Color(0xFF1F2940);
  static const fauve = Color(0xFFC99A55);
  static const brume = Color(0xFF98A1B6);
  static const vert = Color(0xFF7FB2A6);
  static const urgence = Color(0xFFC9553F);
  static const lune = Color(0xFFEDE7D6);

  /// Le papier ivoire des réponses de Tyto, et l'encre qu'on écrit dessus.
  static const papier = Color(0xFFF4EDDC);
  static const encre = Color(0xFF2A2118);

  /// Le fond du site n'est pas une couleur plate : c'est une lueur douce
  /// en haut à droite, qui se fond vers le bleu nuit.
  static const fondApp = RadialGradient(
    center: Alignment(0.44, -1.24), // 72 % à droite, -12 % en haut
    radius: 1.4,
    colors: [nuit2, nuit],
    stops: [0.0, 0.58],
  );
}
