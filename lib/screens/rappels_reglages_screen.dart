import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/notification_service.dart';
import '../services/reglages_service.dart';
import '../services/theme_service.dart';
import '../widgets/reglages_widgets.dart';
import '../widgets/roulette_heure.dart';

/// Paramètres > Rappels de santé : activer les rappels du carnet, choisir
/// l'heure, combien de jours à l'avance et pour quels types de soins.
class RappelsReglagesScreen extends StatefulWidget {
  const RappelsReglagesScreen({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RappelsReglagesScreen()));
  }

  /// Le résumé affiché dans la ligne de Paramètres : « Activés, à 9 h ».
  static String resume() {
    if (!Reglages.actifs) return 'Désactivés';
    return 'Activés, à ${Reglages.heureTexte}';
  }

  @override
  State<RappelsReglagesScreen> createState() => _RappelsReglagesScreenState();
}

class _RappelsReglagesScreenState extends State<RappelsReglagesScreen> {
  /// L'heure change à chaque cran de la roulette : on attend qu'elle s'arrête
  /// avant de reprogrammer les notifications.
  Timer? _minuteur;

  @override
  void dispose() {
    // Si on quitte l'écran pendant l'attente, le changement est appliqué tout de suite.
    if (_minuteur?.isActive ?? false) {
      _minuteur!.cancel();
      Reglages.enregistrer();
      NotificationService.appliquerReglages();
    }
    super.dispose();
  }

  void _changerHeure(int heure, int minute) {
    Reglages.heure = heure;
    Reglages.minute = minute;
    setState(() {});
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 800), _appliquer);
  }

  /// Enregistre puis reprogramme les notifications avec les nouveaux réglages.
  Future<void> _appliquer() async {
    setState(() {});
    await Reglages.enregistrer();
    try {
      await NotificationService.appliquerReglages();
    } catch (_) {}
  }

  void _basculerJour(int j) {
    final nouveaux = {...Reglages.jours};
    if (nouveaux.contains(j)) {
      // Il en faut au moins un : sinon plus aucun rappel ne partirait.
      if (nouveaux.length == 1) return;
      nouveaux.remove(j);
    } else {
      nouveaux.add(j);
    }
    Reglages.jours = nouveaux;
    _appliquer();
  }

  void _basculerGroupe(String g) {
    final nouveaux = {...Reglages.groupes};
    nouveaux.contains(g) ? nouveaux.remove(g) : nouveaux.add(g);
    Reglages.groupes = nouveaux;
    _appliquer();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.barresSurPapier(),
      child: Scaffold(
        backgroundColor: TytoColors.papier,
        appBar: AppBar(
          backgroundColor: TytoColors.papier,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: TytoColors.encre),
          title: Text('Rappels de santé', style: TytoText.display(size: 20, color: TytoColors.encre)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            const NoteReglage(
              "Tyto te prévient sur ton téléphone avant les vaccins, vermifuges et visites notés dans le carnet de tes animaux, même quand l'appli est fermée.",
            ),
            LigneReglage(
              trace: Reglages.actifs ? TracesReglage.cloche : TracesReglage.clocheBarree,
              titre: 'Rappels du carnet',
              sous: Reglages.actifs ? 'Activés' : 'Désactivés',
              onTap: () {
                Reglages.actifs = !Reglages.actifs;
                _appliquer();
              },
              fin: InterrupteurReglage(
                valeur: Reglages.actifs,
                onChanged: (v) {
                  Reglages.actifs = v;
                  _appliquer();
                },
              ),
            ),
            if (Reglages.actifs) ...[
              LigneReglage(
                trace: TracesReglage.horloge,
                titre: 'Heure du rappel',
                sous: 'Le rappel arrive à ${Reglages.heureTexte}',
                bas: RouletteHeure(
                  heure: Reglages.heure,
                  minute: Reglages.minute,
                  onChanged: _changerHeure,
                ),
              ),
              LigneReglage(
                trace: TracesReglage.cloche,
                titre: 'Être prévenu',
                sous: 'Tu peux en choisir plusieurs',
                bas: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PuceReglage(
                      texte: '7 jours avant',
                      choisie: Reglages.jours.contains(7),
                      onTap: () => _basculerJour(7),
                    ),
                    PuceReglage(
                      texte: 'La veille',
                      choisie: Reglages.jours.contains(1),
                      onTap: () => _basculerJour(1),
                    ),
                    PuceReglage(
                      texte: 'Le jour même',
                      choisie: Reglages.jours.contains(0),
                      onTap: () => _basculerJour(0),
                    ),
                  ],
                ),
              ),
              LigneReglage(
                trace: TracesReglage.signal,
                titre: 'Quels rappels',
                sous: 'Désélectionne ceux dont tu ne veux pas',
                bas: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in groupesRappels.entries)
                      PuceReglage(
                        texte: e.value,
                        choisie: Reglages.groupes.contains(e.key),
                        onTap: () => _basculerGroupe(e.key),
                      ),
                  ],
                ),
              ),
            ],
            const NoteReglage(
              "Les prises de médicaments de « Soins en cours » ont leurs propres heures, réglées dans chaque traitement. "
              'Le son se choisit dans « Sons et vibrations ».',
            ),
          ],
        ),
      ),
    );
  }
}
