import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../services/platform_service.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/legal_service.dart';
import 'delete_account_dialog.dart';
import '../services/notification_service.dart';
import '../services/achats_service.dart';
import '../services/user_service.dart';
import 'compte_fenetre_email.dart';
import '../screens/team_screen.dart';
import 'tyto_icons.dart';
import 'owl_sketch.dart';

class DrawerItem {
  final String id;
  final String label;
  final String sub;
  const DrawerItem({required this.id, required this.label, required this.sub});
}

/// Les rubriques, dans l'ordre exact du site. « Veille sanitaire » n'est
/// affichée qu'aux comptes Pro, comme sur le site.
const tytoDrawerItems = [
  DrawerItem(id: 'chat', label: 'Chat', sub: 'Poser une question'),
  DrawerItem(id: 'pets', label: 'Mes animaux', sub: 'Profils & compagnons'),
  DrawerItem(id: 'carnet', label: 'Carnet de santé', sub: 'Vaccins, poids, soins'),
  DrawerItem(id: 'soins', label: 'Soins en cours', sub: 'Traitements & suivi'),
  DrawerItem(id: 'tableau', label: 'Tableau des rappels', sub: 'Ce qui arrive bientôt'),
  DrawerItem(id: 'veille', label: 'Veille sanitaire', sub: "L'analyse quotidienne"),
];

/// La teinte dorée de la chouette du tiroir (#D9BE8C sur le site).
const _dore = Color(0xFFD9BE8C);

/// Le bas du dégradé du tiroir (#0A0E18 sur le site).
const _nuitProfonde = Color(0xFF0A0E18);

/// Les apparitions du site : 0,42 s, cubic-bezier(0.22, 1, 0.36, 1).
const _courbeApparition = Cubic(0.22, 1.0, 0.36, 1.0);
const _dureeApparitionMs = 420;

/// Toute la séquence : la sixième rubrique (Veille) démarre à 430 ms.
const _dureeSequenceMs = 850;

/// L'icône de chaque rubrique — les mêmes que sur le site.
Widget _iconFor(String id, {required double size, required Color color}) {
  switch (id) {
    case 'chat':
      return TytoIcon.chat(size: size, color: color);
    case 'pets':
      return TytoIcon.owl(size: size, color: color);
    case 'carnet':
      return TytoIcon.notebook(size: size, color: color);
    case 'soins':
      return TytoIcon.soins(size: size, color: color);
    case 'tableau':
      return TytoIcon.chart(size: size, color: color);
    case 'veille':
      return TytoIcon.monitor(size: size, color: color);
    default:
      return TytoIcon.chat(size: size, color: color);
  }
}

// ---------- Les icônes des actions (tracés copiés de components/Icons.js) ----------

const _traceEquipe = '<circle cx="9.2" cy="8.4" r="3.2" />'
    '<path d="M3.4 19.8a5.8 5.8 0 0 1 11.6 0" />'
    '<path d="M16.2 6.1a3.2 3.2 0 0 1 0 6" />'
    '<path d="M17.4 14.6a5.6 5.6 0 0 1 3.4 5.2" />';

const _traceBouclier = '<path d="M12 2.8 4.8 5.9v5.3c0 4.4 3 8.5 7.2 9.9 4.2-1.4 7.2-5.5 7.2-9.9V5.9L12 2.8Z" />'
    '<path d="M8.9 11.9l2.1 2.2 4.1-4.4" />';

const _traceEnveloppe = '<rect x="2.8" y="5" width="18.4" height="14" rx="2.2" />'
    '<path d="M3.4 6.6 12 12.9l8.6-6.3" />';

const _traceDeconnexion = '<path d="M9.6 20.2H5.4a1.8 1.8 0 0 1-1.8-1.8V5.6a1.8 1.8 0 0 1 1.8-1.8h4.2" />'
    '<path d="M15.8 16.4 20.2 12l-4.4-4.4" />'
    '<path d="M20.2 12H9.4" />';

