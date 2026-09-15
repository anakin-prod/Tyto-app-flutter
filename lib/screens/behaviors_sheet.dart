import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../data/behaviors.dart';
import '../widgets/tyto_icons.dart';

/// « Pourquoi il fait ça ? » — pré-écrit, aucun appel à l'IA, s'ouvre
/// instantanément. Une question par ligne, la réponse se déplie au
/// toucher, exactement comme le <details> du site.
class BehaviorsSheet extends StatelessWidget {
  final Pet pet;
  const BehaviorsSheet({super.key, required this.pet});

  static Future<void> afficher(BuildContext context, Pet pet) {
    return showDialog(
      context: context,
      barrierColor: const Color(0xCC0A0E18),
      builder: (_) => BehaviorsSheet(pet: pet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = behaviorsFor(pet.species);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Container(
          decoration: BoxDecoration(
            color: TytoColors.papier,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SpeciesIcon(species: pet.species, size: 18, color: TytoColors.encre),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Pourquoi il fait ça ?',
                        style: TytoText.display(size: 19, color: TytoColors.encre)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('×', style: TytoText.ui(size: 22, color: TytoColors.encre.withOpacity(0.55))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Les gestes mystérieux de ${pet.name}, décodés. Touche une question pour voir la réponse.',
                style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, i) => _Accordeon(item: items[i]),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Un comportement inhabituel ou soudain chez ${pet.name} ? Pose la question à Tyto '
                'dans le chat — il connaît son profil.',
                style: TytoText.ui(size: 11, color: TytoColors.encre.withOpacity(0.55)).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une question qui se déplie — le même geste que <details>/<summary>.
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _ouvert = !_ouvert),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question.replaceAll(' (', '\n('),
                    style: TytoText.ui(size: 14, weight: FontWeight.w700, color: TytoColors.encre),
                  ),
                ),
                AnimatedRotation(
                  turns: _ouvert ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: TytoColors.encre.withOpacity(0.5)),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.item.reponse,
                  style: TytoText.body(size: 13.5, color: TytoColors.encre).copyWith(height: 1.55),
                ),
              ),
              crossFadeState: _ouvert ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}
