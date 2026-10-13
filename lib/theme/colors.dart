import 'package:flutter/material.dart';

/// Les couleurs de Tyto, en deux palettes : la nuit (par défaut) et le jour
/// (le même dessin inversé : fond ivoire, traits bleus). Le doré, l'orange
/// d'urgence et le bleu nuit « fixe » (le texte posé sur les boutons dorés)
/// ne changent jamais.
///
/// `jour` est réglé par ThemeService (Paramètres > Mode jour). Toutes les
/// couleurs qui changent sont des « getters » : elles se relisent à chaque
/// dessin, donc il suffit de redessiner l'écran après un changement.
class TytoColors {
  static bool jour = false;

  // ---- Ne changent jamais ----
  /// Le bleu nuit « fixe » : le texte et les icônes posés sur un bouton doré.
  static const nuit = Color(0xFF151C2C);
  static const fauve = Color(0xFFC99A55);
  static const urgence = Color(0xFFC9553F);
  static const _ivoireFixe = Color(0xFFF4EDDC);

  // ---- Changent avec le mode ----
  /// Le fond de l'application : bleu nuit, ou ivoire en mode jour.
  static Color get fond => jour ? _ivoireFixe : nuit;
  static Color get nuit2 => jour ? const Color(0xFFFBF7EA) : const Color(0xFF1F2940);
  static Color get nuitProfonde => jour ? const Color(0xFFE6DDC6) : const Color(0xFF0A0E18);
  static Color get brume => jour ? const Color(0xFF5C667F) : const Color(0xFF98A1B6);
  static Color get vert => jour ? const Color(0xFF4B8F80) : const Color(0xFF7FB2A6);
  static Color get lune => jour ? nuit : const Color(0xFFEDE7D6);

  /// Le papier des réponses de Tyto et des fenêtres, et l'encre dessus :
  /// ivoire et brun en mode nuit, bleu et ivoire en mode jour.
  static Color get papier => jour ? const Color(0xFF1B2540) : _ivoireFixe;
  static Color get encre => jour ? const Color(0xFFEDE7D6) : const Color(0xFF2A2118);

  /// Le fond des champs de saisie posés sur le papier.
  static Color get champ => jour ? const Color(0xFF273250) : Colors.white;

  /// Une couleur d'accent foncée écrite sur du papier (vert, brun, rouge) :
  /// éclaircie en mode jour pour rester lisible sur le papier bleu.
  static Color surPapier(Color c) =>
      jour ? Color.lerp(c, const Color(0xFFEDE7D6), 0.55)! : c;

  /// Le fond du site : une lueur douce en haut à droite qui se fond vers le fond.
  static RadialGradient get fondApp => RadialGradient(
        center: const Alignment(0.44, -1.24), // 72 % à droite, -12 % en haut
        radius: 1.4,
        colors: [nuit2, fond],
        stops: const [0.0, 0.58],
      );
}
