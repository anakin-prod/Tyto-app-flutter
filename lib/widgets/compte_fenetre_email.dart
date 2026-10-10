import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/platform_service.dart';
import '../screens/login_screen.dart';
import 'fenetre_papier.dart';
import 'site_icons.dart';

// ============================================================
// La fenêtre « Crée ton compte gratuit » du site (emailPrompt) :
// ouverte par « Créer mon compte » dans le menu d'un visiteur et
// dans la carte des rubriques réservées aux comptes.
// ============================================================

/// Le « G » de Google exactement comme sur le site (grille 18 x 18).
const _logoGoogleSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">'
    '<path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84c-.21 1.13-.85 2.09-1.8 2.73v2.27h2.92c1.71-1.57 2.68-3.88 2.68-6.64z"/>'
    '<path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.27c-.81.54-1.85.86-3.04.86-2.34 0-4.32-1.58-5.03-3.71H.96v2.34C2.44 15.98 5.48 18 9 18z"/>'
    '<path fill="#FBBC05" d="M3.97 10.7A5.4 5.4 0 0 1 3.68 9c0-.59.1-1.17.29-1.7V4.96H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.04l3.01-2.34z"/>'
    '<path fill="#EA4335" d="M9 3.58c1.32 0 2.51.45 3.44 1.35l2.58-2.58C13.46.89 11.43 0 9 0 5.48 0 2.44 2.02.96 4.96l3.01 2.34C4.68 5.16 6.66 3.58 9 3.58z"/>'
    '</svg>';

/// Le logo Google des boutons « Continuer avec Google » du site.
class CompteLogoGoogle extends StatelessWidget {
  final double size;
  const CompteLogoGoogle({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_logoGoogleSvg, width: size, height: size);
  }
}

/// La même adresse de retour que les liens de connexion de l'app.
const _redirection = 'app.tytoai.twa://login-callback';

class FenetreCreerCompte extends StatefulWidget {
  const FenetreCreerCompte({super.key});

  /// Ouvre la fenêtre par-dessus l'écran courant : voile
  /// rgba(10,14,24,0.72), toucher le voile la referme, comme sur le site.
  static Future<void> afficher(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xB80A0E18),
      builder: (_) => const FenetreCreerCompte(),
    );
  }

  @override
  State<FenetreCreerCompte> createState() => _FenetreCreerCompteState();
}

