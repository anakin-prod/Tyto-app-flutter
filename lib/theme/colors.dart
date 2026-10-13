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

  /// L'ivoire du FOND en mode jour : exactement la même teinte que l'ivoire
  /// fixe (mêmes proportions de rouge, vert et bleu), mais à 92 % de sa
  /// luminosité, pour que le fond soit moins éclatant à l'œil.
  static const ivoireJour = Color(0xFFE0DACA);
  static const _ivoireJourClair = Color(0xFFE7E3D7);
  static const _ivoireJourProfond = Color(0xFFD4CBB6);

  // ---- Changent avec le mode ----
  /// Le fond de l'application : bleu nuit, ou ivoire en mode jour.
  static Color get fond => jour ? ivoireJour : nuit;
  static Color get nuit2 => jour ? _ivoireJourClair : const Color(0xFF1F2940);
  static Color get nuitProfonde => jour ? _ivoireJourProfond : const Color(0xFF0A0E18);
  static Color get brume => jour ? const Color(0xFF5C667F) : const Color(0xFF98A1B6);
  static Color get vert => jour ? const Color(0xFF4B8F80) : const Color(0xFF7FB2A6);
  /// En mode jour, le trait bleu est un bleu un peu plus vif que le bleu nuit
  /// du fond : le bleu nuit, quasi noir, paraissait noir sur l'ivoire.
  static const _bleuTrait = Color(0xFF1B2B52);
  static Color get lune => jour ? _bleuTrait : const Color(0xFFEDE7D6);

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

  /// En mode jour, un trait fin et sombre sur fond clair paraît noir : on
  /// épaissit donc les traits BLEUS (dessins et textes) sur l'ivoire. Les
  /// traits ivoire sur fond bleu (mode nuit, ou papier bleu du mode jour) et
  /// les traits dorés ne changent jamais.
  static bool estTraitSombre(Color c) => jour && c.computeLuminance() < 0.35;

  /// Le coefficient d'épaisseur des dessins pour cette couleur de trait.
  static double epaisseur(Color c) => estTraitSombre(c) ? 1.35 : 1.0;

  /// Épaissit les `stroke-width` d'un SVG quand on le dessine en bleu sur ivoire.
  static String epaissirSvg(String svg, Color c) {
    final k = epaisseur(c);
    if (k == 1.0) return svg;
    return svg.replaceAllMapped(
      RegExp(r'stroke-width="([0-9.]+)"'),
      (m) => 'stroke-width="${(double.parse(m[1]!) * k).toStringAsFixed(2)}"',
    );
  }

  /// Le fond du site : une lueur douce en haut à droite qui se fond vers le fond.
  static RadialGradient get fondApp => RadialGradient(
        center: const Alignment(0.44, -1.24), // 72 % à droite, -12 % en haut
        radius: 1.4,
        colors: [nuit2, fond],
        stops: const [0.0, 0.58],
      );
}
