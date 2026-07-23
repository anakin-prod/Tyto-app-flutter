class Pet {
  final String id;
  final String name;
  final String species; // chien | chat | lapin | oiseau | autre
  final String? breed;
  final String? sex;
  final DateTime? birthdate;
  final double? weightKg;

  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.sex,
    this.birthdate,
    this.weightKg,
  });

  int? get ageYears {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate!.year;
    if (now.month < birthdate!.month || (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age;
  }
}
