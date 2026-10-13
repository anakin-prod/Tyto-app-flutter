import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';

/// Le mode nuit (par défaut) ou jour : le même dessin inversé, fond ivoire
/// et traits bleus. Le choix est mémorisé sur l'appareil.
class ThemeService {
  static const _cle = 'mode_jour';

  /// À appeler une fois au démarrage, avant d'afficher quoi que ce soit.
  static Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      TytoColors.jour = prefs.getBool(_cle) ?? false;
    } catch (_) {
      TytoColors.jour = false;
    }
    appliquerBarres();
  }

  /// Change de mode : mémorise le choix puis redessine tout l'écran, y
  /// compris les parties qui ne se redessinent pas d'elles-mêmes.
  static Future<void> definir(bool jour) async {
    TytoColors.jour = jour;
    appliquerBarres();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cle, jour);
    } catch (_) {}
    await WidgetsBinding.instance.reassembleApplication();
  }

  /// Les barres du système (heure, navigation) suivent le fond de l'appli.
  static void appliquerBarres() {
    SystemChrome.setSystemUIOverlayStyle(barresApp());
  }

  static SystemUiOverlayStyle barresApp() {
    if (TytoColors.jour) {
      return const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFF4EDDC),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF4EDDC),
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
