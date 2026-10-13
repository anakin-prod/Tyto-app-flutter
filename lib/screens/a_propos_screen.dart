import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../services/theme_service.dart';
import '../theme/typography.dart';
import '../services/legal_service.dart';

/// « À propos » : les textes légaux, hébergés sur le site.
class AProposScreen extends StatelessWidget {
  const AProposScreen({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AProposScreen()));
  }

  Widget _ligne(String titre, String sous, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TytoColors.champ.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TytoColors.encre.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.encre)),
                      const SizedBox(height: 2),
                      Text(sous,
                          style: TytoText.ui(size: 12, weight: FontWeight.w400, color: TytoColors.encre.withOpacity(0.6))),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 18, color: TytoColors.encre.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.barresSurPapier(),
      child: Scaffold(
        backgroundColor: TytoColors.papier,
        appBar: AppBar(
          backgroundColor: TytoColors.papier,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: TytoColors.encre),
          title: Text('À propos', style: TytoText.display(size: 20, color: TytoColors.encre)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _ligne('Politique de confidentialité', 'Comment tes données sont utilisées', LegalService.confidentialite),
            _ligne("Conditions générales d'utilisation", "Les règles d'usage de Tyto", LegalService.conditions),
          ],
        ),
      ),
    );
  }
}
