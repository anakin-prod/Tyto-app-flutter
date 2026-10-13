import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../services/theme_service.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/icone_service.dart';
import '../services/notification_service.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/mot_de_passe_dialog.dart';
import '../widgets/reglages_widgets.dart';
import 'a_propos_screen.dart';
import 'rappels_reglages_screen.dart';
import 'signaler_screen.dart';
import 'sons_reglages_screen.dart';

/// La page Paramètres : en ivoire (et non en bleu nuit) pour rompre un peu
/// avec le bleu des autres écrans. De haut en bas : le compte connecté, puis
/// trois groupes : Apparence (nuit, jour ou automatique, taille du texte,
/// icône sur iPhone), Notifications (rappels, sons, conseils de saison) et
/// Compte et aide (blog, mot de passe, signalement, À propos, suppression).
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParametresScreen()));
  }

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  bool _saisonActive = true;
  String _icone = 'nuit';

  @override
  void initState() {
    super.initState();
    AlertesSaison.actives().then((v) {
      if (mounted) setState(() => _saisonActive = v);
    });
    if (IconeService.disponible) {
      IconeService.actuelle().then((v) {
        if (mounted) setState(() => _icone = v);
      });
    }
  }

  Future<void> _basculerSaison(bool nouveau) async {
    setState(() => _saisonActive = nouveau);
    await AlertesSaison.definir(nouveau);
    await NotificationService.reprogrammerSaisonDepuisMemoire();
  }

  Future<void> _changerMode(ModeApparence mode) async {
    await ThemeService.definirMode(mode);
    if (mounted) setState(() {});
  }

  Future<void> _changerTaille(TailleTexte taille) async {
    await ThemeService.definirTaille(taille);
    if (mounted) setState(() {});
  }

  Future<void> _changerIcone(String choix) async {
    if (choix == _icone) return;
    final ok = await IconeService.definir(choix);
    if (!mounted) return;
    if (ok) {
      setState(() => _icone = choix);
    } else {
      _message("L'icône n'a pas pu être changée.");
    }
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String get _descriptionMode {
    switch (ThemeService.mode) {
      case ModeApparence.nuit:
        return 'Fond bleu nuit, traits ivoire';
      case ModeApparence.jour:
        return 'Fond ivoire, traits bleus';
      case ModeApparence.auto:
        return TytoColors.jour
            ? 'Suit le téléphone : il est en mode clair'
            : 'Suit le téléphone : il est en mode sombre';
    }
  }

  /// Une vignette d'icône à toucher (iPhone).
  Widget _vignetteIcone(String choix, String nom, String image) {
    final choisie = _icone == choix;
    return GestureDetector(
      onTap: () => _changerIcone(choix),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: choisie ? TytoColors.fauve : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(image, width: 64, height: 64, filterQuality: FilterQuality.high),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nom,
            style: TytoText.ui(
              size: 13,
              weight: FontWeight.w700,
              color: choisie ? TytoColors.encre : TytoColors.encre.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connecte = AuthService.isSignedIn;
    final email = AuthService.email;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeService.barresSurPapier(),
      child: Scaffold(
        backgroundColor: TytoColors.papier,
        appBar: AppBar(
          backgroundColor: TytoColors.papier,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: TytoColors.encre),
          title: Text('Paramètres', style: TytoText.display(size: 20, color: TytoColors.encre)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Le compte connecté, tout en haut.
            LigneReglage(
              trace: TracesReglage.compte,
              titre: connecte && email != null && email.isNotEmpty ? email : 'Visiteur',
              sous: connecte ? 'Compte connecté' : "Pas encore de compte : crée-le depuis le menu",
            ),

            const TitreSection('Apparence'),
            LigneReglage(
              trace: ThemeService.mode == ModeApparence.auto
                  ? TracesReglage.contraste
                  : (TytoColors.jour ? TracesReglage.soleil : TracesReglage.lune),
              titre: 'Apparence',
              sous: _descriptionMode,
              bas: ChoixSegmente<ModeApparence>(
                options: const [
                  (ModeApparence.nuit, 'Nuit'),
                  (ModeApparence.jour, 'Jour'),
                  (ModeApparence.auto, 'Auto'),
                ],
                valeur: ThemeService.mode,
                onChanged: _changerMode,
              ),
            ),
            LigneReglage(
              trace: TracesReglage.texte,
              titre: 'Taille du texte',
              sous: 'Pour lire plus confortablement',
              bas: ChoixSegmente<TailleTexte>(
                options: [for (final t in TailleTexte.values) (t, t.libelle)],
                valeur: ThemeService.taille.value,
                onChanged: _changerTaille,
              ),
            ),
            if (IconeService.disponible)
              LigneReglage(
                trace: TracesReglage.telephone,
                titre: "Icône de l'appli",
                sous: "Celle qui s'affiche sur l'écran d'accueil",
                bas: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _vignetteIcone('nuit', 'Nuit', 'assets/images/icone_nuit.png'),
                    const SizedBox(width: 28),
                    _vignetteIcone('ivoire', 'Ivoire', 'assets/images/icone_ivoire.png'),
                  ],
                ),
              ),

            const TitreSection('Notifications'),
            LigneReglage(
              trace: TracesReglage.cloche,
              titre: 'Rappels de santé',
              sous: RappelsReglagesScreen.resume(),
              onTap: () async {
                await RappelsReglagesScreen.ouvrir(context);
                if (mounted) setState(() {});
              },
            ),
            LigneReglage(
              trace: TracesReglage.hautParleur,
              titre: 'Sons et vibrations',
              sous: SonsReglagesScreen.resume(),
              onTap: () async {
                await SonsReglagesScreen.ouvrir(context);
                if (mounted) setState(() {});
              },
            ),
            LigneReglage(
              trace: _saisonActive ? TracesReglage.cloche : TracesReglage.clocheBarree,
              titre: 'Conseils de saison',
              sous: _saisonActive ? 'Notifications activées' : 'Notifications désactivées',
              onTap: () => _basculerSaison(!_saisonActive),
              fin: InterrupteurReglage(valeur: _saisonActive, onChanged: _basculerSaison),
            ),

            const TitreSection('Compte et aide'),
            LigneReglage(
              trace: TracesReglage.blog,
              titre: 'Blog et guides',
              sous: 'Tous les articles',
              onTap: () => launchUrl(Uri.parse('https://tytoai.app/blog'), mode: LaunchMode.externalApplication),
            ),
            if (connecte)
              LigneReglage(
                trace: TracesReglage.cle,
                titre: 'Changer mon mot de passe',
                sous: 'Choisir un nouveau mot de passe',
                onTap: () async {
                  final ok = await MotDePasseDialog.afficher(context);
                  if (ok == true && mounted) _message('Mot de passe mis à jour.');
                },
              ),
            LigneReglage(
              trace: TracesReglage.signal,
              titre: 'Signaler un problème',
              sous: "Un bug ou une erreur dans l'application",
              onTap: () async {
                final ok = await SignalerScreen.ouvrir(context);
                if (ok == true && mounted) _message('Merci, ton message a bien été envoyé.');
              },
            ),
            // Tout en bas : « À propos ».
            LigneReglage(
              trace: TracesReglage.info,
              titre: 'À propos',
              sous: "Confidentialité et conditions d'utilisation",
              onTap: () => AProposScreen.ouvrir(context),
            ),
            if (connecte)
              LigneReglage(
                trace: TracesReglage.corbeille,
                titre: 'Supprimer mon compte',
                sous: 'Effacer définitivement mes données',
                couleur: TytoColors.surPapier(const Color(0xFFAA3333)),
                onTap: () => DeleteAccountDialog.afficher(context),
              ),
          ],
        ),
      ),
    );
  }
}
