import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../services/platform_service.dart';
import '../theme/typography.dart';
import '../services/billing_service.dart';
import '../services/achats_service.dart';
import '../services/auth_service.dart';
import 'compte_fenetre_email.dart';
import 'fenetre_papier.dart';

/// Le même message que sur le site quand on touche une fonction réservée
/// au plan Pro. On explique à qui elle s'adresse et ce qu'elle apporte,
/// plutôt que de simplement bloquer.
class ProUpsell extends StatelessWidget {
  const ProUpsell({super.key});

  /// Ouvre le message par-dessus l'écran courant (voile rgba(10,14,24,0.75)).
  static Future<void> afficher(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: const Color(0xBF0A0E18),
      builder: (_) => const ProUpsell(),
    );
  }

  static const _avantages = [
    'Veille sanitaire quotidienne sur tous tes animaux',
    'Saisie vocale des observations',
    "Lecture d'ordonnance par photo",
    'Synthèse vétérinaire en un clic',
    "Journal d'équipe partagé",
    'Animaux illimités',
  ];

  Widget _boutonVert(String texte, VoidCallback onTap) {
    return BoutonPilule(
      texte: texte,
      onTap: onTap,
      fond: TytoColors.vert,
      encre: const Color(0xFF0F2A24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      taille: 14.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    const egal = TextLeadingDistribution.even;
    final texte = TytoText.body(size: 14, color: TytoColors.encre).copyWith(height: 1.45, leadingDistribution: egal);
    return CadreDialogue(
      marge: 20,
      largeurMax: 420,
      child: FenetrePapier(
        lisere: TytoColors.vert,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: IconeTrait.bouclier(size: 28, color: TytoColors.vert),
            ),
            const SizedBox(height: 6),
            Text('Une fonctionnalité Pro', style: TytoText.display(size: 21, color: TytoColors.encre)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Le plan '),
                  TextSpan(
                    text: 'Pro',
                    style: GoogleFonts.newsreader(fontSize: 15.5, fontWeight: FontWeight.w700, color: TytoColors.encre),
                  ),
                  const TextSpan(
                    text: " est fait pour celles et ceux qui s'occupent de plusieurs "
                        'animaux : refuges, éleveurs, pensions, pet-sitters.',
                  ),
                ],
              ),
              style:
                  TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.6, leadingDistribution: egal),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _avantages.length; i++)
              Padding(
                // la dernière ligne garde l'écart de 16 px de la liste du site
                padding: EdgeInsets.only(bottom: i == _avantages.length - 1 ? 16 : 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconeTrait.coche(size: 13, color: TytoColors.vert),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_avantages[i], style: texte)),
                  ],
                ),
              ),
            // Sur iOS : jamais de bouton vers le site (règle 3.1.1 d'Apple) ; le bouton
            // n'existe que si les achats intégrés Apple sont en place.
            if (!PlatformInfo.estIOS)
              _boutonVert('Découvrir le plan Pro — 19,99 €/mois', () {
                Navigator.pop(context);
                BillingService.openOffers();
              })
            else if (AchatsService.disponible)
              _boutonVert('Voir les offres', () {
                Navigator.pop(context);
                AchatsService.ouvrirOffres(context);
              }),
            const SizedBox(height: 12),
            LienDiscret(
              texte: PlatformInfo.estIOS ? 'Fermer' : 'Plus tard',
              onTap: () => Navigator.pop(context),
              centre: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// La fenêtre « L'œil de Tyto » du site, quand un compte gratuit veut
/// joindre une photo : la fonction est Premium.
class PhotoUpsell extends StatelessWidget {
  const PhotoUpsell({super.key});

  /// Ouvre la fenêtre par-dessus l'écran courant (voile rgba(10,14,24,0.72)).
  static Future<void> afficher(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: const Color(0xB80A0E18),
      builder: (_) => const PhotoUpsell(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iosSansAchat = PlatformInfo.estIOS && !AchatsService.disponible;
    return CadreDialogue(
      marge: 20,
      largeurMax: 380,
      child: FenetrePapier(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("L'œil de Tyto", style: TytoText.display(size: 19, color: TytoColors.encre)),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Photographie une plante, un aliment, un insecte ou un bouton suspect : '
                        "Tyto l'analyse pour ton compagnon. C'est une fonction ",
                  ),
                  TextSpan(
                    text: 'Premium',
                    style: GoogleFonts.newsreader(fontSize: 15.5, fontWeight: FontWeight.w700, color: TytoColors.encre),
                  ),
                  const TextSpan(text: ', avec les questions illimitées.'),
                ],
              ),
              style: TytoText.body(size: 15.5, color: TytoColors.encre)
                  .copyWith(height: 1.55, leadingDistribution: TextLeadingDistribution.even),
            ),
            // Sur iOS : jamais de bouton vers le site (règle 3.1.1 d'Apple).
            if (!iosSansAchat) ...[
              const SizedBox(height: 12),
              BoutonDore(
                // Le prix du site, sauf sur iOS où seul l'App Store l'affiche.
                texte: PlatformInfo.estIOS ? 'Voir les offres' : 'Passer Premium — 10,99 €/mois',
                onTap: () {
                  Navigator.pop(context);
                  // Comme goPremium sur le site : un visiteur crée d'abord
                  // son compte (fenêtre « Crée ton compte gratuit »).
                  if (!AuthService.isSignedIn) {
                    FenetreCreerCompte.afficher(context);
                  } else if (PlatformInfo.estIOS) {
                    AchatsService.ouvrirOffres(context);
                  } else {
                    BillingService.openOffers();
                  }
                },
              ),
            ],
            const SizedBox(height: 10),
            LienDiscret(
              texte: PlatformInfo.estIOS ? 'Fermer' : 'Plus tard',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
