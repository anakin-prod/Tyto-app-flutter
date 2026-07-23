import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/health_event.dart';

final _sampleEvents = [
  HealthEvent(id: '1', petId: '1', type: 'vaccin', eventDate: DateTime(2026, 6, 2), nextDue: DateTime(2027, 6, 2), notes: 'Rappel annuel (CHPPI)'),
  HealthEvent(id: '2', petId: '1', type: 'poids', eventDate: DateTime(2026, 7, 10), valueNum: 24.5),
  HealthEvent(id: '3', petId: '1', type: 'vermifuge', eventDate: DateTime(2026, 5, 15), nextDue: DateTime(2026, 8, 15)),
];

IconData _typeIcon(String t) {
  switch (t) {
    case 'vaccin': return Icons.vaccines_rounded;
    case 'poids': return Icons.monitor_weight_rounded;
    case 'vermifuge': return Icons.medication_rounded;
    case 'visite': return Icons.local_hospital_rounded;
    default: return Icons.event_note_rounded;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'vaccin': return 'Vaccin';
    case 'poids': return 'Pesée';
    case 'vermifuge': return 'Vermifuge';
    case 'visite': return 'Visite vétérinaire';
    default: return 'Soin';
  }
}

String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class CarnetScreen extends StatelessWidget {
  const CarnetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = List<HealthEvent>.from(_sampleEvents)
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        title: Text('Carnet de santé', style: TytoText.display(size: 19)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: TytoColors.fauve),
            tooltip: 'Ajouter un événement',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("L'ajout d'un événement arrive à une prochaine étape.")),
              );
            },
          ),
        ],
      ),
      body: events.isEmpty
          ? const TytoEmptyState(icon: Icons.menu_book_rounded, message: "Aucun événement enregistré pour l'instant.")
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final e = events[i];
                final valueTxt = e.valueNum != null ? '${e.valueNum} kg' : null;
                final subtitleParts = [
                  _formatDate(e.eventDate),
                  if (e.nextDue != null) 'Prochain rappel : ${_formatDate(e.nextDue!)}',
                  if (e.notes != null) e.notes!,
                ];
                return TytoTile(
                  icon: _typeIcon(e.type),
                  title: _typeLabel(e.type),
                  subtitle: subtitleParts.join(' · '),
                  trailing: valueTxt,
                );
              },
            ),
    );
  }
}
