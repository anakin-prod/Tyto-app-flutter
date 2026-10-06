import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/account_service.dart';

/// La confirmation de suppression de compte. Une suppression est
/// définitive : il faut taper le mot SUPPRIMER pour la débloquer, comme
/// sur le site.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  /// Renvoie true si le compte a été supprimé.
  static Future<bool?> afficher(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: const BoxDecoration(
            color: TytoColors.papier,
            borderRadius: BorderRadius.all(Radius.circular(14)),
            border: Border(top: BorderSide(color: TytoColors.urgence, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supprimer mon compte', style: TytoText.display(size: 20, color: TytoColors.encre)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TytoText.body(size: 14.5, color: TytoColors.encre).copyWith(height: 1.55),
                  children: const [
                    TextSpan(text: 'Cette action est '),
                    TextSpan(text: 'définitive', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                      text: '. Seront supprimés : tes compagnons, leur carnet de santé, tes '
                          'conversations, tes bilans et ton équipe. Ton abonnement éventuel '
                          'sera annulé.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tes factures éventuelles restent conservées chez notre prestataire de '
                'paiement, pour des raisons comptables et légales.',
                style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6)).copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              Text(
                'POUR CONFIRMER, TAPE SUPPRIMER',
                style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6))
                    .copyWith(letterSpacing: 1.1),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                enabled: !_envoi,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                style: TytoText.ui(color: TytoColors.encre),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'SUPPRIMER',
                  hintStyle: TytoText.ui(color: TytoColors.encre.withOpacity(0.35)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2)),
                  ),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 10),
                Text(_erreur!, style: TytoText.ui(size: 13, color: TytoColors.urgence).copyWith(height: 1.45)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _envoi ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: TytoColors.encre.withOpacity(0.25)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text('Annuler', style: TytoText.ui(size: 14, color: TytoColors.encre)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_confirme && !_envoi) ? _supprimer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TytoColors.urgence,
                        disabledBackgroundColor: TytoColors.urgence.withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: _envoi
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Supprimer',
                              style: TytoText.ui(size: 14, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
