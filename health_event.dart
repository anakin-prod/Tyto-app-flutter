class HealthEvent {
  final String id;
  final String petId;
  final String type;
  final DateTime eventDate;
  final DateTime? nextDue;
  final double? valueNum;
  final String? notes;

  HealthEvent({
    required this.id,
    required this.petId,
    required this.type,
    required this.eventDate,
    this.nextDue,
    this.valueNum,
    this.notes,
  });
}
