import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/background.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/pet.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/account_gate.dart';
import '../widgets/tyto_icons.dart';

const _speciesOptions = ['chien', 'chat', 'lapin', 'oiseau', 'rongeur', 'reptile', 'autre'];

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  List<Pet> _pets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pets = await DataService.loadPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de charger tes compagnons pour l'instant.")),
      );
    }
  }

  Future<void> _openForm({Pet? pet}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PetForm(pet: pet),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Pet pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        title: Text('Supprimer ${pet.name} ?', style: TytoText.display(size: 17)),
        content: Text(
          'Son carnet de santé sera supprimé également. Cette action est définitive.',
          style: TytoText.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: TytoText.ui(color: TytoColors.urgence, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DataService.deletePet(pet.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Mes animaux', style: TytoText.display(size: 19)),
        actions: [
          if (AuthService.isSignedIn)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: TytoColors.fauve),
              tooltip: 'Ajouter un compagnon',
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: !AuthService.isSignedIn
          ? const AccountGate()
          : _loading
          ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
          : _pets.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                    decoration: BoxDecoration(
                      color: TytoColors.papier,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TytoColors.encre.withOpacity(0.12)),
                    ),
                    child: Column(
                      children: [
                        SpeciesIcon(species: 'autre', size: 32, color: TytoColors.nuit),
                        const SizedBox(height: 8),
                        Text('Présente-moi ton compagnon',
                            textAlign: TextAlign.center,
                            style: TytoText.display(size: 19, color: TytoColors.encre)),
                        const SizedBox(height: 6),
                        Text(
                          'Une fois son profil créé, chaque réponse de Tyto sera personnalisée '
                          'pour lui : son espèce, son âge, son poids, ses allergies.',
                          textAlign: TextAlign.center,
                          style: TytoText.body(size: 15, color: TytoColors.encre).copyWith(height: 1.55),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: TytoColors.fauve,
                  backgroundColor: TytoColors.nuit2,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pets.length,
                    itemBuilder: (context, i) {
                      final p = _pets[i];
                      final ageTxt = p.ageYears != null ? "${p.ageYears} an${p.ageYears! > 1 ? 's' : ''}" : null;
                      final parts = [
                        p.species,
                        if (p.breed != null) p.breed!,
                        if (ageTxt != null) ageTxt,
                      ];
                      // La carte sur papier ivoire, comme sur le site,
                      // avec l'icône propre à l'espèce de l'animal.
                      return GestureDetector(
                        onLongPress: () => _confirmDelete(p),
                        onTap: () => _openForm(pet: p),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                          decoration: BoxDecoration(
                            color: TytoColors.papier,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: TytoColors.encre.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              SpeciesIcon(species: p.species, size: 28, color: TytoColors.nuit),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name,
                                        style: TytoText.display(size: 17, color: TytoColors.encre)),
                                    const SizedBox(height: 2),
                                    Text(
                                      parts.isEmpty ? p.species : parts.join(' · '),
                                      style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6))
                                          .copyWith(height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.weightKg != null)
                                Text('${p.weightKg} kg',
                                    style: TytoText.ui(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: TytoColors.encre.withOpacity(0.6))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Le formulaire d'ajout / modification d'un compagnon.
class _PetForm extends StatefulWidget {
  final Pet? pet;
  const _PetForm({this.pet});

  @override
  State<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends State<_PetForm> {
  late TextEditingController _name;
  late TextEditingController _breed;
  late TextEditingController _weight;
  String _species = 'chien';
  DateTime? _birthdate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pet?.name ?? '');
    _breed = TextEditingController(text: widget.pet?.breed ?? '');
    _weight = TextEditingController(text: widget.pet?.weightKg?.toString() ?? '');
    _species = widget.pet?.species ?? 'chien';
    _birthdate = widget.pet?.birthdate;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donne au moins un nom à ton compagnon.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await DataService.savePet(
        id: widget.pet?.id,
        name: _name.text,
        species: _species,
        breed: _breed.text,
        birthdate: _birthdate,
        weightKg: double.tryParse(_weight.text.replaceAll(',', '.')),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'enregistrement n'a pas abouti, réessaie.")),
      );
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TytoText.ui(color: TytoColors.brume),
        filled: true,
        fillColor: TytoColors.nuit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: TytoColors.nuit2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TytoColors.brume.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(widget.pet == null ? 'Nouveau compagnon' : 'Modifier', style: TytoText.display(size: 19)),
              const SizedBox(height: 18),
              Text('Nom', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
              const SizedBox(height: 6),
              TextField(controller: _name, style: TytoText.ui(color: TytoColors.lune), decoration: _dec('Max, Plume…')),
              const SizedBox(height: 14),
              Text('Espèce', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _speciesOptions.map((s) {
                  final on = s == _species;
                  return GestureDetector(
                    onTap: () => setState(() => _species = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: on ? TytoColors.fauve.withOpacity(0.18) : TytoColors.nuit,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: on ? TytoColors.fauve : TytoColors.lune.withOpacity(0.12)),
                      ),
                      child: Text(s, style: TytoText.ui(size: 13, color: on ? TytoColors.fauve : TytoColors.brume)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('Race (facultatif)', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
              const SizedBox(height: 6),
              TextField(controller: _breed, style: TytoText.ui(color: TytoColors.lune), decoration: _dec('Berger australien…')),
              const SizedBox(height: 14),
              Text('Poids en kg (facultatif)', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
              const SizedBox(height: 6),
              TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TytoText.ui(color: TytoColors.lune),
                decoration: _dec('24.5'),
              ),
              const SizedBox(height: 14),
              Text('Date de naissance (facultatif)', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthdate ?? DateTime.now(),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _birthdate = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: TytoColors.nuit, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    _birthdate == null
                        ? 'Choisir une date'
                        : '${_birthdate!.day.toString().padLeft(2, '0')}/${_birthdate!.month.toString().padLeft(2, '0')}/${_birthdate!.year}',
                    style: TytoText.ui(color: _birthdate == null ? TytoColors.brume : TytoColors.lune),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.fauve,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit))
                      : Text('Enregistrer', style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
