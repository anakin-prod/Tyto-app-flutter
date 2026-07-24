import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/health_event.dart';
import '../models/pet.dart';
import '../services/data_service.dart';

String _typeLabel(String t) {
  switch (t) {
    case 'vaccin':
      return 'Rappel de vaccin';
    case 'vermifuge':
      return 'Vermifuge à renouveler';
    case 'visite':
      return 'Visite à prévoir';
    case 'traitement':
      return 'Traitement à renouveler';
    default:
      return 'Rappel';
  }
}

class TableauScreen extends StatefulWidget {
  const TableauScreen({super.key});

  @override
  State<TableauScreen> createState() => _TableauScreenState();
}

class _TableauScreenState extends State<TableauScreen> {
  List<HealthEvent> _upcoming = [];
  Map<String, Pet> _petsById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        DataService.loadUpcoming(),
        DataService.loadPets(),
      ]);
      final upcoming = results[0] as List<HealthEvent>;
      final pets = results[1] as List<Pet>;
      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
        _petsById = {for (final p in pets) p.id: p};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(title: Text('Tableau des rappels', style: TytoText.display(size: 19))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
          : _upcoming.isEmpty
              ? const TytoEmptyState(
                  icon: Icons.checklist_rounded,
                  message: "Rien à prévoir pour l'instant, tout est à jour.",
                )
              : RefreshIndicator(
                  color: TytoColors.fauve,
                  backgroundColor: TytoColors.nuit2,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _upcoming.length,
                    itemBuilder: (context, i) {
                      final e = _upcoming[i];
                      final daysLeft = e.nextDue!.difference(now).inDays;
                      final soon = daysLeft <= 14;
                      final label = daysLeft < 0
                          ? 'En retard'
                          : daysLeft == 0
                              ? "Aujourd'hui"
                              : 'Dans $daysLeft jour${daysLeft > 1 ? 's' : ''}';
                      final petName = _petsById[e.petId]?.name;
                      final date =
                          '${e.nextDue!.day.toString().padLeft(2, '0')}/${e.nextDue!.month.toString().padLeft(2, '0')}/${e.nextDue!.year}';
                      return TytoTile(
                        icon: Icons.notifications_active_rounded,
                        title: _typeLabel(e.type),
                        subtitle: petName != null ? '$petName · $date' : date,
                        trailing: label,
                        accent: soon ? TytoColors.urgence : TytoColors.fauve,
                      );
                    },
                  ),
                ),
    );
  }
}
