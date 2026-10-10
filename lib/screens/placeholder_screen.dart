import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Écran d'attente pour une rubrique pas encore disponible dans l'app.
/// Titre et texte au style des autres écrans et des états vides du site
/// (texte brume, 14 px, centré).
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: TytoText.display(size: 19)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '$title arrive bientôt.',
            textAlign: TextAlign.center,
            style: TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.brume),
          ),
        ),
      ),
    );
  }
}
