import 'package:flutter/material.dart';

/// L'apparition des messages du site (classe « .msg » de globals.css) :
/// le bloc monte de 7 px en passant de transparent à opaque, en 0,34 s,
/// avec la courbe cubic-bezier(0.2, 0.8, 0.3, 1).
///
/// L'animation ne se joue qu'une fois, quand le bloc apparaît : il reste
/// ensuite en mémoire même s'il sort de l'écran, pour ne pas rejouer
/// l'apparition à chaque défilement.
class ChatApparition extends StatefulWidget {
  final Widget child;
  const ChatApparition({super.key, required this.child});

  @override
  State<ChatApparition> createState() => _ChatApparitionState();
}

class _ChatApparitionState extends State<ChatApparition>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controleur;
  late final Animation<double> _progression;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _progression = CurvedAnimation(parent: _controleur, curve: const Cubic(0.2, 0.8, 0.3, 1.0));
    _controleur.forward();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Comme le site (prefers-reduced-motion) : pas d'animation si le
    // téléphone demande de réduire les mouvements.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return widget.child;
    return AnimatedBuilder(
      animation: _progression,
      child: widget.child,
      builder: (context, child) {
        final double t = _progression.value.clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 7 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
