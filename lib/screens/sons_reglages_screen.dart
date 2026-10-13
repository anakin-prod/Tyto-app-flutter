import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/notification_service.dart';
import '../services/reglages_service.dart';
import '../services/soins_service.dart';
import '../services/son_service.dart';
import '../services/theme_service.dart';
import '../widgets/reglages_widgets.dart';

/// Paramètres > Sons et vibrations : le son des rappels et des soins, les
/// vibrations, et un bouton pour essayer.
class SonsReglagesScreen extends StatefulWidget {
  const SonsReglagesScreen({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SonsReglagesScreen()));
  }

  /// Le résumé affiché dans la ligne de Paramètres : « Hou-hou, vibrations ».
  static String resume() {
    final son = Reglages.sonChoisi.libelle;
    return Reglages.vibrations ? '$son, avec vibrations' : '$son, sans vibration';
  }

  @override
  State<SonsReglagesScreen> createState() => _SonsReglagesScreenState();
}

class _SonsReglagesScreenState extends State<SonsReglagesScreen> {
  Future<void> _appliquer() async {
    setState(() {});
    await Reglages.enregistrer();
    try {
      await NotificationService.appliquerReglages();
      // Les prises de traitements prennent aussi le nouveau son.
      await SoinsService.reprogrammerNotifications();
    } catch (_) {}
  }

  Future<void> _choisir(String id) async {
    if (Reglages.son == id) return;
    Reglages.son = id;
    Reglages.toucher();
    await _appliquer();
  }

  Future<void> _basculerSonMessage(bool v) async {
    Reglages.sonMessage = v;
    setState(() {});
    await Reglages.enregistrer();
    // On l'entend tout de suite en l'activant.
    if (v) await SonService.essayer();
  }

  Future<void> _basculerVibrations(bool v) async {
    Reglages.vibrations = v;
    if (v) HapticFeedback.mediumImpact();
    await _appliquer();
  }

  Future<void> _tester() async {
    try {
      await NotificationService.tester();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Notification d'essai envoyée. Si rien n'apparaît, vérifie que les notifications de Tyto sont autorisées dans les réglages du téléphone.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iphone = Platform.isIOS;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.barresSurPapier(),
      child: Scaffold(
        backgroundColor: TytoColors.papier,
        appBar: AppBar(
          backgroundColor: TytoColors.papier,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: TytoColors.encre),
          title: Text('Sons et vibrations', style: TytoText.display(size: 20, color: TytoColors.encre)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const TitreSection("À l'envoi d'un message"),
            LigneReglage(
              trace: TracesReglage.hautParleur,
              titre: 'Hou-hou de la chouette',
              sous: "Un petit « hou » à chaque message envoyé. Il suit le volume des notifications et se tait en mode silencieux.",
              onTap: () => _basculerSonMessage(!Reglages.sonMessage),
              fin: InterrupteurReglage(valeur: Reglages.sonMessage, onChanged: _basculerSonMessage),
            ),
            const TitreSection('Rappels et soins'),
            const NoteReglage('Le son joué par les rappels du carnet et par les prises de traitements.'),
            for (final s in sonsRappel)
              LigneReglage(
                titre: s.libelle,
                sous: s.description,
                onTap: () => _choisir(s.id),
                fin: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Reglages.son == s.id ? TytoColors.fauve : Colors.transparent,
                    border: Border.all(
                      color: Reglages.son == s.id ? TytoColors.fauve : TytoColors.encre.withOpacity(0.3),
                    ),
                  ),
                  child: Reglages.son == s.id ? iconeReglage(TracesReglage.coche, TytoColors.nuit, taille: 15) : null,
                ),
              ),
            const SizedBox(height: 4),
            LigneReglage(
              trace: TracesReglage.vibration,
              titre: 'Vibrations',
              sous: iphone
                  ? "Petits retours tactiles dans l'appli. Pour les notifications, voir les Réglages de l'iPhone."
                  : "Notifications et petits retours tactiles dans l'appli",
              onTap: () => _basculerVibrations(!Reglages.vibrations),
              fin: InterrupteurReglage(valeur: Reglages.vibrations, onChanged: _basculerVibrations),
            ),
            const SizedBox(height: 4),
            BoutonDoreReglage(texte: 'Tester le son', onTap: _tester),
            const SizedBox(height: 10),
            NoteReglage(
              'Le test envoie une vraie notification, avec le son choisi. '
              "Si tu n'entends rien, vérifie que le téléphone n'est pas en mode silencieux. "
              'Les conseils de saison gardent le son habituel du téléphone.',
            ),
          ],
        ),
      ),
    );
  }
}
