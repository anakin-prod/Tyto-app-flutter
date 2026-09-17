import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Une entrée d'historique : un jour donné, avec un aperçu du premier
/// message échangé et le nombre total d'échanges ce jour-là.
class HistoryDay {
  final DateTime jour;
  final String apercu;
  final int nombreMessages;
  final int indexPremierMessage; // pour faire défiler jusque-là
  const HistoryDay({
    required this.jour,
    required this.apercu,
    required this.nombreMessages,
    required this.indexPremierMessage,
  });
}

/// Le panneau d'historique — glisse depuis le bas, liste les jours de
/// conversation avec cet animal (ou en général), du plus récent au plus
/// ancien. Toucher un jour fait défiler la conversation jusque-là.
class HistorySheet extends StatelessWidget {
  final List<HistoryDay> jours;
  final String titre;
  final ValueChanged<int> onJumpTo;
  final VoidCallback onEffacer;

  const HistorySheet({
    super.key,
    required this.jours,
    required this.titre,
    required this.onJumpTo,
    required this.onEffacer,
  });

  static Future<void> afficher(
    BuildContext context, {
    required List<HistoryDay> jours,
    required String titre,
    required ValueChanged<int> onJumpTo,
    required VoidCallback onEffacer,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HistorySheet(jours: jours, titre: titre, onJumpTo: onJumpTo, onEffacer: onEffacer),
    );
  }

  String _formatJour(DateTime d) {
    final aujourdhui = DateTime.now();
    final hier = aujourdhui.subtract(const Duration(days: 1));
    bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (memeJour(d, aujourdhui)) return "Aujourd'hui";
    if (memeJour(d, hier)) return 'Hier';
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day} ${mois[d.month - 1]}${d.year != aujourdhui.year ? ' ${d.year}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: TytoColors.nuit2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38, height: 4,
                decoration: BoxDecoration(color: TytoColors.lune.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Historique · $titre', style: TytoText.display(size: 18, color: TytoColors.lune)),
                    ),
                    if (jours.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: TytoColors.brume),
                        tooltip: 'Effacer cet historique',
                        onPressed: () => _confirmerEffacement(context),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: jours.isEmpty
                    ? Center(
                        child: Text(
                          'Rien à revoir pour le moment.',
                          style: TytoText.body(size: 14, color: TytoColors.brume),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: jours.length,
                        itemBuilder: (context, i) {
                          final j = jours[i];
                          return ListTile(
                            onTap: () {
                              Navigator.pop(context);
                              onJumpTo(j.indexPremierMessage);
                            },
                            leading: Container(
                              width: 38, height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: TytoColors.fauve.withOpacity(0.4)),
                              ),
                              child: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: TytoColors.fauve),
                            ),
                            title: Text(_formatJour(j.jour),
                                style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.lune)),
                            subtitle: Text(
                              j.apercu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TytoText.ui(size: 12.5, color: TytoColors.brume),
                            ),
                            trailing: Text('${j.nombreMessages}',
                                style: TytoText.ui(size: 11, color: TytoColors.brume)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmerEffacement(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        title: Text('Effacer cet historique ?', style: TytoText.display(size: 17, color: TytoColors.lune)),
        content: Text(
          'Tous les échanges de cette conversation seront définitivement supprimés.',
          style: TytoText.body(size: 14, color: TytoColors.brume),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ferme la confirmation
              Navigator.pop(context); // ferme le panneau
              onEffacer();
            },
            child: Text('Effacer', style: TytoText.ui(color: TytoColors.urgence, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
