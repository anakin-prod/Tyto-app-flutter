import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../services/theme_service.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/signalement_service.dart';
import '../widgets/fenetre_papier.dart';

/// Le formulaire « Signaler un problème », en ivoire comme Paramètres.
class SignalerScreen extends StatefulWidget {
  const SignalerScreen({super.key});

  /// Renvoie true si le message est parti.
  static Future<bool?> ouvrir(BuildContext context) {
    return Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SignalerScreen()));
  }

  @override
  State<SignalerScreen> createState() => _SignalerScreenState();
}

class _SignalerScreenState extends State<SignalerScreen> {
  final _message = TextEditingController();
  late final TextEditingController _contact = TextEditingController(text: AuthService.email ?? '');
  bool _envoi = false;
  bool _indisponible = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final texte = _message.text.trim();
    if (texte.length < 5) {
      setState(() => _erreur = 'Décris le problème en quelques mots.');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final r = await SignalementService.envoyer(message: texte, contact: _contact.text.trim());
    if (!mounted) return;
    switch (r) {
      case ResultatSignalement.envoye:
        Navigator.of(context).pop(true);
      case ResultatSignalement.indisponible:
        setState(() {
          _envoi = false;
          _indisponible = true;
          _erreur = "L'envoi direct n'est pas disponible pour le moment. Tu peux l'envoyer depuis ta messagerie.";
        });
      case ResultatSignalement.echec:
        setState(() {
          _envoi = false;
          _erreur = "L'envoi n'a pas abouti. Vérifie ta connexion et réessaie.";
        });
    }
  }

  Widget _etiquette(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TytoText.ui(size: 13, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.7))),
      );

  @override
  Widget build(BuildContext context) {
    final vide = _message.text.trim().isEmpty || _envoi;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.barresSurPapier(),
      child: Scaffold(
        backgroundColor: TytoColors.papier,
        appBar: AppBar(
          backgroundColor: TytoColors.papier,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: TytoColors.encre),
          title: Text('Signaler un problème', style: TytoText.display(size: 20, color: TytoColors.encre)),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                "Un bug, une erreur, quelque chose qui ne marche pas comme prévu ? Raconte-nous ce qui s'est passé, nous lisons chaque message.",
                style: TytoText.body(size: 15, color: TytoColors.encre).copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              _etiquette('Que s\'est-il passé ?'),
              TextField(
                controller: _message,
                minLines: 6,
                maxLines: 10,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                style: TytoText.ui(size: 15, weight: FontWeight.w400, color: TytoColors.encre),
                cursorColor: TytoColors.encre,
                decoration: decorationChampPapier(
                  indication: 'Décris le problème, et ce que tu faisais juste avant…',
                  taille: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 14),
              _etiquette('Ton e-mail, pour te répondre (facultatif)'),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TytoText.ui(size: 15, weight: FontWeight.w400, color: TytoColors.encre),
                cursorColor: TytoColors.encre,
                decoration: decorationChampPapier(
                  indication: 'ton@email.fr',
                  taille: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                ),
              ),
              const SizedBox(height: 18),
              BoutonDore(
                texte: _envoi ? 'Envoi…' : 'Envoyer',
                onTap: _envoyer,
                actif: !vide,
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 10),
                Text(_erreur!,
                    style: TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.surPapier(const Color(0xFFAA3333))).copyWith(height: 1.4)),
              ],
              if (_indisponible) ...[
                const SizedBox(height: 10),
                LienDiscret(
                  texte: 'Écrire depuis ma messagerie',
                  onTap: () => SignalementService.ouvrirMessagerie(_message.text.trim()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
