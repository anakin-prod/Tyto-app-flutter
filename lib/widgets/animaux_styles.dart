import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

// ============================================================
// Les réglages de texte de la rubrique « Mes animaux », calés sur
// ce que le navigateur dessine sur le site :
//  - hauteur de ligne « normal » : le navigateur arrondit au pixel
//    la partie haute (ascendante) et la partie basse (descendante)
//    de la police, séparément ;
//  - line-height CSS : l'espace en plus est réparti à parts égales
//    au-dessus et au-dessous du texte (TextLeadingDistribution.even).
// ============================================================

/// Ligne « normal » de Karla dans le navigateur : 0,917 em au-dessus
/// de la ligne de base et 0,252 em en dessous, arrondis chacun.
double ligneKarla(double taille) =>
    (taille * 0.917).roundToDouble() + (taille * 0.252).roundToDouble();

/// Ligne « normal » de Fraunces (0,978 em et 0,255 em, arrondis).
double ligneFraunces(double taille) =>
    (taille * 0.978).roundToDouble() + (taille * 0.255).roundToDouble();

/// Karla (police des boutons, champs et petits textes du site).
/// [interligne] = le line-height CSS ; sans lui, la ligne « normal ».
TextStyle karla(
  double taille, {
  FontWeight poids = FontWeight.w400,
  Color couleur = TytoColors.encre,
  double? interligne,
}) {
  return TytoText.ui(size: taille, weight: poids, color: couleur).copyWith(
    height: interligne ?? ligneKarla(taille) / taille,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Fraunces en gras (titres du site), ligne « normal » du navigateur.
TextStyle fraunces(double taille, {Color couleur = TytoColors.encre}) {
  return TytoText.display(size: taille, color: couleur).copyWith(
    height: ligneFraunces(taille) / taille,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Newsreader (textes de lecture du site) avec son line-height CSS.
TextStyle newsreader(double taille, {Color couleur = TytoColors.encre, required double interligne}) {
  return TytoText.body(size: taille, color: couleur).copyWith(
    height: interligne,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// L'ombre de paperCard : 0 3px 14px rgba(0,0,0,.28). Un flou CSS de
/// 14 px correspond à un écart-type de 7, soit 11,3 pour Flutter.
const BoxShadow ombrePapier = BoxShadow(color: Color(0x47000000), blurRadius: 11.3, offset: Offset(0, 3));

/// paperCard du site : papier ivoire, bord encre à 15 %, rayon 12, ombre.
const BoxDecoration decorationPapier = BoxDecoration(
  color: TytoColors.papier,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0x262A2118))),
  boxShadow: [ombrePapier],
);

/// Le « × » qui ferme les fenêtres du site (race, comportements, animal
/// perdu, équipe) : un <button> sans police précisée, donc la police
/// système du navigateur, 20 px, encre à 53 %, padding 0 4 px, ligne
/// « normal » de 23 px.
class CroixFermerAnimaux extends StatelessWidget {
  final VoidCallback onTap;
  const CroixFermerAnimaux({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).typography.black.bodyMedium;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '×',
          style: TextStyle(
            fontFamily: base?.fontFamily ?? 'Roboto',
            fontFamilyFallback: base?.fontFamilyFallback,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.15,
            leadingDistribution: TextLeadingDistribution.even,
            color: const Color(0x882A2118),
          ),
        ),
      ),
    );
  }
}
