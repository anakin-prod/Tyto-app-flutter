import 'package:flutter/material.dart';
import 'colors.dart';

/// Le fond de l'application, repris du site : ce n'est pas un bleu plat,
/// mais une lueur douce en haut à droite qui se fond vers le bleu nuit.
/// (Sur le site : radial-gradient à 72 % / -12 %, de NUIT2 vers NUIT.)
///
/// À utiliser à la place d'une couleur de fond unie, sur chaque écran.
class TytoBackground extends StatelessWidget {
  final Widget child;
  const TytoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: TytoColors.fondApp),
      child: child,
    );
  }
}
