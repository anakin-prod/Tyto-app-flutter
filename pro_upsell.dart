import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/billing_service.dart';

/// Le même message que sur le site quand on touche une fonction réservée
/// au plan Pro. On explique à qui elle s'adresse et ce qu'elle apporte,
/// plutôt que de simplement bloquer.
class ProUpsell extends StatelessWidget {
  const ProUpsell({super.key});

  /// Ouvre le message par-dessus l'écran courant.
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: const BoxDecoration(
          color: TytoColors.papier,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          border: Border(top: BorderSide(color: TytoColors.vert, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 28, color: TytoColors.vert),
              const SizedBox(height: 6),
              Text('Une fonctionnalité Pro',
                  style: TytoText.display(size: 21, color: TytoColors.encre)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.6),
                  children: [
                    const TextSpan(text: 'Le plan '),
                    const TextSpan(text: 'Pro', style: TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                      text: " est fait pour celles et ceux qui s'occupent de plusieurs "
                          'animaux : refuges, éleveurs, pensions, pet-sitters.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._avantages.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded, size: 15, color: TytoColors.vert),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(a,
                            style: TytoText.body(size: 14, color: TytoColors.encre)
                                .copyWith(height: 1.45)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    BillingService.openOffers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.vert,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text('Découvrir le plan Pro',
                      style: TytoText.ui(size: 15, weight: FontWeight.w700, color: const Color(0xFF0F2A24))),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Plus tard',
                      style: TytoText.ui(size: 13.5, color: TytoColors.encre.withOpacity(0.65))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
