import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/pet.dart';
import '../data/breeds.dart';
import '../widgets/site_icons.dart';
import '../widgets/animaux_styles.dart';

/// « À surveiller pour sa race » — pré-écrit, aucun appel à l'IA, s'ouvre
/// instantanément. Des tendances connues de la race, jamais un diagnostic.
/// Même fenêtre que sur le site : carte papier centrée sur un voile sombre.
class BreedSheet extends StatelessWidget {
  final Pet pet;
  final RaceInfo race;
  const BreedSheet({super.key, required this.pet, required this.race});

  /// N'ouvre rien si la race de l'animal n'est pas reconnue.
  static Future<void> afficher(BuildContext context, Pet pet) {
    final race = racePourAnimal(pet.species, pet.breed);
    if (race == null) return Future.value();
    return showDialog(
      context: context,
      barrierColor: const Color(0xCC0A0E18), // rgba(10,14,24,0.8)
      builder: (_) => BreedSheet(pet: pet, race: race),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          // paperCard du site ; ce qui défile reste dans l'arrondi.
          decoration: decorationPapier,
          clipBehavior: Clip.antiAlias,
          // Toute la carte défile, en-tête compris (overflowY: auto du site).
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SiteIcon.espece(pet.species, size: 18, color: TytoColors.encre),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(titreRace, style: fraunces(19)),
                    ),
                    const SizedBox(width: 8),
                    CroixFermerAnimaux(onTap: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${race.nom} : ce qu\'il vaut mieux garder en tête pour ${pet.name}.',
                  style: karla(12.5, couleur: const Color(0x992A2118)),
                ),
                const SizedBox(height: 12),
                for (final point in race.points)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x55FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x262A2118)),
                    ),
                    child: Text(point, style: karla(13.5, interligne: 1.6)),
                  ),
                // 8 de marge sous le dernier point + 2 = les 10 du site.
                const SizedBox(height: 2),
                Text(
                  avertissementRace,
                  style: karla(11, couleur: const Color(0x772A2118), interligne: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
