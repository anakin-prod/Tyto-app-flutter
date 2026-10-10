import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/account_service.dart';
import '../services/user_service.dart';
import 'fenetre_papier.dart';

/// La confirmation de suppression de compte. Une suppression est
/// définitive : il faut taper le mot SUPPRIMER pour la débloquer, comme
/// sur le site.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  /// Renvoie true si le compte a été supprimé.
  static Future<bool?> afficher(BuildContext context) {
    // Comme sur le site : toucher le voile ferme la fenêtre, sauf pendant
    // la suppression (voir PopScope plus bas).
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xCC0A0E18),
      builder: (_) => const DeleteAccountDialog(),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _envoi = false;
  String? _erreur;

  bool get _confirme => _controller.text.trim().toUpperCase() == 'SUPPRIMER';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _supprimer() async {
    if (!_confirme || _envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final ok = await AccountService.supprimerCompte();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _envoi = false;
        _erreur = "La suppression n'a pas abouti. Rien n'a été supprimé : "
            'tu peux réessayer, ou nous écrire à contact.surnia@gmail.com.';
      });
    }
  }

  static final _styleAnnuler = TytoText.ui(size: 14, weight: FontWeight.w400);
  static final _styleSupprimer = TytoText.ui(size: 14, weight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final libelleSupprimer = _envoi ? 'Suppression…' : 'Supprimer définitivement';
    final labelStyle =
        TytoText.ui(size: 11, weight: FontWeight.w700, color: encreA(0x99)).copyWith(letterSpacing: 0.88);
    return PopScope(
      canPop: !_envoi,
      child: CadreDialogue(
        marge: 16,
        largeurMax: 440,
        child: FenetrePapier(
          lisere: TytoColors.urgence,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Supprimer mon compte', style: TytoText.display(size: 20, color: TytoColors.encre)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Cette action est '),
                    TextSpan(
                      text: 'définitive',
                      style:
                          GoogleFonts.newsreader(fontSize: 14.5, fontWeight: FontWeight.w700, color: TytoColors.encre),
                    ),
                    const TextSpan(
                      text: '. Seront supprimés : tes compagnons, leur carnet de santé, tes '
                          'conversations, tes bilans et ton équipe. Ton abonnement éventuel '
                          'sera annulé.',
                    ),
                  ],
                ),
                style: TytoText.body(size: 14.5, color: TytoColors.encre)
                    .copyWith(height: 1.6, leadingDistribution: TextLeadingDistribution.even),
              ),
              const SizedBox(height: 10),
              Text(
                'Tes factures éventuelles restent conservées chez notre prestataire de '
                'paiement, pour des raisons comptables et légales.',
                style: TytoText.body(size: 12.5, color: encreA(0x99))
                    .copyWith(height: 1.5, leadingDistribution: TextLeadingDistribution.even),
              ),
              // Apple ne permet pas d'annuler un abonnement à la place de
              // l'utilisateur : on le lui dit clairement.
              if (UserService.planSource == 'apple') ...[
                const SizedBox(height: 10),
                Text(
                  "Ton abonnement Apple n'est pas annulé par la suppression du compte : "
                  'résilie-le dans Réglages > ton nom > Abonnements, sinon il continuera à être facturé.',
                  style: TytoText.ui(size: 12.5, weight: FontWeight.w600, color: TytoColors.urgence)
                      .copyWith(height: 1.45, leadingDistribution: TextLeadingDistribution.even),
                ),
              ],
              const SizedBox(height: 14),
              Text('POUR CONFIRMER, TAPE SUPPRIMER', style: labelStyle),
              const SizedBox(height: 4),
              TextField(
                controller: _controller,
                enabled: !_envoi,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                style: TytoText.ui(size: 14.5, weight: FontWeight.w400, color: TytoColors.encre),
                onChanged: (_) => setState(() {}),
                decoration: decorationChampPapier(
                  indication: 'SUPPRIMER',
                  taille: 14.5,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 10),
                Text(
                  _erreur!,
                  style: TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.urgence)
                      .copyWith(height: 1.5, leadingDistribution: TextLeadingDistribution.even),
                ),
              ],
              const SizedBox(height: 16),
              // flex « 1 1 auto » du site : chaque bouton part de sa largeur
              // naturelle et reçoit la moitié de la place qui reste ; s'ils
              // ne tiennent pas côte à côte, ils passent l'un sous l'autre.
              _RangeeBoutons(
                libelleGauche: 'Annuler',
                styleGauche: _styleAnnuler,
                gauche: BoutonPilule(
                  texte: 'Annuler',
                  onTap: () => Navigator.pop(context, false),
                  actif: !_envoi,
                  opaciteInactive: 1,
                  bord: const Color(0x33EDE7D6),
                  encre: TytoColors.brume,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  taille: 14,
                  gras: false,
                ),
                libelleDroite: libelleSupprimer,
                styleDroite: _styleSupprimer,
                droite: BoutonPilule(
                  texte: libelleSupprimer,
                  onTap: _supprimer,
                  actif: _confirme && !_envoi,
                  opaciteInactive: 0.4,
                  fond: TytoColors.urgence,
                  encre: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  taille: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La rangée des deux boutons du site (display: flex; gap: 10px;
/// flex-wrap: wrap; flex: 1 1 auto sur chaque bouton).
class _RangeeBoutons extends StatelessWidget {
  final Widget gauche;
  final Widget droite;
  final String libelleGauche;
  final String libelleDroite;
  final TextStyle styleGauche;
  final TextStyle styleDroite;

  const _RangeeBoutons({
    required this.gauche,
    required this.droite,
    required this.libelleGauche,
    required this.libelleDroite,
    required this.styleGauche,
    required this.styleDroite,
  });

  static const _ecart = 10.0;

  double _largeurTexte(BuildContext context, String texte, TextStyle style) {
    final mesure = TextPainter(
      text: TextSpan(text: texte, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final largeur = mesure.width;
    mesure.dispose();
    return largeur;
  }

  @override
  Widget build(BuildContext context) {
    // Largeurs naturelles : texte + padding 14 de chaque côté (+ le bord
    // d'1 px du bouton Annuler).
    final naturelleGauche = _largeurTexte(context, libelleGauche, styleGauche) + 28 + 2;
    final naturelleDroite = _largeurTexte(context, libelleDroite, styleDroite) + 28;
    return LayoutBuilder(
      builder: (context, contraintes) {
        final reste = contraintes.maxWidth - naturelleGauche - naturelleDroite - _ecart;
        if (reste < 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [gauche, const SizedBox(height: _ecart), droite],
          );
        }
        // align-items: stretch : les deux boutons prennent la hauteur du
        // plus haut (Annuler, à cause de son bord).
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: naturelleGauche + reste / 2, child: gauche),
              const SizedBox(width: _ecart),
              Expanded(child: droite),
            ],
          ),
        );
      },
    );
  }
}
