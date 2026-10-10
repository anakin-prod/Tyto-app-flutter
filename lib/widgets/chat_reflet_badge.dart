import 'dart:async';
import 'package:flutter/material.dart';

/// Le reflet qui traverse une seule fois le badge PRO / PREMIUM quand il
/// apparaît (.plan-badge::after et l'animation « badgeGlint » de
/// globals.css) : une bande claire, large de 45 % du badge, glisse de
/// -60 % à 130 % en 0,9 s (ease-out), 0,35 s après l'affichage. Elle reste
/// dans le badge (overflow: hidden), sous son liseré de 1 px.
class ChatRefletBadge extends StatefulWidget {
  final Widget child;
  const ChatRefletBadge({super.key, required this.child});

  @override
  State<ChatRefletBadge> createState() => _ChatRefletBadgeState();
}

class _ChatRefletBadgeState extends State<ChatRefletBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;
  Timer? _depart;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _depart = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _controleur.forward();
    });
  }

  @override
  void dispose() {
    _depart?.cancel();
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Comme le site (prefers-reduced-motion) : pas de reflet du tout.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              // Le reflet se cale dans la boîte intérieure, sous le liseré.
              padding: const EdgeInsets.all(1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: AnimatedBuilder(
                  animation: _controleur,
                  builder: (context, _) {
                    final v = _controleur.value;
                    if (v <= 0 || v >= 1) return const SizedBox.shrink();
                    final t = Curves.easeOut.transform(v);
                    // left : de -60 % à 130 % de la largeur du badge ; la
                    // translation se compte ici en largeurs de bande (45 %).
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.45,
                        heightFactor: 1,
                        child: FractionalTranslation(
                          translation: Offset((-0.6 + 1.9 * t) / 0.45, 0),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              // linear-gradient(100deg, transparent,
                              // rgba(237,231,214,0.45), transparent)
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                transform: GradientRotation(0.1745),
                                colors: [Color(0x00EDE7D6), Color(0x73EDE7D6), Color(0x00EDE7D6)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
