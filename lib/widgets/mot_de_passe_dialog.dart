import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import 'fenetre_papier.dart';

/// La fenêtre « Nouveau mot de passe ». Elle sert dans deux cas : quand la
/// personne revient du lien « Mot de passe oublié » reçu par e-mail, et
/// depuis Paramètres > Changer mon mot de passe.
class MotDePasseDialog extends StatefulWidget {
  final String titre;
  final String intro;
  const MotDePasseDialog({super.key, required this.titre, required this.intro});

  /// Renvoie true si le mot de passe a bien été enregistré.
  static Future<bool?> afficher(
    BuildContext context, {
    String titre = 'Changer mon mot de passe',
    String intro = 'Choisis un nouveau mot de passe, de 8 caractères au minimum.',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xCC0A0E18),
      builder: (_) => MotDePasseDialog(titre: titre, intro: intro),
    );
  }

  @override
  State<MotDePasseDialog> createState() => _MotDePasseDialogState();
}

class _MotDePasseDialogState extends State<MotDePasseDialog> {
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _nouveau.addListener(_maj);
    _confirmation.addListener(_maj);
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (_envoi) return;
    final mdp = _nouveau.text;
    if (mdp.length < 8) {
      setState(() => _erreur = 'Le mot de passe doit faire au moins 8 caractères.');
      return;
    }
    if (mdp != _confirmation.text) {
      setState(() => _erreur = 'Les deux mots de passe ne sont pas identiques.');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    String? message;
    try {
      await AuthService.changerMotDePasse(mdp);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('different') || m.contains('same')) {
        message = "Choisis un mot de passe différent de l'ancien.";
      } else if (m.contains('weak') || m.contains('short') || m.contains('characters')) {
        message = 'Ce mot de passe est trop faible. Ajoute des lettres, des chiffres ou plus de caractères.';
      } else {
        message = "Le changement n'a pas abouti. Réessaie dans un instant.";
      }
    } catch (_) {
      message = "Le changement n'a pas abouti. Vérifie ta connexion et réessaie.";
    }
    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _envoi = false;
      _erreur = message;
    });
  }

  Widget _champ(TextEditingController c, String indication) => TextField(
        controller: c,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        style: TytoText.ui(size: 15, weight: FontWeight.w400, color: TytoColors.encre),
        cursorColor: TytoColors.encre,
        onSubmitted: (_) => _enregistrer(),
        decoration: decorationChampPapier(
          indication: indication,
          taille: 15,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vide = _nouveau.text.isEmpty || _confirmation.text.isEmpty || _envoi;
    return CadreDialogue(
      marge: 20,
      largeurMax: 400,
      child: FenetrePapier(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titre, style: TytoText.display(size: 19, color: TytoColors.encre)),
            const SizedBox(height: 6),
            Text(
              widget.intro,
              style: TytoText.body(size: 15, color: TytoColors.encre)
                  .copyWith(height: 1.5, leadingDistribution: TextLeadingDistribution.even),
            ),
            const SizedBox(height: 14),
            _champ(_nouveau, 'Nouveau mot de passe'),
            const SizedBox(height: 10),
            _champ(_confirmation, 'Répète le mot de passe'),
            const SizedBox(height: 12),
            BoutonDore(
              texte: _envoi ? 'Enregistrement…' : 'Enregistrer',
              onTap: _enregistrer,
              actif: !vide,
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(
                _erreur!,
                style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.surPapier(const Color(0xFFAA3333)))
                    .copyWith(height: 1.4, leadingDistribution: TextLeadingDistribution.even),
              ),
            ],
            const SizedBox(height: 10),
            LienDiscret(texte: 'Annuler', onTap: () => Navigator.of(context).pop(false)),
          ],
        ),
      ),
    );
  }
}
