import 'package:flutter/material.dart';
import '../models/soin.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

// Petits éléments partagés par les écrans « Soins en cours ».

IconData iconeSuivi(String etat) {
  switch (etat) {
    case 'better':
      return Icons.sentiment_satisfied_alt_rounded;
    case 'worse':
      return Icons.sentiment_dissatisfied_rounded;
    default:
      return Icons.sentiment_neutral_rounded;
  }
}

Color couleurSuivi(String etat) {
  switch (etat) {
    case 'better':
      return TytoColors.vert;
    case 'worse':
      return TytoColors.urgence;
    default:
      return TytoColors.fauve;
  }
}

String libelleSuivi(String etat) {
  switch (etat) {
    case 'better':
      return 'Mieux';
    case 'worse':
      return 'Moins bien';
    default:
      return 'Pareil';
  }
}

/// Le petit titre en capitales d'une section.
Widget titreSection(String texte) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Text(
      texte.toUpperCase(),
      style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.brume).copyWith(letterSpacing: 1.3),
    ),
  );
}

/// L'étiquette d'un champ de formulaire sur le papier ivoire.
Widget etiquettePapier(String texte) {
  return Text(
    texte,
    style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6))
        .copyWith(letterSpacing: 1.1),
  );
}

InputDecoration decPapier(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TytoText.ui(color: TytoColors.encre.withOpacity(0.4)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: TytoColors.encre.withOpacity(0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: TytoColors.fauve, width: 1.5),
    ),
  );
}

/// Une pastille cliquable sur le papier ivoire (choix d'une durée, d'un
/// rythme, d'une suggestion…).
class PastillePapier extends StatelessWidget {
  final String texte;
  final bool actif;
  final VoidCallback onTap;
  final IconData? icone;

  const PastillePapier({
    super.key,
    required this.texte,
    required this.actif,
    required this.onTap,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? TytoColors.fauve.withOpacity(0.22) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: actif ? TytoColors.fauve : TytoColors.encre.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 14, color: actif ? const Color(0xFF7A5A2A) : TytoColors.encre.withOpacity(0.6)),
              const SizedBox(width: 5),
            ],
            Text(
              texte,
              style: TytoText.ui(
                size: 13,
                color: actif ? const Color(0xFF7A5A2A) : TytoColors.encre.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une prise de traitement : l'heure, le nom, et le bouton « Fait ».
class LignePriseSoin extends StatelessWidget {
  final SoinOccurrence occurrence;
  final String? nomAnimal; // affiché seulement quand on mélange plusieurs animaux
  final VoidCallback onFait;
  final VoidCallback onPasser;
  final VoidCallback onAnnuler;

  const LignePriseSoin({
    super.key,
    required this.occurrence,
    this.nomAnimal,
    required this.onFait,
    required this.onPasser,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final maintenant = DateTime.now();
    final enRetard = o.enRetard(maintenant);
    final couleur = o.faite
        ? TytoColors.vert
        : o.sautee
            ? TytoColors.brume
            : enRetard
                ? TytoColors.urgence
                : TytoColors.fauve;

    final details = <String>[
      if (o.traitement.dose != null && o.traitement.dose!.trim().isNotEmpty) o.traitement.dose!.trim(),
      if (nomAnimal != null && nomAnimal!.isNotEmpty) nomAnimal!,
    ];

    String? statut;
    if (o.faite) {
      final quand = o.prise?.faiteLe;
      statut = quand == null
          ? 'Fait'
          : 'Fait à ${quand.hour.toString().padLeft(2, '0')}:${quand.minute.toString().padLeft(2, '0')}';
    } else if (o.sautee) {
      statut = 'Passée';
    } else if (enRetard) {
      statut = 'En retard';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TytoColors.nuit2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withOpacity(o.traitee ? 0.25 : 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              o.heure,
              style: TytoText.ui(size: 14.5, weight: FontWeight.w700, color: couleur),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.traitement.nom,
                  style: TytoText.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: o.traitee ? TytoColors.lune.withOpacity(0.6) : TytoColors.lune,
                  ),
                ),
                if (details.isNotEmpty || statut != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [...details, if (statut != null) statut].join(' · '),
                    style: TytoText.ui(
                      size: 12.5,
                      color: enRetard && !o.traitee ? TytoColors.urgence : TytoColors.brume,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (o.traitee)
            IconButton(
              tooltip: 'Annuler',
              onPressed: onAnnuler,
              icon: Icon(
                o.faite ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                color: couleur,
                size: 26,
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: onFait,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.fauve,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text('Fait', style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: TytoColors.nuit)),
                ),
                GestureDetector(
                  onTap: onPasser,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Text('Passer', style: TytoText.ui(size: 11.5, color: TytoColors.brume)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