/// Le livre ouvert de « Blog et guides » (tracé en ligne dans page.js, trait 1,7).
const _traceBlog = '<path d="M4.5 4.5h10a2 2 0 0 1 2 2v13h-10a2 2 0 0 1-2-2v-11a2 2 0 0 1 2-2z" />'
    '<path d="M16.5 8.5h3v9a2 2 0 0 1-2 2M7 9h6M7 12.5h6" />';

const _traceCorbeille = '<path d="M4 6.4h16" />'
    '<path d="M9.4 6.4V4.6a1 1 0 0 1 1-1h3.2a1 1 0 0 1 1 1v1.8" />'
    '<path d="M6.2 6.4 7 19.6a1.6 1.6 0 0 0 1.6 1.5h6.8a1.6 1.6 0 0 0 1.6-1.5l.8-13.2" />';

/// La cloche des conseils de saison (propre à l'application), dessinée
/// dans le même style que les icônes du site.
const _traceCloche = '<path d="M6.4 16.4V11a5.6 5.6 0 0 1 11.2 0v5.4l1.6 1.8H4.8l1.6-1.8Z" />'
    '<path d="M10 20.8a2.2 2.2 0 0 0 4 0" />';
const _traceClocheBarree = '$_traceCloche<path d="M4.2 4.2 19.8 19.8" />';

