import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';

// ⚠️ Ce ne sont PAS des clés secrètes, elles sont faites pour être publiques.
const String supabaseUrl = 'https://wtmlzrtbsxlwyxpnimee.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0bWx6cnRic3hsd3l4cG5pbWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTY3MjUsImV4cCI6MjA5OTI3MjcyNX0.H1BEW0OCQRYhBUga5ExX8ByVoMd_6OqVly6THp6ujNw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const TytoApp());
}

class TytoApp extends StatelessWidget {
  const TytoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tyto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TytoColors.nuit,
        colorScheme: ColorScheme.dark(
          primary: TytoColors.fauve,
          secondary: TytoColors.fauve,
          surface: TytoColors.nuit2,
        ),
        textTheme: TextTheme(
          bodyMedium: TytoText.body(),
          titleLarge: TytoText.display(),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Au démarrage, si personne n'est connecté, on crée une session anonyme
/// en silence (exactement comme le fait le site) — jamais d'écran de
/// connexion forcé. La vraie connexion (email/Google) ne sert qu'à débloquer
/// plus de questions par jour, elle n'est jamais obligatoire pour discuter.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  Future<void> _ensureSession() async {
    if (AuthService.currentSession == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (_) {
        // Si ça échoue (pas de réseau, etc.), on affiche quand même l'app —
        // le chat gérera l'absence de session à ce moment-là.
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: TytoColors.nuit,
        body: Center(child: CircularProgressIndicator(color: TytoColors.fauve)),
      );
    }
    return const ChatScreen();
  }
}

