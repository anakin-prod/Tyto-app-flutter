import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  bool _sending = false;
  bool _linkSent = false;
  String? _errorMessage;

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
      backgroundColor: TytoColors.nuit,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.circle_outlined, color: TytoColors.fauve, size: 56),
              const SizedBox(height: 14),
              Text('Tyto', style: TytoText.display(size: 30)),
              const SizedBox(height: 6),
              Text(
                "L'IA du monde animal",
                style: TytoText.ui(size: 13, color: TytoColors.brume),
              ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
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
                    icon: const Icon(Icons.g_mobiledata, size: 22, color: TytoColors.lune),
                    label: Text('Continuer avec Google', style: TytoText.ui(color: TytoColors.lune)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TytoColors.lune.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
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
