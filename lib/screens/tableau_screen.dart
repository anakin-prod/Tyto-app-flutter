import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/health_event.dart';

final _sampleUpcoming = [
  HealthEvent(id: '1', petId: '1', type: 'vermifuge', eventDate: DateTime(2026, 5, 15), nextDue: DateTime(2026, 8, 15)),
  HealthEvent(id: '2', petId: '1', type: 'vaccin', eventDate: DateTime(2026, 6, 2), nextDue: DateTime(2027, 6, 2)),
];

class TableauScreen extends StatelessWidget {
  const TableauScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = _sampleUpcoming.where((e) => e.nextDue != null).toList()
      ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        title: Text('Tableau des rappels', style: TytoText.display(size: 19)),
      ),
      body: upcoming.isEmpty
          ? const TytoEmptyState(icon: Icons.checklist_rounded, message: "Rien à prévoir pour l'instant, tout est à jour.")
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: upcoming.length,
              itemBuilder: (context, i) {
                final e = upcoming[i];
                final daysLeft = e.nextDue!.difference(now).inDays;
                final soon = daysLeft <= 14;
                final label = daysLeft < 0
                    ? 'En retard'
                    : daysLeft == 0
                        ? "Aujourd'hui"
                        : 'Dans $daysLeft jour${daysLeft > 1 ? 's' : ''}';
                return TytoTile(
                  icon: Icons.notifications_active_rounded,
                  title: e.type == 'vermifuge' ? 'Vermifuge à renouveler' : 'Rappel vaccin',
                  subtitle: '${e.nextDue!.day.toString().padLeft(2, '0')}/${e.nextDue!.month.toString().padLeft(2, '0')}/${e.nextDue!.year}',
                  trailing: label,
                  accent: soon ? TytoColors.urgence : TytoColors.fauve,
                );
              },
            ),
    );
  }
}
