import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';
import 'widgets/owl_sketch.dart';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: TytoColors.nuit,
          surfaceTintColor: Colors.transparent, // sans ça, Flutter grise légèrement le fond
          elevation: 0,
          iconTheme: IconThemeData(color: TytoColors.fauve), // le bouton menu, la flèche retour...
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent, // idem : sinon le bleu du tiroir est faussé
          elevation: 0,
          scrimColor: Color(0x99080B14),
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
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _ensureSession();
    // Si la session disparaît (déconnexion, expiration…), on en recrée
    // aussitôt une anonyme : l'app doit TOUJOURS avoir une session valide,
    // sinon le chat se retrouve bloqué sur "connexion en cours".
    _sub = AuthService.onAuthStateChange.listen((state) {
      if (state.session != null) {
        // Une vraie connexion a abouti : le marqueur peut être levé.
        AuthService.oauthEnCours = false;
        return;
      }
      // Pas de session — sauf si une connexion Google est en train de se
      // faire : dans ce cas, créer une session anonyme l'annulerait.
      if (!AuthService.oauthEnCours) _ensureSession();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _ensureSession() async {
    // On laisse l'écran d'accueil visible au moins le temps de le lire,
    // même quand la session est déjà prête instantanément.
    final minimum = Future.delayed(const Duration(milliseconds: 2200));
    if (AuthService.currentSession == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (_) {}
    }
    await minimum;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Le même écran d'attente que le site : on dit déjà qui on est,
      // plutôt que de laisser un écran vide.
      return Scaffold(
        backgroundColor: TytoColors.nuit,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OwlSketch(size: 76),
                const SizedBox(height: 14),
                Text('Tyto', style: TytoText.display(size: 30)),
                const SizedBox(height: 8),
                Text(
                  "L'IA du monde animal",
                  textAlign: TextAlign.center,
                  style: TytoText.body(size: 16.5, color: TytoColors.brume)
                      .copyWith(fontStyle: FontStyle.italic, height: 1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  'Gratuit, sans inscription',
                  style: TytoText.ui(size: 12.5, color: TytoColors.brume.withOpacity(0.75)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const ChatScreen();
  }
}
