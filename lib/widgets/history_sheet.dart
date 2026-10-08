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
      barrierColor: const Color(0xBF0A0E18), // rgba(10,14,24,0.75), comme le site
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
        // Même feuille ivoire que sur le site : papier, encre, bord fin.
        return Container(
          decoration: BoxDecoration(
            color: TytoColors.papier,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
            boxShadow: const [
              BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: TytoColors.encre.withOpacity(0.08))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Historique · $titre',
                          style: TytoText.display(size: 18, color: TytoColors.encre)),
                    ),
                    if (jours.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: TytoColors.encre.withOpacity(0.47)),
                        tooltip: 'Effacer cet historique',
                        onPressed: () => _confirmerEffacement(context),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 22, color: TytoColors.encre.withOpacity(0.6)),
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: jours.isEmpty
                    ? Center(
                        child: Text(
                          'Rien à revoir pour le moment.',
                          style: TytoText.body(size: 14.5, color: TytoColors.encre.withOpacity(0.53)),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
                        itemCount: jours.length,
                        itemBuilder: (context, i) {
                          final j = jours[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(context);
                              onJumpTo(j.indexPremierMessage);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: TytoColors.fauve.withOpacity(0.4)),
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: TytoColors.fauve),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_formatJour(j.jour),
                                            style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.encre)),
                                        const SizedBox(height: 2),
                                        Text(
                                          j.apercu,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.53)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('${j.nombreMessages}',
                                      style: TytoText.ui(size: 11, color: TytoColors.encre.withOpacity(0.47))),
                                ],
                              ),
                            ),
                            ),
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
        backgroundColor: TytoColors.papier,
        surfaceTintColor: Colors.transparent,
        title: Text('Effacer cet historique ?', style: TytoText.display(size: 17, color: TytoColors.encre)),
        content: Text(
          'Tous les échanges de cette conversation seront définitivement supprimés.',
          style: TytoText.body(size: 14.5, color: TytoColors.encre.withOpacity(0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.encre.withOpacity(0.6))),
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
