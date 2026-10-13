import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/colors.dart';
import 'theme/background.dart';
import 'theme/typography.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'widgets/mot_de_passe_dialog.dart';

// Attention : ce ne sont PAS des clés secrètes, elles sont faites pour être publiques.
const String supabaseUrl = 'https://wtmlzrtbsxlwyxpnimee.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0bWx6cnRic3hsd3l4cG5pbWVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTY3MjUsImV4cCI6MjA5OTI3MjcyNX0.H1BEW0OCQRYhBUga5ExX8ByVoMd_6OqVly6THp6ujNw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Les barres du système (heure, navigation) prennent le bleu nuit du site
  // au lieu du noir par défaut, avec des icônes claires.
  // Le mode nuit ou jour choisi dans Paramètres (et les barres du système).
  await ThemeService.charger();
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
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    if (details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right) {
      return child;
    }
    // Sur iPhone, la barre Material devient une barre iOS grise, qui ignore
    // le thème : on dessine donc la nôtre, la même partout, comme celle du
    // site (5 px, or à 40 %, bouts arrondis).
    return RawScrollbar(
      controller: details.controller,
      thumbColor: TytoColors.fauve.withOpacity(0.4),
      thickness: 5,
      radius: const Radius.circular(10),
      crossAxisMargin: 2,
      interactive: true,
      thumbVisibility: false,
      child: child,
    );
  }
}

/// Une transition de page classique, mais l'écran qui arrive est posé sur un
/// fond opaque (le même dégradé que le site), pour masquer l'écran précédent.
class _TransitionOpaque extends PageTransitionsBuilder {
  final PageTransitionsBuilder base;
  const _TransitionOpaque(this.base);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return base.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      TytoBackground(child: child),
    );
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
      builder: (context, child) =>
          TytoBackground(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        // Les écrans sont transparents (le fond est posé derrière) : sans ça,
        // l'ancien écran restait visible pendant la transition. Chaque
        // nouvel écran arrive donc avec son propre fond, opaque.
        pageTransitionsTheme: PageTransitionsTheme(builders: {
          TargetPlatform.iOS:
              _TransitionOpaque(CupertinoPageTransitionsBuilder()),
          TargetPlatform.android:
              _TransitionOpaque(FadeUpwardsPageTransitionsBuilder()),
        }),
        colorScheme: (TytoColors.jour ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
          primary: TytoColors.fauve,
          secondary: TytoColors.fauve,
          surface: TytoColors.nuit2,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor:
              WidgetStatePropertyAll(TytoColors.fauve.withOpacity(0.55)),
          trackColor: const WidgetStatePropertyAll(Colors.transparent),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(10),
          crossAxisMargin: 2,
          thumbVisibility: const WidgetStatePropertyAll(false),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor:
              Colors.transparent, // sans ça, Flutter grise légèrement le fond
          elevation: 0,
          iconTheme: IconThemeData(
              color: TytoColors.fauve), // le bouton menu, la flèche retour...
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor:
              Colors.transparent, // idem : sinon le bleu du tiroir est faussé
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
  bool _dureeMiniEcoulee = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _dureeMiniEcoulee = true);
    });
    _ensureSession();
    // Si la session disparaît (déconnexion, expiration…), on en recrée
    // aussitôt une anonyme : l'app doit TOUJOURS avoir une session valide,
    // sinon le chat se retrouve bloqué sur "connexion en cours".
    _sub = AuthService.onAuthStateChange.listen((state) {
      // Retour du lien « Mot de passe oublié » : on propose de choisir un
      // nouveau mot de passe.
      if (state.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final ok = await MotDePasseDialog.afficher(
            context,
            titre: 'Nouveau mot de passe',
            intro: 'Choisis ton nouveau mot de passe, de 8 caractères au minimum.',
          );
          if (ok == true && mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(content: Text('Mot de passe mis à jour.')),
            );
          }
        });
        return;
      }
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
    // Page de lancement (logo + phrase), identique sur Android et iOS :
    // elle reste au moins 1,5 s, puis s'efface en fondu.
    final fini = _ready && _dureeMiniEcoulee;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: fini
          ? const ChatScreen(key: ValueKey('chat'))
          : const _PageLancement(key: ValueKey('lancement')),
    );
  }
}


/// La page de lancement : le même visuel que l'écran natif d'Android
/// (même image, même taille, centrée sur le fond de la marque), pour que
/// le passage de l'un à l'autre ne se voie pas — et pour que iOS ait la
/// même page qu'Android.
class _PageLancement extends StatelessWidget {
  const _PageLancement({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF151C2C),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/splash_logo.png',
        width: 168.75,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
