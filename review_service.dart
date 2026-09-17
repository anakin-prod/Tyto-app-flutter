import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Invite à noter l'app une fois que la personne a eu quelques bonnes
/// réponses de Tyto — jamais au tout premier lancement, et jamais deux
/// fois. C'est Google qui affiche sa propre fenêtre native : on ne
/// construit rien nous-mêmes.
class ReviewService {
  static const _cleCompteur = 'reponses_reussies';
  static const _cleDemande = 'avis_deja_demande';
  static const _seuil = 3; // après la 3e bonne réponse

  static Future<void> signalerReponseReussie() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cleDemande) ?? false) return; // déjà demandé une fois

    final compteur = (prefs.getInt(_cleCompteur) ?? 0) + 1;
    await prefs.setInt(_cleCompteur, compteur);

    if (compteur >= _seuil) {
      await prefs.setBool(_cleDemande, true);
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        review.requestReview();
      }
    }
  }
}
