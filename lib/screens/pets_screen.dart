import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/pet.dart';

final _samplePets = [
  Pet(id: '1', name: 'Max', species: 'chien', breed: 'Berger australien', birthdate: DateTime(2021, 3, 12), weightKg: 24.5),
  Pet(id: '2', name: 'Plume', species: 'oiseau', breed: 'Perruche', birthdate: DateTime(2023, 7, 2), weightKg: 0.04),
];

IconData _speciesIcon(String s) => Icons.pets_rounded;

class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pets = _samplePets;
    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        title: Text('Mes animaux', style: TytoText.display(size: 19)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: TytoColors.fauve),
            tooltip: 'Ajouter un compagnon',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("L'ajout d'un compagnon arrive à une prochaine étape.")),
              );
            },
          ),
        ],
      ),
      body: pets.isEmpty
          ? const TytoEmptyState(icon: Icons.pets_rounded, message: "Aucun compagnon pour l'instant.\nAjoute ton premier animal avec le bouton +.")
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pets.length,
              itemBuilder: (context, i) {
                final p = pets[i];
                final ageTxt = p.ageYears != null ? "${p.ageYears} an${p.ageYears! > 1 ? 's' : ''}" : null;
                final subtitleParts = [
                  if (p.breed != null) p.breed!,
                  if (ageTxt != null) ageTxt,
                ];
                return TytoTile(
                  icon: _speciesIcon(p.species),
                  title: p.name,
                  subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
                  trailing: p.weightKg != null ? '${p.weightKg} kg' : null,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Le profil détaillé de ${p.name} arrive bientôt.')),
                    );
                  },
                );
              },
            ),
    );
  }
}
