import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/colors.dart';
import 'theme/background.dart';
import 'theme/typography.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

// Attention : ce ne sont PAS des clés secrètes, elles sont faites pour être publiques.
const String supabaseUrl = 'https://wtmlzrtbsxlwyxpnimee.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0bWx6cnRic3hsd3l4cG5pbWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTY3MjUsImV4cCI6MjA5OTI3MjcyNX0.H1BEW0OCQRYhBUga5ExX8ByVoMd_6OqVly6THp6ujNw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Les barres du système (heure, navigation) prennent le bleu nuit du site
  // au lieu du noir par défaut, avec des icônes claires.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF1A2336),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF151C2C),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await NotificationService.initialiser();
  runApp(const TytoApp());
}

/// Sur téléphone, Flutter n'affiche aucune barre de défilement par défaut.
/// Tyto en montre une, fine et dorée comme celle du menu du site, qui
/// apparaît pendant qu'on fait défiler (verticalement seulement).
class TytoScrollBehavior extends MaterialScrollBehavior {
  const TytoScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (details.direction == AxisDirection.left || details.direction == AxisDirection.right) {
      return child;
    }
    return Scrollbar(controller: details.controller, child: child);
  }
}

class TytoApp extends StatelessWidget {
  const TytoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tyto',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const TytoScrollBehavior(),
      // Le dégradé du site est posé une fois pour toutes derrière chaque
      // écran, plutôt que répété dans chacun d'eux.
      builder: (context, child) => TytoBackground(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.dark(
          primary: TytoColors.fauve,
          secondary: TytoColors.fauve,
          surface: TytoColors.nuit2,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(TytoColors.fauve.withOpacity(0.55)),
          trackColor: const WidgetStatePropertyAll(Colors.transparent),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(10),
          crossAxisMargin: 2,
          thumbVisibility: const WidgetStatePropertyAll(false),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
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
    if (AuthService.currentSession == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (_) {}
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Volontairement vide : l'écran de lancement d'Android (logo + phrase)
      // est encore affiché à cet instant. Y remettre un logo ferait croire
      // à un second démarrage.
      return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox.shrink());
    }
    return const ChatScreen();
  }
}
