import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../services/platform_service.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../widgets/owl_sketch.dart';
import '../widgets/fenetre_papier.dart';
import '../widgets/compte_fenetre_email.dart';

/// L'écran de connexion, disposé comme celui du site : la chouette, la
/// devise, « Tyto », la promesse, Google, puis le lien par email.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _sending = false;
  bool _linkSent = false;
  bool _modeMotDePasse = false; // replié par défaut
  String? _errorMessage;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    // Le bouton doré reste pâle tant que les champs sont vides, comme sur
    // le site : on redessine à chaque frappe.
    _emailController.addListener(_maj);
    _passwordController.addListener(_maj);
    // Dès que la connexion aboutit (retour de Google ou clic sur le lien
    // reçu par email), on referme cet écran : sans ça, l'utilisateur
    // revenait sur la page de connexion et croyait que ça avait échoué.
    _sub = AuthService.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (AuthService.isSignedIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _emailController.removeListener(_maj);
    _passwordController.removeListener(_maj);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = "Cette adresse email ne semble pas valide.");
      return;
    }
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      await AuthService.sendMagicLink(email);
      setState(() => _linkSent = true);
    } catch (e) {
      setState(() => _errorMessage = "Impossible d'envoyer le lien pour l'instant. Réessaie dans un instant.");
    } finally {
      setState(() => _sending = false);
    }
  }

  /// Connexion directe par mot de passe — sert au compte d'examen Google.
  Future<void> _connexionMotDePasse() async {
    final email = _emailController.text.trim();
    final motDePasse = _passwordController.text;
    if (email.isEmpty || motDePasse.isEmpty) {
      setState(() => _errorMessage = 'Renseigne ton email et ton mot de passe.');
      return;
    }
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      await AuthService.signInWithPassword(email, motDePasse);
      // L'écran se referme tout seul via l'écoute des changements de session.
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Email ou mot de passe incorrect.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = "La connexion Google n'a pas abouti. Réessaie.");
    }
  }

  OutlineInputBorder _bord(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  /// Les champs du site : fond NUIT2, filet ivoire, arrondi de 14.
  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TytoText.ui(size: 15.5, weight: FontWeight.w400, color: const Color(0xFF757575)),
        filled: true,
        fillColor: TytoColors.nuit2,
        isDense: true,
        // padding CSS 13 x 16, plus le bord d'1 px compté à part en CSS
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        border: _bord(TytoColors.lune.withOpacity(0.19), 1),
        enabledBorder: _bord(TytoColors.lune.withOpacity(0.19), 1),
        focusedBorder: _bord(TytoColors.fauve, 2),
      );

  /// Un lien souligné, gris brume (« Se connecter avec un mot de passe »…).
  Widget _lien(String texte, VoidCallback onTap, {double size = 12, Color couleur = TytoColors.brume}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: TytoText.ui(size: size, weight: FontWeight.w400, color: couleur).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: couleur,
        ),
      ),
    );
  }

  Widget _boutonGoogle() {
    return GestureDetector(
      onTap: _signInWithGoogle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CompteLogoGoogle(size: 18),
            const SizedBox(width: 10),
            Text(
              'Continuer avec Google',
              style: TytoText.ui(size: 15, weight: FontWeight.w700, color: const Color(0xFF1F1F1F)),
            ),
          ],
        ),
      ),
    );
  }

  /// « ou » entre deux filets.
  Widget _separateur() {
    final filet = Expanded(child: Container(height: 1, color: TytoColors.lune.withOpacity(0.133)));
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Row(
        children: [
          filet,
          const SizedBox(width: 10),
          Text('ou', style: TytoText.ui(size: 11.5, weight: FontWeight.w400, color: TytoColors.brume)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: TytoColors.lune.withOpacity(0.133))),
        ],
      ),
    );
  }

  /// Le message « C'est envoyé ! » sur le papier ivoire.
  Widget _carteEnvoye() {
    final base = TytoText.body(size: 16, color: TytoColors.encre)
        .copyWith(height: 1.55, leadingDistribution: TextLeadingDistribution.even);
    final gras = GoogleFonts.newsreader(fontSize: 16, fontWeight: FontWeight.w700, color: TytoColors.encre)
        .copyWith(height: 1.55, leadingDistribution: TextLeadingDistribution.even);
    // width: 100 % comme sur le site.
    return SizedBox(
      width: double.infinity,
      child: FenetrePapier(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("C'est envoyé !", style: gras),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Un email vient de partir vers '),
                  TextSpan(text: _emailController.text.trim(), style: gras),
                  const TextSpan(text: '. Ouvre-le et clique sur le lien de connexion.'),
                ],
              ),
              style: base,
            ),
            const SizedBox(height: 12),
            _lien(
              'Adresse erronée ou rien reçu ? Réessayer',
              () => setState(() => _linkSent = false),
              size: 12.5,
              couleur: TytoColors.encre.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaire() {
    final vide =
        _emailController.text.trim().isEmpty || _sending || (_modeMotDePasse && _passwordController.text.isEmpty);
    final libelle = _sending
        ? (_modeMotDePasse ? 'Connexion…' : 'Envoi en cours…')
        : (_modeMotDePasse ? 'Se connecter' : 'Recevoir mon lien de connexion');
    final retour = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: TytoText.ui(size: 15.5, weight: FontWeight.w400, color: TytoColors.lune),
          cursorColor: TytoColors.lune,
          decoration: _dec('ton@email.fr'),
          onSubmitted: (_) {
            if (!vide) (_modeMotDePasse ? _connexionMotDePasse : _sendMagicLink)();
          },
        ),
        // Le mot de passe se place juste sous l'email : les deux
        // champs d'un même formulaire doivent rester ensemble.
        if (_modeMotDePasse) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            style: TytoText.ui(size: 15.5, weight: FontWeight.w400, color: TytoColors.lune),
            cursorColor: TytoColors.lune,
            decoration: _dec('Mot de passe'),
            onSubmitted: (_) {
              if (!vide) _connexionMotDePasse();
            },
          ),
        ],
        const SizedBox(height: 10),
        // Le bouton doré du site (goldBtn), pâle tant qu'il manque un champ.
        BoutonDore(
          texte: libelle,
          onTap: _modeMotDePasse ? _connexionMotDePasse : _sendMagicLink,
          actif: !vide,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.fauve),
          ),
        ],
        if (!_modeMotDePasse) ...[
          const SizedBox(height: 14),
          Text(
            'Pas de mot de passe à retenir : un simple lien par email.\nGratuit, sans carte bancaire.',
            textAlign: TextAlign.center,
            style: TytoText.ui(size: 12, weight: FontWeight.w400, color: TytoColors.brume)
                .copyWith(height: 1.5, leadingDistribution: TextLeadingDistribution.even),
          ),
        ],
        // Sur le site, les deux liens du bas sont des boutons en ligne :
        // ils partagent la même ligne, sous la marge du paragraphe (12 px)
        // ou du message d'erreur (13 px) qui les précède.
        SizedBox(
          height: (_modeMotDePasse ? (_errorMessage != null ? 13.0 : 0.0) : 12.0) + (retour ? 15.0 : 12.0),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            // Le lien reste discret : il ne sert qu'au compte d'examen de
            // Google, pas aux vrais utilisateurs.
            _lien(
              _modeMotDePasse ? 'Revenir au lien de connexion' : 'Se connecter avec un mot de passe',
              () => setState(() {
                _modeMotDePasse = !_modeMotDePasse;
                _errorMessage = null;
              }),
            ),
            // L'écran s'ouvre par-dessus Tyto : on peut y revenir sans se connecter.
            if (retour)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _lien('← Retour à Tyto', () => Navigator.of(context).maybePop(), size: 13),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.of(context).size.width;
    // clamp(42px, 12vw, 54px), comme le titre du site.
    final tailleTitre = (largeur * 0.12).clamp(42.0, 54.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Sans ça, l'ouverture du clavier faisait déborder la colonne
      // (barre jaune et noire) : le contenu peut maintenant glisser.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) => SingleChildScrollView(
            child: ConstrainedBox(
              // La colonne reste centrée verticalement tant qu'il y a la
              // place, et se met à défiler seulement quand il en manque.
              constraints: BoxConstraints(minHeight: contraintes.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const OwlSketch(size: 120),
                        const SizedBox(height: 20),
                        Text(
                          'LE COMPAGNON DE VOS COMPAGNONS',
                          textAlign: TextAlign.center,
                          style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.fauve)
                              .copyWith(letterSpacing: 2.86),
                        ),
                        const SizedBox(height: 6),
                        Text('Tyto', style: TytoText.display(size: tailleTitre)),
                        const SizedBox(height: 10),
                        Text(
                          "L'IA qui connaît votre animal : conseils personnalisés, carnet de santé, rappels de vaccins et analyse photo.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.newsreader(
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            color: TytoColors.brume,
                            height: 1.5,
                          ).copyWith(leadingDistribution: TextLeadingDistribution.even),
                        ),
                        const SizedBox(height: 26),
                        // Sur iOS, Apple exigerait « Se connecter avec Apple » dès qu'on
                        // propose Google : on ne propose donc que le lien par email.
                        if (!PlatformInfo.estIOS) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _boutonGoogle(),
                          ),
                          _separateur(),
                        ],
                        if (_linkSent) _carteEnvoye() else _formulaire(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
