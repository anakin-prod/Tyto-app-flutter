import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../theme/background.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../widgets/tyto_icons.dart';
import '../widgets/owl_sketch.dart';

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

  @override
  void dispose() {
    _sub?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const OwlSketch(size: 52),
              const SizedBox(height: 14),
              Text('Tyto', style: TytoText.display(size: 30)),
              const SizedBox(height: 6),
              Text("L'IA du monde animal", style: TytoText.ui(size: 13, color: TytoColors.brume)),
              const SizedBox(height: 40),
              if (_linkSent) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TytoColors.nuit2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TytoColors.fauve.withOpacity(0.4)),
                  ),
                  child: Text(
                    "Lien envoyé ! Ouvre l'email reçu sur cet appareil pour te connecter.",
                    textAlign: TextAlign.center,
                    style: TytoText.body(size: 15),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TytoText.ui(color: TytoColors.lune),
                  decoration: InputDecoration(
                    hintText: 'ton@email.com',
                    hintStyle: TytoText.ui(color: TytoColors.brume),
                    filled: true,
                    fillColor: TytoColors.nuit2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendMagicLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TytoColors.fauve,
                      foregroundColor: TytoColors.nuit,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _sending
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Recevoir un lien de connexion', style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: Divider(color: TytoColors.brume.withOpacity(0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('ou', style: TytoText.ui(size: 12, color: TytoColors.brume)),
                  ),
                  Expanded(child: Divider(color: TytoColors.brume.withOpacity(0.3))),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const GoogleLogo(size: 18),
                    label: Text('Continuer avec Google', style: TytoText.ui(color: TytoColors.lune)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TytoColors.lune.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                // Connexion par mot de passe : repliée par défaut, elle
                // ne sert qu'au compte d'examen de Google (les
                // examinateurs ne peuvent pas recevoir de lien magique).
                const SizedBox(height: 14),
                if (!_modeMotDePasse)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _modeMotDePasse = true),
                      child: Text('Se connecter avec un mot de passe',
                          style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                    ),
                  )
                else ...[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TytoText.ui(color: TytoColors.lune),
                    decoration: InputDecoration(
                      hintText: 'Mot de passe',
                      hintStyle: TytoText.ui(color: TytoColors.brume),
                      filled: true,
                      fillColor: TytoColors.nuit2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _connexionMotDePasse(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _connexionMotDePasse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TytoColors.fauve,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Se connecter',
                          style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit)),
                    ),
                  ),
                ],
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: TytoText.ui(size: 13, color: TytoColors.urgence), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
