import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'compte_fenetre_email.dart';
import 'fenetre_papier.dart';
import 'site_icons.dart';

/// Le même message que sur le site (accountGate) quand un visiteur non
/// connecté essaie d'accéder aux compagnons, au carnet ou aux rappels :
/// ces fonctions demandent un compte, un simple email suffit.
class AccountGate extends StatelessWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Comme sur le site, la carte se pose en haut de la page (8 px de
    // marge du contenu + 16 px de la rubrique sous l'en-tête, 16 px sur
    // les côtés).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: FenetrePapier(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SiteIcon('IconPaw', size: 32, color: TytoColors.nuit)),
            // marginBottom 4 de l'icône et marginTop 8 du titre : en CSS,
            // les deux marges se confondent, il reste 8 px.
            const SizedBox(height: 8),
            Text(
              'Crée ton compte gratuit',
              textAlign: TextAlign.center,
              style: TytoText.display(size: 19, color: TytoColors.encre),
            ),
            const SizedBox(height: 6),
            Text(
              "Un simple email suffit pour enregistrer tes compagnons et débloquer le carnet de santé, "
              "les rappels de vaccins et 15 questions par jour. Tes questions d'essai sont conservées.",
              textAlign: TextAlign.center,
              style: TytoText.body(size: 15, color: TytoColors.encre)
                  .copyWith(height: 1.55, leadingDistribution: TextLeadingDistribution.even),
            ),
            const SizedBox(height: 14),
            Center(
              // Comme le site : la fenêtre « Crée ton compte gratuit ».
              child: _BoutonCompte(onTap: () => FenetreCreerCompte.afficher(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Créer mon compte » : le bouton doré du site (goldBtn), qui se tasse
/// légèrement sous le doigt. L'icône et le texte sont dans une ligne de
/// texte du bouton : le navigateur lui donne 42 px de haut (11 px
/// au-dessus du contenu, 14 px dessous).
class _BoutonCompte extends StatefulWidget {
  final VoidCallback onTap;
  const _BoutonCompte({required this.onTap});

  @override
  State<_BoutonCompte> createState() => _BoutonCompteState();
}

class _BoutonCompteState extends State<_BoutonCompte> {
  bool _enfonce = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _enfonce = true),
      onTapUp: (_) => setState(() => _enfonce = false),
      onTapCancel: () => setState(() => _enfonce = false),
      child: AnimatedScale(
        scale: _enfonce ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.ease,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 11, 22, 14),
          decoration: BoxDecoration(
            color: TytoColors.fauve,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SiteIcon('IconMail', size: 15, color: TytoColors.nuit),
              const SizedBox(width: 6),
              Text(
                'Créer mon compte',
                style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.nuit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
