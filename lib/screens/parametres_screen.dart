import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../services/theme_service.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/mot_de_passe_dialog.dart';
import 'a_propos_screen.dart';
import 'signaler_screen.dart';

/// La page Paramètres : en ivoire (et non en bleu nuit) pour rompre un peu
/// avec le bleu des autres écrans. De haut en bas : le compte connecté, les
/// conseils de saison, le blog, le changement de mot de passe, le signalement
/// d'un problème, la suppression du compte et « À propos ».
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParametresScreen()));
  }

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

const _traceBlog = '<path d="M4.5 4.5h10a2 2 0 0 1 2 2v13h-10a2 2 0 0 1-2-2v-11a2 2 0 0 1 2-2z" />'
    '<path d="M16.5 8.5h3v9a2 2 0 0 1-2 2M7 9h6M7 12.5h6" />';
const _traceCle = '<circle cx="8" cy="15" r="4" />'
    '<path d="M10.8 12.2 20 3M16 7l3 3M13.5 9.5l2 2" />';
const _traceCorbeille = '<path d="M4 6.4h16" />'
    '<path d="M9.4 6.4V4.6a1 1 0 0 1 1-1h3.2a1 1 0 0 1 1 1v1.8" />'
    '<path d="M6.2 6.4 7 19.6a1.6 1.6 0 0 0 1.6 1.5h6.8a1.6 1.6 0 0 0 1.6-1.5l.8-13.2" />';
const _traceCloche = '<path d="M6.4 16.4V11a5.6 5.6 0 0 1 11.2 0v5.4l1.6 1.8H4.8l1.6-1.8Z" />'
    '<path d="M10 20.8a2.2 2.2 0 0 0 4 0" />';
const _traceClocheBarree = '$_traceCloche<path d="M4.2 4.2 19.8 19.8" />';
const _traceSignal = '<path d="M12 3.2 2.8 19.4a1.2 1.2 0 0 0 1 1.8h16.4a1.2 1.2 0 0 0 1-1.8L12 3.2Z" />'
    '<path d="M12 9.6v4.4M12 17.2v.1" />';
const _traceSoleil = '<circle cx="12" cy="12" r="4" />'
    '<path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6" />';
const _traceLune = '<path d="M20 14.2A8.2 8.2 0 0 1 9.8 4a8.4 8.4 0 1 0 10.2 10.2Z" />';
const _traceInfo = '<circle cx="12" cy="12" r="9" />'
    '<path d="M12 11v5.2M12 7.8v.1" />';
const _traceCompte = '<circle cx="12" cy="8.4" r="3.6" />'
    '<path d="M4.6 20a7.4 7.4 0 0 1 14.8 0" />';

class _ParametresScreenState extends State<ParametresScreen> {
  bool _saisonActive = true;

  @override
  void initState() {
    super.initState();
    AlertesSaison.actives().then((v) {
      if (mounted) setState(() => _saisonActive = v);
    });
  }

  Widget _icone(String trace, Color couleur) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
        'stroke-linejoin="round">$trace</svg>',
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
      );

  /// Une ligne : pastille d'icône, titre, sous-titre, bordure fine. Le
  /// dernier élément (`fin`) remplace la flèche, par exemple par un interrupteur.
  Widget _ligne({
    required String trace,
    required String titre,
    required String sous,
    VoidCallback? onTap,
    Color? couleur,
    Widget? fin,
  }) {
    final c = couleur ?? TytoColors.encre;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TytoColors.champ.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TytoColors.encre.withOpacity(0.14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.withOpacity(0.2)),
                  ),
                  child: _icone(trace, c),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: c)),
                      const SizedBox(height: 2),
                      Text(sous,
                          style: TytoText.ui(size: 12, weight: FontWeight.w400, color: TytoColors.encre.withOpacity(0.6))),
                    ],
                  ),
                ),
                fin ?? (onTap == null ? const SizedBox.shrink() : Icon(Icons.chevron_right_rounded, color: TytoColors.encre.withOpacity(0.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _basculerSaison(bool nouveau) async {
    setState(() => _saisonActive = nouveau);
    await AlertesSaison.definir(nouveau);
    await NotificationService.reprogrammerSaisonDepuisMemoire();
  }

  Future<void> _basculerMode(bool jour) async {
    await ThemeService.definir(jour);
    if (mounted) setState(() {});
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
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
            _ligne(
              trace: _traceCompte,
              titre: connecte && email != null && email.isNotEmpty ? email : 'Visiteur',
              sous: connecte ? 'Compte connecté' : "Pas encore de compte : crée-le depuis le menu",
            ),
            _ligne(
              trace: TytoColors.jour ? _traceSoleil : _traceLune,
              titre: 'Mode jour',
              sous: TytoColors.jour ? 'Activé : fond ivoire, traits bleus' : 'Désactivé : fond bleu nuit, traits ivoire',
              onTap: () => _basculerMode(!TytoColors.jour),
              fin: Switch(
                value: TytoColors.jour,
                onChanged: _basculerMode,
                activeColor: TytoColors.encre,
                activeTrackColor: TytoColors.fauve,
              ),
            ),
            _ligne(
              trace: _saisonActive ? _traceCloche : _traceClocheBarree,
              titre: 'Conseils de saison',
              sous: _saisonActive ? 'Notifications activées' : 'Notifications désactivées',
              onTap: () => _basculerSaison(!_saisonActive),
              fin: Switch(
                value: _saisonActive,
                onChanged: _basculerSaison,
                activeColor: TytoColors.encre,
                activeTrackColor: TytoColors.fauve,
              ),
            ),
            _ligne(
              trace: _traceBlog,
              titre: 'Blog et guides',
              sous: 'Tous les articles',
              onTap: () => launchUrl(Uri.parse('https://tytoai.app/blog'), mode: LaunchMode.externalApplication),
            ),
            if (connecte)
              _ligne(
                trace: _traceCle,
                titre: 'Changer mon mot de passe',
                sous: 'Choisir un nouveau mot de passe',
                onTap: () async {
                  final ok = await MotDePasseDialog.afficher(context);
                  if (ok == true && mounted) _message('Mot de passe mis à jour.');
                },
              ),
            _ligne(
              trace: _traceSignal,
              titre: 'Signaler un problème',
              sous: "Un bug ou une erreur dans l'application",
              onTap: () async {
                final ok = await SignalerScreen.ouvrir(context);
                if (ok == true && mounted) _message('Merci, ton message a bien été envoyé.');
              },
            ),
            // Tout en bas : « À propos ».
            _ligne(
              trace: _traceInfo,
              titre: 'À propos',
              sous: "Confidentialité et conditions d'utilisation",
              onTap: () => AProposScreen.ouvrir(context),
            ),
            if (connecte)
              _ligne(
                trace: _traceCorbeille,
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