class _FenetreCreerCompteState extends State<FenetreCreerCompte> {
  final _email = TextEditingController();
  bool _envoi = false;
  bool _envoye = false;
  bool _fermee = false;
  String? _erreur;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    // Le bouton doré reste pâle tant que le champ est vide.
    _email.addListener(_maj);
    // Dès qu'un vrai compte est ouvert (retour de Google, lien confirmé),
    // la fenêtre n'a plus lieu d'être.
    _sub = AuthService.onAuthStateChange.listen((_) {
      if (!mounted || _fermee || !AuthService.isSignedIn) return;
      _fermer();
    });
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _email.removeListener(_maj);
    _email.dispose();
    super.dispose();
  }

  void _fermer() {
    if (_fermee) return;
    _fermee = true;
    Navigator.of(context).pop();
  }

  /// Comme le site : la session de visiteur devient un vrai compte (même
  /// identifiant), ce qui garde les conversations déjà commencées. Un
  /// lien de confirmation part par email.
  Future<void> _creer() async {
    final valeur = _email.text.trim();
    if (valeur.isEmpty || _envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    String? message;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: valeur),
        emailRedirectTo: _redirection,
      );
    } on AuthException catch (e) {
      message = e.message.isEmpty ? 'erreur inconnue' : e.message;
    } catch (_) {
      message = 'erreur inconnue';
    }
    if (!mounted) return;
    setState(() {
      _envoi = false;
      if (message == null) {
        _envoye = true;
      } else {
        final indice = RegExp('already|registered|exists', caseSensitive: false).hasMatch(message)
            ? ' → Cet email a déjà un compte : clique sur « Déjà inscrit ? Se connecter ».'
            : RegExp('rate limit', caseSensitive: false).hasMatch(message)
                ? " → Limite d'envois d'emails atteinte : attends environ 1 heure."
                : '';
        _erreur = 'Impossible — $message$indice';
      }
    });
  }

  Future<void> _google() async {
    setState(() => _erreur = null);
    try {
      await AuthService.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) setState(() => _erreur = 'Connexion Google impossible — ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _erreur = 'Connexion Google impossible — réessaie.');
    }
  }

  void _seConnecter() {
    final navigateur = Navigator.of(context);
    _fermee = true;
    navigateur.pop();
    navigateur.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return CadreDialogue(
      marge: 20,
      largeurMax: 400,
      child: FenetrePapier(
        child: _envoye ? _vueEnvoyee() : _formulaire(),
      ),
    );
  }

  TextStyle get _titre => TytoText.display(size: 19, color: TytoColors.encre);

  Widget _formulaire() {
    final vide = _email.text.trim().isEmpty || _envoi;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Crée ton compte gratuit', style: _titre),
        const SizedBox(height: 6),
        Text(
          'Débloque 15 questions par jour, les compagnons, le carnet et les rappels.',
          style: TytoText.body(size: 15, color: TytoColors.encre)
              .copyWith(height: 1.5, leadingDistribution: TextLeadingDistribution.even),
        ),
        const SizedBox(height: 14),
        // Sur iOS, Google n'est pas proposé (Apple exigerait alors
        // « Se connecter avec Apple »), comme sur l'écran de connexion.
        if (!PlatformInfo.estIOS) ...[
          _boutonGoogle(),
          const SizedBox(height: 12),
          _separateur(),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          style: TytoText.ui(size: 15, weight: FontWeight.w400, color: TytoColors.encre),
          cursorColor: TytoColors.encre,
          onSubmitted: (_) => _creer(),
          decoration: decorationChampPapier(
            indication: 'ton@email.fr',
            taille: 15,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          ),
        ),
        const SizedBox(height: 10),
        BoutonDore(
          texte: _envoi ? 'Envoi…' : 'Créer mon compte gratuit',
          onTap: _creer,
          actif: !vide,
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 8),
          Text(
            _erreur!,
            style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: const Color(0xFFAA3333))
                .copyWith(height: 1.4, leadingDistribution: TextLeadingDistribution.even),
          ),
        ],
        const SizedBox(height: 12),
        LienDiscret(texte: 'Déjà inscrit ? Se connecter', onTap: _seConnecter),
      ],
    );
  }

  /// Le bouton blanc du site : bord encre à 13 %, rayon 10, padding
  /// 11 x 13, Karla 14,5 gras, logo de 17 px à 9 px du texte.
  Widget _boutonGoogle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _google,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: encreA(0x22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CompteLogoGoogle(size: 17),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                'Continuer avec Google',
                style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: const Color(0xFF1F1F1F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// « ou » entre deux filets encre à 10 %.
  Widget _separateur() {
    Widget filet() => Expanded(child: Container(height: 1, color: encreA(0x1a)));
    return Row(
      children: [
        filet(),
        const SizedBox(width: 8),
        Text('ou', style: TytoText.ui(size: 11, weight: FontWeight.w400, color: encreA(0x77))),
        const SizedBox(width: 8),
        filet(),
      ],
    );
  }

  Widget _vueEnvoyee() {
    final base = TytoText.body(size: 15.5, color: TytoColors.encre)
        .copyWith(height: 1.55, leadingDistribution: TextLeadingDistribution.even);
    final gras = GoogleFonts.newsreader(fontSize: 15.5, fontWeight: FontWeight.w700, color: TytoColors.encre)
        .copyWith(height: 1.55, leadingDistribution: TextLeadingDistribution.even);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SiteIcon('IconMail', size: 18, color: TytoColors.encre),
            const SizedBox(width: 8),
            Expanded(child: Text('Vérifie tes emails !', style: _titre)),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Un lien de confirmation vient de partir vers '),
              TextSpan(text: _email.text.trim(), style: gras),
              const TextSpan(
                text: '. Clique-le pour activer ton compte — tout ce que tu as fait ici sera conservé.',
              ),
            ],
          ),
          style: base,
        ),
        const SizedBox(height: 12),
        LienDiscret(texte: 'Fermer', onTap: _fermer),
      ],
    );
  }
}
