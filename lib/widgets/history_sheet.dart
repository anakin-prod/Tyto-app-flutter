import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

/// Le panneau d'historique (HistoryPanel du site) — une feuille ivoire qui
/// monte du bas, à la hauteur de son contenu (75 % de l'écran au plus), et
/// liste les jours de conversation du plus récent au plus ancien. Toucher
/// un jour fait défiler la conversation jusque-là.
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
      elevation: 0,
      barrierColor: const Color(0xBF0A0E18), // rgba(10,14,24,0.75), comme le site
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => HistorySheet(jours: jours, titre: titre, onJumpTo: onJumpTo, onEffacer: onEffacer),
    );
  }

  // Les deux dessins du panneau du site : la corbeille et la bulle.
  static const _corbeille = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="#000" stroke-width="1.6"><path d="M3 6h18" />'
      '<path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />'
      '<path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" /></svg>';
  static const _bulle = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="#000" stroke-width="1.8"><path d="M21 11.6a8.2 8.2 0 0 1-8.3 8.2 8.7 8.7 0 0 1-3.7-.8l-5 1.6 '
      '1.7-4.8a8 8 0 0 1-1-3.9 8.2 8.2 0 0 1 8.3-8.2 8.2 8.2 0 0 1 8 7.9Z" /></svg>';

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
    final media = MediaQuery.of(context);
    final basSecurite = media.padding.bottom;
    // Le compteur et la croix sont des boutons sans police précisée sur le
    // site : ils s'affichent dans la police du système.
    final policeSysteme = Theme.of(context).typography.white.bodyMedium?.fontFamily;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
      child: Container(
        clipBehavior: Clip.antiAlias,
        // Même feuille ivoire que sur le site : papier, encre, bord fin.
        decoration: BoxDecoration(
          color: TytoColors.papier,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
          boxShadow: const [
            BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
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
                    Tooltip(
                      message: 'Effacer cet historique',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _confirmerEffacement(context),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.string(
                            _corbeille,
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(TytoColors.encre.withOpacity(0.47), BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: 'Fermer',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '×',
                          style: TextStyle(
                            fontFamily: policeSysteme,
                            fontSize: 22,
                            color: TytoColors.encre.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: jours.isEmpty
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(34, 30, 34, 42 + basSecurite),
                      child: Text(
                        'Rien à revoir pour le moment.',
                        textAlign: TextAlign.center,
                        style: TytoText.body(size: 16, color: TytoColors.encre.withOpacity(0.53)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(10, 6, 10, 18 + basSecurite),
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
                                    child: SvgPicture.string(
                                      _bulle,
                                      width: 15,
                                      height: 15,
                                      colorFilter: const ColorFilter.mode(TytoColors.fauve, BlendMode.srcIn),
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_formatJour(j.jour),
                                            style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.encre)),
                                        Text(
                                          j.apercu.replaceAll('\n', ' '),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TytoText.ui(
                                              size: 12.5,
                                              weight: FontWeight.w400,
                                              color: TytoColors.encre.withOpacity(0.53)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Text(
                                    '${j.nombreMessages}',
                                    style: TextStyle(
                                      fontFamily: policeSysteme,
                                      fontSize: 11,
                                      color: TytoColors.encre.withOpacity(0.47),
                                    ),
                                  ),
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
      ),
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
