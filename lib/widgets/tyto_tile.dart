import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Une ligne avec médaillon d'icône + titre + sous-titre, dans le même
/// esprit que les rubriques du tiroir — pour que tous les écrans se
/// ressemblent, sans réécrire le style à chaque fois.
class TytoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? accent;
  final VoidCallback? onTap;

  const TytoTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? TytoColors.fauve;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TytoColors.nuit2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TytoColors.lune.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.16),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.lune)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              Text(trailing!, style: TytoText.ui(size: 12.5, weight: FontWeight.w600, color: TytoColors.brume)),
          ],
        ),
      ),
    );
  }
}

/// Un état "vide" cohérent, réutilisé sur chaque écran de liste.
class TytoEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const TytoEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: TytoColors.brume.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: TytoText.body(size: 14, color: TytoColors.brume)),
          ],
        ),
      ),
    );
  }
}
