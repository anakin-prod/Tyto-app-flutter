import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';

/// Les trois façons de choisir l'apparence : toujours la nuit, toujours le
/// jour, ou « automatique » (l'appli suit le mode clair ou sombre du téléphone).
enum ModeApparence { nuit, jour, auto }

/// La taille du texte choisie dans Paramètres.
enum TailleTexte {
  normale(1.0, 'Normale'),
  grande(1.15, 'Grande'),
  tresGrande(1.3, 'Très grande');

  final double facteur;
  final String libelle;
  const TailleTexte(this.facteur, this.libelle);
}

/// L'apparence de l'appli : nuit (par défaut), jour (le même dessin inversé,
/// fond ivoire et traits bleus) ou automatique, et la taille du texte. Les
/// choix sont mémorisés sur l'appareil.
class ThemeService {
  /// L'ancien réglage (un simple « mode jour oui/non »), relu une seule fois
  /// pour ne pas perdre le choix de ceux qui l'avaient déjà fait.
  static const _cleAncienne = 'mode_jour';
  static const _cleMode = 'mode_apparence';
  static const _cleTaille = 'taille_texte';

  static ModeApparence mode = ModeApparence.nuit;

  /// La taille du texte : l'écran se redessine tout seul quand elle change.
  static final ValueNotifier<TailleTexte> taille = ValueNotifier(TailleTexte.normale);

  static final _ObservateurLuminosite _observateur = _ObservateurLuminosite();
  static bool _observe = false;

  /// À appeler une fois au démarrage, avant d'afficher quoi que ce soit.
  static Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cleMode);
      if (brut != null) {
        mode = ModeApparence.values.firstWhere(
          (m) => m.name == brut,
          orElse: () => ModeApparence.nuit,
        );
      } else {
        mode = (prefs.getBool(_cleAncienne) ?? false) ? ModeApparence.jour : ModeApparence.nuit;
      }
      final t = prefs.getString(_cleTaille);
      taille.value = TailleTexte.values.firstWhere(
        (x) => x.name == t,
        orElse: () => TailleTexte.normale,
      );
    } catch (_) {
      mode = ModeApparence.nuit;
    }
    TytoColors.jour = _estJour();
    appliquerBarres();
    if (!_observe) {
      WidgetsBinding.instance.addObserver(_observateur);
      _observe = true;
    }
  }

  /// Vrai si l'appli doit être en mode jour en ce moment.
  static bool _estJour() {
    switch (mode) {
      case ModeApparence.jour:
        return true;
      case ModeApparence.nuit:
        return false;
      case ModeApparence.auto:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light;
    }
  }

  /// Change d'apparence : mémorise le choix puis redessine tout l'écran, y
  /// compris les parties qui ne se redessinent pas d'elles-mêmes.
  static Future<void> definirMode(ModeApparence nouveau) async {
    mode = nouveau;
    TytoColors.jour = _estJour();
    appliquerBarres();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleMode, nouveau.name);
    } catch (_) {}
    await WidgetsBinding.instance.reassembleApplication();
  }

  /// Le téléphone vient de passer du clair au sombre (ou l'inverse) : en
  /// mode automatique, l'appli suit.
  static Future<void> _systemeChange() async {
    if (mode != ModeApparence.auto) return;
    final jour = _estJour();
    if (jour == TytoColors.jour) return;
    TytoColors.jour = jour;
    appliquerBarres();
    await WidgetsBinding.instance.reassembleApplication();
  }

  static Future<void> definirTaille(TailleTexte nouvelle) async {
    taille.value = nouvelle;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleTaille, nouvelle.name);
    } catch (_) {}
  }

  /// Le grossissement du texte en cours (1 = normal), jamais en dessous de 1.
  /// Sert aux mises en page qui comptent des pixels (l'en-tête qui passe sur
  /// deux lignes quand tout ne tient plus).
  static double echelleTexte(BuildContext context) {
    final k = MediaQuery.textScalerOf(context).scale(100) / 100;
    return k < 1 ? 1.0 : k;
  }

  /// Les barres du système (heure, navigation) suivent le fond de l'appli.
  static void appliquerBarres() {
    SystemChrome.setSystemUIOverlayStyle(barresApp());
  }

  static SystemUiOverlayStyle barresApp() {
    if (TytoColors.jour) {
      return const SystemUiOverlayStyle(
        statusBarColor: TytoColors.ivoireJour,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: TytoColors.ivoireJour,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    }
    return const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1A2336),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF151C2C),
      systemNavigationBarIconBrightness: Brightness.light,
    );
  }

  /// La page de lancement est toujours bleu nuit, même en mode jour : ses
  /// barres du système le sont donc aussi.
  static SystemUiOverlayStyle barresLancement() => const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF151C2C),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF151C2C),
        systemNavigationBarIconBrightness: Brightness.light,
      );

  /// Pour un écran qui est « sur papier » : ivoire en mode nuit (icônes
  /// foncées), bleu en mode jour (icônes claires).
  static SystemUiOverlayStyle barresSurPapier() => TytoColors.jour
      ? const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        )
      : const SystemUiOverlayStyle(
          statusBarColor: Color(0x00000000),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        );

  /// Pour un écran « sur le fond » : bleu en mode nuit, ivoire en mode jour.
  static SystemUiOverlayStyle barresSurFond() => TytoColors.jour
      ? barresSurPapier().copyWith(statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light)
      : barresSurPapier().copyWith(statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark);
}

/// Prévient quand le téléphone change de mode clair / sombre.
class _ObservateurLuminosite with WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() {
    ThemeService._systemeChange();
  }
}
