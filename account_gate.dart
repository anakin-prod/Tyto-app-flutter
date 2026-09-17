import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../screens/login_screen.dart';
import 'tyto_icons.dart';

/// Le même message que sur le site quand un visiteur non connecté essaie
/// d'accéder aux compagnons, au carnet ou aux rappels : ces fonctions
/// demandent un compte, un simple email suffit.
class AccountGate extends StatelessWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F1E7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TytoIcon.owl(size: 32, color: TytoColors.nuit),
              const SizedBox(height: 8),
              Text(
                'Crée ton compte gratuit',
                textAlign: TextAlign.center,
                style: TytoText.display(size: 19, color: const Color(0xFF2A2118)),
              ),
              const SizedBox(height: 6),
              Text(
                "Un simple email suffit pour enregistrer tes compagnons et débloquer le carnet de santé, "
                "les rappels de vaccins et 15 questions par jour. Tes questions d'essai sont conservées.",
                textAlign: TextAlign.center,
                style: TytoText.body(size: 15, color: const Color(0xFF2A2118)).copyWith(height: 1.55),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.mail_outline_rounded, size: 15, color: TytoColors.nuit),
                label: Text(
                  'Créer mon compte',
                  style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TytoColors.fauve,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
