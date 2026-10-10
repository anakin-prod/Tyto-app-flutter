import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/pet.dart';
import '../data/behaviors.dart';
import '../widgets/site_icons.dart';
import '../widgets/animaux_styles.dart';

/// « Pourquoi il fait ça ? » — pré-écrit, aucun appel à l'IA, s'ouvre
/// instantanément. Une question par ligne, la réponse se déplie au
/// toucher, exactement comme le <details> du site.
class BehaviorsSheet extends StatelessWidget {
  final Pet pet;
  const BehaviorsSheet({super.key, required this.pet});

  static Future<void> afficher(BuildContext context, Pet pet) {
    return showDialog(
      context: context,
      barrierColor: const Color(0xCC0A0E18), // rgba(10,14,24,0.8)
      builder: (_) => BehaviorsSheet(pet: pet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = behaviorsFor(pet.species);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          // paperCard du site ; ce qui défile reste dans l'arrondi.
          decoration: decorationPapier,
          clipBehavior: Clip.antiAlias,
          // Toute la carte défile, en-tête compris (overflowY: auto du site).
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SiteIcon.espece(pet.species, size: 18, color: TytoColors.encre),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Pourquoi il fait ça ?', style: fraunces(19)),
                    ),
                    const SizedBox(width: 8),
                    CroixFermerAnimaux(onTap: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Les gestes mystérieux de ${pet.name}, décodés. Touche une question pour voir la réponse.',
                  style: karla(12.5, couleur: const Color(0x992A2118)),
                ),
                const SizedBox(height: 12),
                for (final item in items) _Accordeon(item: item),
                // 8 de marge sous la dernière question + 2 = les 10 du site.
                const SizedBox(height: 2),
                Text(
                  'Un comportement inhabituel ou soudain chez ${pet.name} ? Pose la question à Tyto '
                  'dans le chat — il connaît son profil.',
                  style: karla(11, couleur: const Color(0x772A2118), interligne: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une question qui se déplie — le même geste que <details>/<summary> :
/// le petit triangle plein du navigateur devant la question, la réponse
/// juste en dessous, sans animation.
class _Accordeon extends StatefulWidget {
  final BehaviorQA item;
  const _Accordeon({required this.item});

  @override
  State<_Accordeon> createState() => _AccordeonState();
}

class _AccordeonState extends State<_Accordeon> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x262A2118)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _ouvert = !_ouvert),
            child: SizedBox(
              width: double.infinity,
              // Le triangle est dans la ligne : une question longue revient
              // à la ligne sous le triangle, comme sur le site.
              child: Text.rich(
                TextSpan(
                  children: [
                    // Le marqueur occupe 16 px avant le texte ; le
                    // triangle (9 px) est centré sur la ligne.
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: SizedBox(
                        width: 16,
                        height: 9,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CustomPaint(
                            size: const Size(9, 9),
                            painter: _Triangle(ouvert: _ouvert),
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: widget.item.question),
                  ],
                ),
                style: karla(14, poids: FontWeight.w700),
              ),
            ),
          ),
          if (_ouvert)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.item.reponse,
                style: karla(13.5, interligne: 1.6),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le marqueur du <summary> tel que le navigateur le dessine : triangle
/// plein de 9 px de côté, vers la droite (fermé) ou vers le bas (ouvert).
class _Triangle extends CustomPainter {
  final bool ouvert;
  const _Triangle({required this.ouvert});

  @override
  void paint(Canvas canvas, Size size) {
    final trace = Path();
    if (ouvert) {
      trace
        ..moveTo(0, 0.6)
        ..lineTo(9, 0.6)
        ..lineTo(4.5, 8.4)
        ..close();
    } else {
      trace
        ..moveTo(0, 0)
        ..lineTo(7.8, 4.5)
        ..lineTo(0, 9)
        ..close();
    }
    canvas.drawPath(trace, Paint()..color = TytoColors.encre);
  }

  @override
  bool shouldRepaint(_Triangle oldDelegate) => oldDelegate.ouvert != ouvert;
}
