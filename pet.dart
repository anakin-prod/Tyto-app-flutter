class Pet {
  final String id;
  final String name;
  final String species;
  final String? breed;
  final String? sex;
  final DateTime? birthdate;
  final double? weightKg;
  final bool sterilized;
  final String? allergies;
  final String? conditions; // antécédents, traitements en cours

  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.sex,
    this.birthdate,
    this.weightKg,
    this.sterilized = false,
    this.allergies,
    this.conditions,
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
