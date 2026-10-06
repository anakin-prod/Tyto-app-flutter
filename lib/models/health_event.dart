class HealthEvent {
  final String id;
  final String petId;
  final String type;
  final DateTime eventDate;
  final DateTime? nextDue;
  final double? valueNum;
  final String? notes;
  final String? label; // l'intitulé saisi : « Vaccin rage », « Amoxicilline — 250 mg »…

  HealthEvent({
    required this.id,
    required this.petId,
    required this.type,
    required this.eventDate,
    this.nextDue,
    this.valueNum,
    this.notes,
    this.label,
  });
}

/// Les libellés par type d'événement : les mêmes que EVENT_TYPES sur le site.
/// « visite » est l'ancien nom de « veto », encore présent dans des carnets.
String libelleDuType(String type) {
  switch (type) {
    case 'vaccin':
      return 'Vaccin';
    case 'vermifuge':
      return 'Vermifuge';
    case 'antiparasitaire':
      return 'Antiparasitaire';
    case 'veto':
    case 'visite':
      return 'Visite véto';
    case 'poids':
      return 'Pesée';
    case 'observation':
      return 'Observation';
    case 'traitement':
      return 'Traitement';
    default:
      return 'Autre';
  }
}

extension LibelleEvenement on HealthEvent {
  /// L'intitulé saisi quand il existe, sinon celui du type.
  String get libelle =>
      (label?.trim().isNotEmpty ?? false) ? label!.trim() : libelleDuType(type);
}