Widget _traceSvg(String trace, {required double size, required Color color, double epaisseur = 1.6}) {
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="currentColor" stroke-width="$epaisseur" stroke-linecap="round" '
    'stroke-linejoin="round">$trace</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// Le fond du tiroir : radial-gradient(circle at 30% -10%, NUIT2, NUIT 55%,
/// #0A0E18). Le cercle CSS va jusqu'au coin le plus éloigné ; Flutter
/// exprime le rayon en fraction du plus petit côté, d'où ce calcul.
RadialGradient _fondTiroir(Size taille) {
  final court = math.min(taille.width, taille.height);
  final dx = 0.7 * taille.width;
  final dy = 1.1 * taille.height;
  final rayon = math.sqrt(dx * dx + dy * dy);
  return RadialGradient(
    center: const Alignment(-0.4, -1.2),
    radius: court > 0 ? rayon / court : 1.0,
    colors: const [TytoColors.nuit2, TytoColors.nuit, _nuitProfonde],
    stops: const [0.0, 0.55, 1.0],
  );
}

/// Le tiroir de navigation, copie du site : fond nuit, cadre doré double,
/// coins ornementés, chouette dorée, rubriques à médaillon, actions en
/// cartes bordées et badge du plan.
class TytoDrawer extends StatefulWidget {
  final String activeId;
  final ValueChanged<String> onSelect;
  final bool isPro;
  final bool isPremium;

  const TytoDrawer({
    super.key,
    required this.activeId,
    required this.onSelect,
    this.isPro = false,
    this.isPremium = false,
  });

  @override
  State<TytoDrawer> createState() => _TytoDrawerState();
}

class _TytoDrawerState extends State<TytoDrawer> with SingleTickerProviderStateMixin {
  late final AnimationController _entree;
  bool _saisonActive = true; // les notifications « Conseils de saison »

  /// La rubrique sous le doigt : elle s'allume comme au survol sur le site.
  String? _rubriqueAllumee;

  // Raccourcis pour garder le reste du code lisible.
  String get activeId => widget.activeId;
  ValueChanged<String> get onSelect => widget.onSelect;
  bool get isPro => widget.isPro;
  bool get isPremium => widget.isPremium;

  @override
  void initState() {
    super.initState();
    // L'en-tête et les rubriques se révèlent pendant que le tiroir glisse,
    // aux mêmes instants que sur le site.
    _entree = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _dureeSequenceMs),
    )..forward();
    AlertesSaison.actives().then((v) {
      if (mounted) setState(() => _saisonActive = v);
    });
  }

  @override
  void dispose() {
    _entree.dispose();
    super.dispose();
  }

  /// Fondu avec un glissement de 14 px vers la droite, démarré après
  /// [delaiMs] (animation drawerReveal du site).
  Widget _apparition({required int delaiMs, required bool sansAnimation, required Widget enfant}) {
    if (sansAnimation) return enfant;
    final debut = delaiMs / _dureeSequenceMs;
    final fin = math.min(1.0, (delaiMs + _dureeApparitionMs) / _dureeSequenceMs);
    final intervalle = Interval(debut, fin, curve: _courbeApparition);
    return AnimatedBuilder(
      animation: _entree,
      builder: (context, child) {
        final v = math.max(0.0, math.min(1.0, intervalle.transform(_entree.value)));
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(-14 * (1 - v), 0),
            child: child,
          ),
        );
      },
      child: enfant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ecran = media.size;
    final sansAnimation = media.disableAnimations;
    // width: 80 %, maxWidth: 310 px, comme sur le site.
    final largeur = math.min(ecran.width * 0.8, 310.0);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Menu de navigation',
      child: ConstrainedBox(
        constraints: BoxConstraints.expand(width: largeur),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Le fond flouté à droite du tiroir (backdrop-filter: blur(3px)
            // du voile assombri sur le site).
            Positioned(
              left: largeur,
              top: 0,
              bottom: 0,
              width: ecran.width,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: _panneau(context, sansAnimation: sansAnimation),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panneau(BuildContext context, {required bool sansAnimation}) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              gradient: _fondTiroir(contraintes.biggest),
              // box-shadow: 8px 0 50px rgba(0,0,0,.5) — rayon converti pour
              // retrouver le même flou que le navigateur.
              boxShadow: const [
                BoxShadow(color: Color(0x80000000), offset: Offset(8, 0), blurRadius: 42.4),
              ],
            ),
            child: Stack(
              children: [
                // Le cadre doré double, façon carte de membre gravée.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: TytoColors.fauve.withAlpha(0x45)),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: TytoColors.fauve.withAlpha(0x25), width: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _apparition(
                        delaiMs: 100,
                        sansAnimation: sansAnimation,
                        enfant: _buildHeader(context),
                      ),
                      // Une seule zone défilante : rubriques, actions et badge.
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildRubriques(sansAnimation: sansAnimation),
                              ..._buildActions(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Les quatre coins ornementés, au-dessus du reste.
                const Positioned(top: 9, left: 9, child: _CoinOrnement()),
                const Positioned(
                  top: 9,
                  right: 9,
                  child: RotatedBox(quarterTurns: 1, child: _CoinOrnement()),
                ),
                const Positioned(
                  bottom: 9,
                  right: 9,
                  child: RotatedBox(quarterTurns: 2, child: _CoinOrnement()),
                ),
                const Positioned(
                  bottom: 9,
                  left: 9,
                  child: RotatedBox(quarterTurns: 3, child: _CoinOrnement()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// En-tête : chouette dorée, « Tyto » souligné d'un trait doré (aussi
  /// large que la colonne), « L'IA du monde animal », puis la croix.
  Widget _buildHeader(BuildContext context) {
    const interligne = TextLeadingDistribution.even;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TytoColors.lune.withAlpha(0x12))),
      ),
      child: Row(
        children: [
          const OwlSketch(size: 32, ink: _dore),
          const SizedBox(width: 11),
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tyto',
                  style: TytoText.display(size: 22, weight: FontWeight.w700, color: TytoColors.lune)
                      .copyWith(height: 1.1, leadingDistribution: interligne),
                ),
                const SizedBox(height: 3),
                Container(height: 1.5, color: TytoColors.fauve),
                const SizedBox(height: 3),
                Text(
                  "L'IA du monde animal",
                  style: TytoText.ui(size: 10.5, weight: FontWeight.w400, color: TytoColors.brume)
                      .copyWith(fontStyle: FontStyle.italic, height: 1.1, leadingDistribution: interligne),
                ),
              ],
            ),
          ),
          const Spacer(),
          // La croix « × » du site (Karla 26 px, brume), avec une zone de
          // toucher plus large que le signe lui-même.
          Semantics(
            button: true,
            label: 'Fermer le menu',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '×',
                      style: TytoText.ui(size: 26, weight: FontWeight.w400, color: TytoColors.brume)
                          .copyWith(height: 1.0, leadingDistribution: interligne),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRubriques({required bool sansAnimation}) {
    final visibles = tytoDrawerItems
        .where((r) => r.id != 'veille' || isPro || activeId == 'veille')
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibles.length; i++)
            _apparition(
              // Délais du site : 0,06 s puis +0,05 s par rubrique ; la
              // sixième suit la règle générale 0,1 s + rang x 0,055 s.
              delaiMs: i < 5 ? 60 + 50 * i : 100 + 55 * (i + 1),
              sansAnimation: sansAnimation,
              enfant: _rubrique(visibles[i]),
            ),
        ],
      ),
    );
  }

  Widget _rubrique(DrawerItem item) {
    final on = item.id == activeId;
    final lit = on || item.id == _rubriqueAllumee; // allumée : active ou sous le doigt
    const duree = Duration(milliseconds: 200);
    final couleurIcone = lit ? TytoColors.fauve : TytoColors.brume;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _rubriqueAllumee = item.id),
      onTapCancel: () => setState(() => _rubriqueAllumee = null),
      onTap: () => onSelect(item.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 13, 6, 13),
        child: Row(
          children: [
            // Le médaillon, une étape du vol.
            AnimatedContainer(
              duration: duree,
              curve: Curves.ease,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: lit
                    ? RadialGradient(
                        radius: 0.7071, // jusqu'aux coins, comme le cercle CSS
                        colors: [TytoColors.fauve.withAlpha(0x38), TytoColors.fauve.withAlpha(0x0a)],
                      )
                    : null,
                border: Border.all(color: lit ? TytoColors.fauve : TytoColors.lune.withAlpha(0x1f)),
                boxShadow: lit
                    ? [BoxShadow(color: TytoColors.fauve.withAlpha(0x40), blurRadius: 9.5, spreadRadius: 1)]
                    : null,
              ),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: couleurIcone),
                duration: duree,
                curve: Curves.ease,
                builder: (context, couleur, _) =>
                    _iconFor(item.id, size: 16, color: couleur ?? couleurIcone),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: duree,
                    curve: Curves.ease,
                    style: TytoText.display(
                      size: 15,
                      weight: on ? FontWeight.w700 : FontWeight.w600,
                      color: lit ? TytoColors.lune : TytoColors.lune.withAlpha(0xcc),
                    ),
                    child: Text(item.label),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.sub,
                    style: TytoText.ui(size: 11.5, weight: FontWeight.w400, color: TytoColors.brume),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Les actions du bas, dans l'ordre du site : (Créer mon compte), Nos
  /// offres, Blog et guides, Mon équipe, Gérer l'abonnement, Se
  /// déconnecter, puis le badge du plan. S'y ajoutent les réglages propres
  /// à l'application (conseils de saison, suppression du compte, liens
  /// légaux), au même style.
  List<Widget> _buildActions(BuildContext context) {
    final subscribed = isPro || isPremium;
    final signedIn = AuthService.isSignedIn;

    // Sur iOS, l'abonnement passe par l'App Store, jamais par le site ni
    // par Stripe : Apple l'interdit (règle 3.1.1). Les offres n'y
    // apparaissent que si les achats intégrés sont en place.
    final offresVisibles = PlatformInfo.estIOS ? AchatsService.disponible : true;
    // Un abonnement acheté sur le site ne se gère pas depuis iOS : on ne
    // propose la gestion Apple que pour un abonnement Apple.
    final gestionVisible = PlatformInfo.estIOS
        ? AchatsService.disponible && UserService.planSource == 'apple'
        : true;

    final icone = TytoColors.brume;
    final nosOffres = _carte(
      icone: TytoIcon.sparkle(size: 16, color: icone),
      label: 'Nos offres',
      sub: 'Découvrir Premium & Pro',
      onTap: () {
        Navigator.pop(context);
        if (PlatformInfo.estIOS) {
          AchatsService.ouvrirOffres(context);
        } else {
          BillingService.openOffers();
        }
      },
    );

    return [
      if (!signedIn)
        // Visiteur : le bouton doré « Créer mon compte », puis les offres.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BoutonDore(
                // Comme le site : la fenêtre « Crée ton compte gratuit »
                // s'ouvre par-dessus la page, une fois le menu refermé.
                onTap: () {
                  Navigator.pop(context);
                  FenetreCreerCompte.afficher(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _traceSvg(_traceEnveloppe, size: 16, color: TytoColors.nuit),
                    const SizedBox(width: 6),
                    Text(
                      'Créer mon compte',
                      style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: TytoColors.nuit),
                    ),
                  ],
                ),
              ),
              if (offresVisibles) ...[
                const SizedBox(height: 8),
                nosOffres,
              ],
            ],
          ),
        )
      else if (!subscribed && offresVisibles)
        _encadre(nosOffres),
      // Le blog : pour tout le monde.
      _encadre(_carte(
        icone: _traceSvg(_traceBlog, size: 16, color: icone, epaisseur: 1.7),
        label: 'Blog et guides',
        sub: 'Tous les articles',
        onTap: () {
          Navigator.pop(context);
          launchUrl(Uri.parse('https://tytoai.app/blog'), mode: LaunchMode.externalApplication);
        },
      )),
      if (signedIn && isPro)
        _encadre(_carte(
          icone: _traceSvg(_traceEquipe, size: 16, color: icone),
          label: 'Mon équipe',
          sub: 'Gérer les soigneurs',
          onTap: () {
            Navigator.pop(context);
            TeamScreen.ouvrir(context);
          },
        )),
      if (signedIn && subscribed && gestionVisible)
        _encadre(_carte(
          icone: TytoIcon.sparkle(size: 16, color: icone),
          label: "Gérer l'abonnement",
          sub: 'Facturation, résiliation',
          onTap: () async {
            Navigator.pop(context);
            if (PlatformInfo.estIOS) {
              AchatsService.gererAbonnement();
            } else {
              final token = AuthService.currentSession?.accessToken;
              if (token != null) await BillingService.openPortal(token);
            }
          },
        )),
      // Les conseils de saison (épillets, chaleur, froid…) : un
      // interrupteur propre à l'application. On ne ferme pas le menu au
      // toucher, pour voir le changement.
      if (signedIn)
        _encadre(_carte(
          icone: _traceSvg(_saisonActive ? _traceCloche : _traceClocheBarree, size: 16, color: icone),
          label: 'Conseils de saison',
          sub: _saisonActive ? 'Notifications activées' : 'Notifications désactivées',
          onTap: () async {
            final nouveau = !_saisonActive;
            setState(() => _saisonActive = nouveau);
            await AlertesSaison.definir(nouveau);
            await NotificationService.reprogrammerSaisonDepuisMemoire();
          },
        )),
      if (signedIn)
        _encadre(_carte(
          icone: _traceSvg(_traceDeconnexion, size: 16, color: icone),
          label: 'Se déconnecter',
          sub: 'Fermer ma session',
          onTap: () async {
            Navigator.pop(context);
            await AuthService.signOut();
          },
        )),
      // Exigé par Apple et Google : un compte créé dans l'app doit
      // pouvoir être supprimé depuis l'app.
      if (signedIn)
        _encadre(_carte(
          icone: _traceSvg(_traceCorbeille, size: 16, color: icone),
          label: 'Supprimer mon compte',
          sub: 'Effacer définitivement mes données',
          onTap: () {
            Navigator.pop(context);
            DeleteAccountDialog.afficher(context);
          },
        )),
      if (subscribed) _buildBadge() else const SizedBox(height: 14),
      // Google Play exige que la politique de confidentialité soit
      // accessible depuis l'application, pas seulement depuis la fiche
      // du Play Store.
      _buildLiensLegaux(),
    ];
  }

  /// La marge autour de chaque action (padding: 4px 12px 0 sur le site).
  Widget _encadre(Widget carte) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: carte,
    );
  }

  /// Une action : carte bordée (rayon 13), pastille carrée arrondie de
  /// 32 px pour l'icône, titre Karla 14 et sous-titre Karla 11.
  Widget _carte({
    required Widget icone,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: TytoColors.lune.withAlpha(0x16)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TytoColors.lune.withAlpha(0x0d),
                border: Border.all(color: TytoColors.lune.withAlpha(0x16)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: icone,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TytoText.ui(size: 14, weight: FontWeight.w600, color: TytoColors.lune.withAlpha(0xcc)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: TytoText.ui(size: 11, weight: FontWeight.w400, color: TytoColors.brume),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Le badge du plan : pastille arrondie teintée (vert Pro ou fauve
  /// Premium), sous un filet qui traverse le tiroir.
  Widget _buildBadge() {
    final couleur = isPro ? TytoColors.vert : TytoColors.fauve;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: TytoColors.lune.withAlpha(0x12))),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withAlpha(0x1f),
          border: Border.all(color: couleur.withAlpha(0x66)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPro)
              _traceSvg(_traceBouclier, size: 13, color: couleur)
            else
              TytoIcon.sparkle(size: 13, color: couleur),
            const SizedBox(width: 6),
            Text(
              isPro ? 'COMPTE PRO' : 'COMPTE PREMIUM',
              style: TytoText.ui(size: 11, weight: FontWeight.w700, color: couleur)
                  .copyWith(letterSpacing: 0.66), // 0.06em
            ),
          ],
        ),
      ),
    );
  }

  /// Les liens légaux, en pied de menu — discrets mais toujours
  /// accessibles, comme l'exige Google Play.
  Widget _buildLiensLegaux() {
    Widget lien(String texte, Future<bool> Function() action) {
      return GestureDetector(
        onTap: () => action(),
        child: Text(
          texte,
          style: TytoText.ui(size: 10.5, weight: FontWeight.w400, color: TytoColors.brume)
              .copyWith(decoration: TextDecoration.underline, decorationColor: TytoColors.brume),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          lien('Confidentialité', LegalService.confidentialite),
          lien('CGU / CGV', LegalService.conditions),
          lien('Mentions légales', LegalService.mentionsLegales),
          lien('Support', LegalService.support),
        ],
      ),
    );
  }
}

