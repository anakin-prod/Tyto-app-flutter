import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Les petits dessins au trait des écrans de réglages (viewBox 24 x 24).
class TracesReglage {
  static const compte = '<circle cx="12" cy="8.4" r="3.6" />'
      '<path d="M4.6 20a7.4 7.4 0 0 1 14.8 0" />';
  static const blog = '<path d="M4.5 4.5h10a2 2 0 0 1 2 2v13h-10a2 2 0 0 1-2-2v-11a2 2 0 0 1 2-2z" />'
      '<path d="M16.5 8.5h3v9a2 2 0 0 1-2 2M7 9h6M7 12.5h6" />';
  static const cle = '<circle cx="8" cy="15" r="4" />'
      '<path d="M10.8 12.2 20 3M16 7l3 3M13.5 9.5l2 2" />';
  static const corbeille = '<path d="M4 6.4h16" />'
      '<path d="M9.4 6.4V4.6a1 1 0 0 1 1-1h3.2a1 1 0 0 1 1 1v1.8" />'
      '<path d="M6.2 6.4 7 19.6a1.6 1.6 0 0 0 1.6 1.5h6.8a1.6 1.6 0 0 0 1.6-1.5l.8-13.2" />';
  static const cloche = '<path d="M6.4 16.4V11a5.6 5.6 0 0 1 11.2 0v5.4l1.6 1.8H4.8l1.6-1.8Z" />'
      '<path d="M10 20.8a2.2 2.2 0 0 0 4 0" />';
  static const clocheBarree = '$cloche<path d="M4.2 4.2 19.8 19.8" />';
  static const signal = '<path d="M12 3.2 2.8 19.4a1.2 1.2 0 0 0 1 1.8h16.4a1.2 1.2 0 0 0 1-1.8L12 3.2Z" />'
      '<path d="M12 9.6v4.4M12 17.2v.1" />';
  static const soleil = '<circle cx="12" cy="12" r="4" />'
      '<path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6" />';
  static const lune = '<path d="M20 14.2A8.2 8.2 0 0 1 9.8 4a8.4 8.4 0 1 0 10.2 10.2Z" />';
  static const info = '<circle cx="12" cy="12" r="9" />'
      '<path d="M12 11v5.2M12 7.8v.1" />';
  static const contraste = '<circle cx="12" cy="12" r="9" />'
      '<path d="M12 3v18a9 9 0 0 0 0-18Z" />';
  static const texte = '<path d="M2.8 18 7.6 6l4.8 12M4.5 14h6.2" />'
      '<circle cx="17.3" cy="14.7" r="2.7" />'
      '<path d="M20 12v6" />';
  static const horloge = '<circle cx="12" cy="12" r="9" />'
      '<path d="M12 7v5l3.2 2" />';
  static const hautParleur = '<path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5H4Z" />'
      '<path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" />';
  static const vibration = '<rect x="8.5" y="4" width="7" height="16" rx="1.8" />'
      '<path d="M4.6 8v8M2.4 10v4M19.4 8v8M21.6 10v4" />';
  static const telephone = '<rect x="7" y="2.8" width="10" height="18.4" rx="2.4" />'
      '<path d="M11 18.4h2" />';
  static const coche = '<path d="M5 12.6 10 17.4 19 7" />';
}

/// Un dessin au trait, de la couleur donnée.
Widget iconeReglage(String trace, Color couleur, {double taille = 18}) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      'stroke-linejoin="round">$trace</svg>',
      width: taille,
      height: taille,
      colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
    );

/// Le titre d'un groupe de réglages (« Apparence », « Notifications »…).
class TitreSection extends StatelessWidget {
  final String texte;
  const TitreSection(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        texte.toUpperCase(),
        style: TytoText.ui(size: 11.5, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.55))
            .copyWith(letterSpacing: 1.1),
      ),
    );
  }
}

/// Une ligne de réglage : pastille d'icône, titre, sous-titre, bordure fine.
/// `fin` remplace la flèche (par exemple un interrupteur) ; `bas` s'ajoute
/// sous le texte (par exemple un choix à trois boutons).
class LigneReglage extends StatelessWidget {
  final String? trace;
  final String titre;
  final String? sous;
  final VoidCallback? onTap;
  final Color? couleur;
  final Widget? fin;
  final Widget? bas;

  const LigneReglage({
    super.key,
    this.trace,
    required this.titre,
    this.sous,
    this.onTap,
    this.couleur,
    this.fin,
    this.bas,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (trace != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.withOpacity(0.2)),
                        ),
                        child: iconeReglage(trace!, c),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titre, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: c)),
                          if (sous != null) ...[
                            const SizedBox(height: 2),
                            Text(sous!,
                                style: TytoText.ui(
                                    size: 12, weight: FontWeight.w400, color: TytoColors.encre.withOpacity(0.6))),
                          ],
                        ],
                      ),
                    ),
                    fin ??
                        (onTap == null
                            ? const SizedBox.shrink()
                            : Icon(Icons.chevron_right_rounded, color: TytoColors.encre.withOpacity(0.4))),
                  ],
                ),
                if (bas != null) ...[
                  const SizedBox(height: 12),
                  bas!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un interrupteur aux couleurs des réglages.
class InterrupteurReglage extends StatelessWidget {
  final bool valeur;
  final ValueChanged<bool> onChanged;
  const InterrupteurReglage({super.key, required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: valeur,
      onChanged: onChanged,
      activeColor: TytoColors.encre,
      activeTrackColor: TytoColors.fauve,
    );
  }
}

/// Un choix parmi quelques options, en boutons côte à côte (« Nuit / Jour /
/// Auto »). L'option choisie est dorée, avec le bleu nuit fixe dessus.
class ChoixSegmente<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T valeur;
  final ValueChanged<T> onChanged;

  const ChoixSegmente({
    super.key,
    required this.options,
    required this.valeur,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TytoColors.encre.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          for (final (v, texte) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == valeur ? TytoColors.fauve : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    texte,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TytoText.ui(
                      size: 13,
                      weight: FontWeight.w700,
                      color: v == valeur ? TytoColors.nuit : TytoColors.encre.withOpacity(0.75),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une pastille à cocher (heure, jours d'avance, types de rappels).
class PuceReglage extends StatelessWidget {
  final String texte;
  final bool choisie;
  final VoidCallback onTap;
  const PuceReglage({super.key, required this.texte, required this.choisie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: choisie ? TytoColors.fauve : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: choisie ? TytoColors.fauve : TytoColors.encre.withOpacity(0.28)),
        ),
        child: Text(
          texte,
          style: TytoText.ui(
            size: 13,
            weight: FontWeight.w700,
            color: choisie ? TytoColors.nuit : TytoColors.encre.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

/// Le bouton doré principal d'un écran de réglages.
class BoutonDoreReglage extends StatelessWidget {
  final String texte;
  final VoidCallback? onTap;
  const BoutonDoreReglage({super.key, required this.texte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: TytoColors.fauve,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Center(
              child: Text(texte, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.nuit)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un petit texte d'explication, discret.
class NoteReglage extends StatelessWidget {
  final String texte;
  const NoteReglage(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
      child: Text(
        texte,
        style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6)).copyWith(height: 1.4),
      ),
    );
  }
}
