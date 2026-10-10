import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/owl_sketch.dart';
import '../widgets/site_icons.dart';

/// L'en-tête du site, le même sur toutes les rubriques (tableau des
/// rappels, veille…) : bouton du menu, chouette, « Tyto », badge du plan
/// et bouton URGENCE, puis un filet clair. Mesures prises sur le site :
/// padding 10 / 16 / 6, éléments de 38 px, filet lune à 10 %.
/// Quand tout ne tient pas sur une ligne, URGENCE passe dessous, calé à
/// droite, comme le fait le navigateur (flex-wrap, 6 px entre les lignes).
class EnteteSite extends StatelessWidget implements PreferredSizeWidget {
  final bool isPro;
  final bool isPremium;
  final VoidCallback onUrgence;
  final bool deuxLignes;

  const EnteteSite._({
    required this.isPro,
    required this.isPremium,
    required this.onUrgence,
    required this.deuxLignes,
  });

  /// À placer dans `appBar:` du Scaffold (qui doit avoir un `drawer`).
  factory EnteteSite.pour(
    BuildContext context, {
    required bool isPro,
    required bool isPremium,
    required VoidCallback onUrgence,
  }) {
    final largeur = MediaQuery.of(context).size.width;
    return EnteteSite._(
      isPro: isPro,
      isPremium: isPremium,
      onUrgence: onUrgence,
      deuxLignes: surDeuxLignes(largeur, isPro: isPro, isPremium: isPremium),
    );
  }

  /// Largeurs mesurées sur le site : groupe de gauche (menu, chouette,
  /// « Tyto », badge) et bouton URGENCE ; 8 px d'écart, 16 px de marge de
  /// chaque côté, contenu limité à 720 px.
  static bool surDeuxLignes(double largeurEcran, {required bool isPro, required bool isPremium}) {
    final dispo = math.min(largeurEcran, 720.0) - 32;
    final gauche = isPro ? 200.9 : (isPremium ? 233.5 : 130.3);
    return gauche + 8 + 100.9 > dispo;
  }

  @override
  Size get preferredSize => Size.fromHeight(deuxLignes ? 87.5 : 55);

  @override
  Widget build(BuildContext context) {
    final ligne = Row(
      children: [
        _BoutonMenu(onTap: () => Scaffold.of(context).openDrawer()),
        const SizedBox(width: 8),
        const OwlSketch(size: 30),
        const SizedBox(width: 8),
        Text('Tyto', style: TytoText.display(size: 20)),
        if (isPro || isPremium) ...[
          const SizedBox(width: 8),
          _BadgePlan(pro: isPro),
        ],
        if (!deuxLignes) ...[
          const Spacer(),
          _BoutonUrgence(onTap: onUrgence),
        ],
      ],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Comme une AppBar sombre : barre d'état transparente, icônes claires.
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: TytoColors.lune.withOpacity(0.1))),
        ),
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 38, child: ligne),
                    if (deuxLignes) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _BoutonUrgence(onTap: onUrgence),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bouton du menu : 38 x 38, rayon 10, trois traits dorés de 2 px.
class _BoutonMenu extends StatelessWidget {
  final VoidCallback onTap;
  const _BoutonMenu({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvrir le menu',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: TytoColors.lune.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TytoColors.lune.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 4.5),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: TytoColors.fauve,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Le badge PRO (bouclier, vert) ou PREMIUM (étincelle, doré).
class _BadgePlan extends StatelessWidget {
  final bool pro;
  const _BadgePlan({required this.pro});

  @override
  Widget build(BuildContext context) {
    final couleur = pro ? TytoColors.vert : TytoColors.fauve;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withOpacity(pro ? 0.533 : 0.467)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SiteIcon(pro ? 'IconShield' : 'IconSparkle', size: 12, color: couleur),
          const SizedBox(width: 5),
          Text(
            pro ? 'PRO' : 'PREMIUM',
            style: TytoText.ui(size: 11, weight: FontWeight.w700, color: couleur).copyWith(letterSpacing: 0.88),
          ),
        ],
      ),
    );
  }
}

/// Le bouton URGENCE : rouge, 12 px gras espacé, et le halo « sosPulse »
/// du site (un anneau qui s'écarte de 0 à 6 px en s'estompant, 2,6 s,
/// chaque moitié en « ease »). Il se tasse à 97 % sous le doigt.
class _BoutonUrgence extends StatefulWidget {
  final VoidCallback onTap;
  const _BoutonUrgence({required this.onTap});

  @override
  State<_BoutonUrgence> createState() => _BoutonUrgenceState();
}

class _BoutonUrgenceState extends State<_BoutonUrgence> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _enfonce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Comme le CSS (prefers-reduced-motion) : pas de halo si l'utilisateur
    // a demandé moins d'animations.
    final calme = MediaQuery.of(context).disableAnimations;
    if (calme) {
      if (_pulse.isAnimating) _pulse.stop();
      if (_pulse.value != 0) _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _poser(bool v) {
    if (_enfonce == v) return;
    setState(() => _enfonce = v);
  }

  @override
  Widget build(BuildContext context) {
    // padding 5 / 13 ; la ligne (14 px) laisse 2,5 px vides dessous,
    // comme dans le navigateur : 26,5 px de haut au total.
    final bouton = Container(
      padding: const EdgeInsets.fromLTRB(13, 5, 13, 7.5),
      decoration: BoxDecoration(
        color: TytoColors.urgence,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        height: 14,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SiteIcon('IconAlert', size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'URGENCE',
              style: TytoText.ui(size: 12, weight: FontWeight.w700, color: Colors.white).copyWith(letterSpacing: 0.36),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Urgence : mon animal va mal',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _poser(true),
        onTapUp: (_) => _poser(false),
        onTapCancel: () => _poser(false),
        child: Transform.scale(
          scale: _enfonce ? 0.97 : 1.0,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              final double p = t < 0.5
                  ? Curves.ease.transform(t * 2)
                  : Curves.ease.transform((t - 0.5) * 2);
              final double ecart = t < 0.5 ? 6 * p : 6 * (1 - p);
              final double alpha = t < 0.5 ? 0.5 * (1 - p) : 0.5 * p;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: TytoColors.urgence.withOpacity(alpha.clamp(0.0, 1.0).toDouble()),
                      blurRadius: 0,
                      spreadRadius: ecart,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: bouton,
          ),
        ),
      ),
    );
  }
}
