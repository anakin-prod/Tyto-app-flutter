import 'package:flutter/material.dart';
import '../screens/pets_screen.dart';
import '../screens/carnet_screen.dart';
import '../screens/tableau_screen.dart';
import '../screens/veille_screen.dart';

/// La navigation depuis le tiroir, partagée par tous les écrans : depuis
/// le chat, on empile normalement (retour possible) ; depuis une autre
/// rubrique, on remplace plutôt que d'empiler indéfiniment. Choisir
/// « Chat » depuis n'importe où revient proprement à l'accueil.
void handleDrawerNavigation(BuildContext context, String currentId, String selectedId) {
  Navigator.pop(context); // referme le tiroir
  if (selectedId == currentId) return;

  if (selectedId == 'chat') {
    Navigator.of(context).popUntil((route) => route.isFirst);
    return;
  }

  Widget screen;
  switch (selectedId) {
    case 'pets':
      screen = const PetsScreen();
      break;
    case 'carnet':
      screen = const CarnetScreen();
      break;
    case 'tableau':
      screen = const TableauScreen();
      break;
    case 'veille':
      screen = const VeilleScreen();
      break;
    default:
      return;
  }

  if (currentId == 'chat') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  } else {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }
}
