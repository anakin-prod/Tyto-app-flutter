import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../services/auth_service.dart';
import '../services/pro_service.dart';
import '../services/photo_service.dart';
import '../services/data_service.dart';

/// Fonction Pro : photographier une ordonnance, laisser Tyto la lire, puis
/// vérifier chaque ligne avant de l'ajouter au carnet de santé.
/// Rien n'est enregistré sans que tu aies coché la ligne : une lecture
/// automatique peut se tromper, c'est toi qui valides.
class PrescriptionScreen extends StatefulWidget {
  final Pet pet;
  const PrescriptionScreen({super.key, required this.pet});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  File? _photo;
  PhotoCompressee? _compressee;
  bool _lecture = false;
  bool _enregistrement = false;
  PrescriptionResult? _resultat;

  Future<void> _choisirPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final choisie = await picker.pickImage(source: source, imageQuality: 100);
    if (choisie == null) return;

    final fichier = File(choisie.path);
    final compressee = await compresserPhoto(fichier);
    if (!mounted) return;
    if (compressee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cette image n'a pas pu être lue. Réessaie avec une autre photo.")),
      );
      return;
    }
    setState(() {
      _photo = fichier;
      _compressee = compressee;
      _resultat = null;
    });
  }

  Future<void> _lire() async {
    if (_compressee == null || _lecture) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _lecture = true;
      _resultat = null;
    });
    final r = await ProService.readPrescription(
      accessToken: token,
      base64Image: _compressee!.base64,
      mediaType: _compressee!.mediaType,
    );
    if (!mounted) return;
    setState(() {
      _lecture = false;
      _resultat = r.isError ? null : r;
    });
    if (r.isError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error!)));
    }
  }

  Future<void> _enregistrer() async {
    final lignes = _resultat?.lines.where((l) => l.checked && l.medication.trim().isNotEmpty).toList() ?? [];
    if (lignes.isEmpty) return;

    setState(() => _enregistrement = true);
    try {
      for (final l in lignes) {
        final parts = <String>[];
        if (l.timesPerDay != null) parts.add('${l.timesPerDay}x/jour');
        if (l.durationDays != null) {
          parts.add('pendant ${l.durationDays} jour${l.durationDays! > 1 ? 's' : ''}');
        }
        if (l.notes != null && l.notes!.trim().isNotEmpty) parts.add(l.notes!.trim());
        parts.add('(ordonnance photographiée, à vérifier)');

        final titre = l.medication.trim() + (l.dose != null && l.dose!.trim().isNotEmpty ? ' — ${l.dose!.trim()}' : '');

        await DataService.saveEvent(
          petId: widget.pet.id,
          type: 'traitement',
          eventDate: DateTime.now(),
          notes: '$titre · ${parts.join(' · ')}',
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lignes.length} traitement${lignes.length > 1 ? 's ajoutés' : ' ajouté'} au carnet.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'enregistrement n'a pas abouti, réessaie.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coches = _resultat?.lines.where((l) => l.checked).length ?? 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Ordonnance', style: TytoText.display(size: 19)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photographie l\'ordonnance de ${widget.pet.name}. Tyto en extrait les traitements, '
              'et tu vérifies chaque ligne avant de l\'ajouter au carnet.',
              style: TytoText.body(size: 14.5, color: TytoColors.brume).copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),

            if (_photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_photo!, width: double.infinity, height: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _choisirPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 17, color: TytoColors.lune),
                    label: Text('Photographier', style: TytoText.ui(size: 13.5, color: TytoColors.lune)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TytoColors.lune.withOpacity(0.22)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _choisirPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined, size: 17, color: TytoColors.lune),
                    label: Text('Galerie', style: TytoText.ui(size: 13.5, color: TytoColors.lune)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TytoColors.lune.withOpacity(0.22)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            if (_compressee != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _lecture ? null : _lire,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.vert,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _lecture ? 'Tyto lit l\'ordonnance…' : 'Lire l\'ordonnance',
                    style: TytoText.ui(weight: FontWeight.w700, color: const Color(0xFF0F2A24)),
                  ),
                ),
              ),
            ],

            if (_resultat != null) ...[
              const SizedBox(height: 20),
              if (!_resultat!.readable)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: TytoColors.urgence.withOpacity(0.13),
                    border: Border.all(color: TytoColors.urgence.withOpacity(0.45)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "La photo est difficile à lire : vérifie attentivement chaque ligne, "
                    "ou reprends une photo plus nette.",
                    style: TytoText.ui(size: 13, color: TytoColors.lune),
                  ),
                ),
              if (_resultat!.lines.isEmpty)
                Text(
                  "Aucun traitement n'a pu être identifié sur cette photo.",
                  style: TytoText.body(size: 14.5, color: TytoColors.brume),
                )
              else ...[
                Text('Traitements détectés', style: TytoText.display(size: 17)),
                const SizedBox(height: 4),
                Text(
                  'Décoche ce qui ne doit pas être ajouté.',
                  style: TytoText.ui(size: 12.5, color: TytoColors.brume),
                ),
                const SizedBox(height: 10),
                ..._resultat!.lines.map((l) => _ligne(l)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (coches == 0 || _enregistrement) ? null : _enregistrer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TytoColors.fauve,
                      disabledBackgroundColor: TytoColors.fauve.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _enregistrement
                          ? 'Enregistrement…'
                          : coches == 0
                              ? 'Coche au moins un traitement'
                              : 'Ajouter $coches traitement${coches > 1 ? 's' : ''} au carnet',
                      style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _ligne(PrescriptionLine l) {
    final details = <String>[
      if (l.dose != null && l.dose!.trim().isNotEmpty) l.dose!.trim(),
      if (l.timesPerDay != null) '${l.timesPerDay}x/jour',
      if (l.durationDays != null) 'pendant ${l.durationDays} j',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TytoColors.papier,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
      ),
      child: CheckboxListTile(
        value: l.checked,
        onChanged: (v) => setState(() => l.checked = v ?? false),
        activeColor: TytoColors.vert,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          l.medication,
          style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.encre),
        ),
        subtitle: details.isEmpty && (l.notes == null || l.notes!.isEmpty)
            ? null
            : Text(
                [...details, if (l.notes != null && l.notes!.isNotEmpty) l.notes!].join(' · '),
                style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.7)),
              ),
      ),
    );
  }
}
