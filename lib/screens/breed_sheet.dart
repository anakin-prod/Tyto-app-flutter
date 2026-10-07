import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../data/breeds.dart';
import '../widgets/tyto_icons.dart';

/// « À surveiller pour sa race » — pré-écrit, aucun appel à l'IA, s'ouvre
/// instantanément. Des tendances connues de la race, jamais un diagnostic.
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
      barrierColor: const Color(0xCC0A0E18),
      builder: (_) => BreedSheet(pet: pet, race: race),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Container(
          decoration: BoxDecoration(
            color: TytoColors.papier,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SpeciesIcon(species: pet.species, size: 18, color: TytoColors.encre),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(titreRace, style: TytoText.display(size: 19, color: TytoColors.encre)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('×', style: TytoText.ui(size: 22, color: TytoColors.encre.withOpacity(0.55))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${race.nom} : ce qu\'il vaut mieux garder en tête pour ${pet.name}.',
                style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: race.points.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
                    ),
                    child: Text(
                      race.points[i],
                      style: TytoText.body(size: 14, color: TytoColors.encre).copyWith(height: 1.55),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                avertissementRace,
                style: TytoText.ui(size: 11, color: TytoColors.encre.withOpacity(0.55)).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