/// Le bouton doré du site (goldBtn) : fond fauve, pilule, léger
/// enfoncement au toucher (.gold:active { transform: scale(0.98) }).
class _BoutonDore extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _BoutonDore({required this.onTap, required this.child});

  @override
  State<_BoutonDore> createState() => _BoutonDoreState();
}

class _BoutonDoreState extends State<_BoutonDore> {
  bool _appuye = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _appuye = true),
      onTapUp: (_) => setState(() => _appuye = false),
      onTapCancel: () => setState(() => _appuye = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _appuye ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.ease,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: TytoColors.fauve,
            borderRadius: BorderRadius.circular(999),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Le petit angle doré, dans chaque coin du tiroir.
class _CoinOrnement extends StatelessWidget {
  const _CoinOrnement();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        size: Size(16, 16),
        painter: _CoinPainter(),
      ),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Comme le SVG du site, le trait est coupé au bord de sa boîte de
    // 16 px : il n'en reste qu'un demi-pixel, très fin.
    canvas.clipRect(Offset.zero & size);
    final peinture = Paint()
      ..color = TytoColors.fauve
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final chemin = Path()
      ..moveTo(0, 8)
      ..lineTo(0, 0)
      ..lineTo(8, 0);
    canvas.drawPath(chemin, peinture);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
