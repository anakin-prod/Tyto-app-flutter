import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../models/soin.dart';
import '../services/notification_service.dart';
import '../services/soins_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/traitement_form.dart';

const _suggestions = [
  'Conjonctivite',
  'Otite',
  'Plaie',
  'Gastro-entérite',
  'Infection urinaire',
  'Boiterie',
  'Allergie',
  'Soin dentaire',
];

/// Ouvre un dossier de soin : quel animal, quel problème, et les
/// traitements à donner (avec leurs heures). Les traitements peuvent aussi
/// arriver déjà remplis, depuis la lecture d'une ordonnance.
class NouveauSoinScreen extends StatefulWidget {
  final List<Pet> pets;
  final Pet? petInitial;
  final List<NouveauTraitement> traitementsInitiaux;
  final bool depuisOrdonnance;

  const NouveauSoinScreen({
    super.key,
    required this.pets,
    this.petInitial,
    this.traitementsInitiaux = const [],
    this.depuisOrdonnance = false,
  });

  @override
  State<NouveauSoinScreen> createState() => _NouveauSoinScreenState();
}

class _NouveauSoinScreenState extends State<NouveauSoinScreen> {
  final _titre = TextEditingController();
  final _notes = TextEditingController();
  late List<NouveauTraitement> _traitements;
  Pet? _pet;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _traitements = List<NouveauTraitement>.from(widget.traitementsInitiaux);
    _pet = widget.petInitial ?? (widget.pets.isNotEmpty ? widget.pets.first : null);
  }

  @override
  void dispose() {
    _titre.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final t = await ouvrirFormulaireTraitement(context);
    if (t == null || !mounted) return;
    setState(() => _traitements.add(t));
  }

  Future<void> _modifier(int i) async {
    final t = await ouvrirFormulaireTraitement(context, initial: _traitements[i]);
    if (t == null || !mounted) return;
    setState(() => _traitements[i] = t);
  }

  Future<void> _creer() async {
    final titre = _titre.text.trim();
    if (_pet == null) {
      setState(() => _erreur = "Choisis l'animal concerné.");
      return;
    }
    if (titre.isEmpty) {
      setState(() => _erreur = 'Indique le problème, par exemple « Conjonctivite ».');
      return;
    }
    setState(() {
      _erreur = null;
      _envoi = true;
    });
    try {
      final id = await SoinsService.creerDossier(
        petId: _pet!.id,
        titre: titre,
        notes: _notes.text,
        traitements: _traitements,
        nomAnimal: _pet!.name,
      );
      if (id == null) throw Exception('pas de session');
      // La permission de notifier est demandée ici, au moment où elle a un
      // sens : pour sonner à l'heure des prises.
      await NotificationService.demanderPermission();
      await SoinsService.reprogrammerNotifications();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      final manque = e.toString().contains('care_');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(manque
              ? "Les soins ne sont pas encore activés sur ce compte : il manque le script Supabase v8."
              : "Le dossier n'a pas pu être créé. Vérifie ta connexion et réessaie."),
        ),
      );
    }
  }

  Widget _carteTraitement(int i) {
    final t = _traitements[i];
    final lignes = <String>[
      if (t.dose != null && t.dose!.trim().isNotEmpty) t.dose!.trim(),
      rythmeTexte(t.tousLesJours, t.heures),
      periodeTexte(t.debut, t.fin),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _modifier(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.nom, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.encre)),
                  const SizedBox(height: 3),
                  for (final l in lignes)
                    Text(l, style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.65))),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Modifier',
            onPressed: () => _modifier(i),
            icon: Icon(Icons.edit_outlined, size: 20, color: TytoColors.encre.withOpacity(0.6)),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: () => setState(() => _traitements.removeAt(i)),
            icon: Icon(Icons.close_rounded, size: 20, color: TytoColors.encre.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('Nouveau dossier de soin', style: TytoText.display(size: 19))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TytoColors.papier,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TytoColors.encre.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Un dossier regroupe un problème de santé, ses traitements à heures fixes '
                "et le suivi de son évolution. Tyto te rappelle chaque prise sur ton téléphone.",
                style: TytoText.body(size: 14.5, color: TytoColors.encre.withOpacity(0.75)).copyWith(height: 1.5),
              ),
              if (widget.depuisOrdonnance) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TytoColors.fauve.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TytoColors.fauve.withOpacity(0.5)),
                  ),
                  child: Text(
                    "Les traitements viennent de l'ordonnance : les heures sont proposées par défaut. "
                    'Vérifie chaque ligne et ajuste les heures selon la prescription.',
                    style: TytoText.ui(size: 12.5, color: TytoColors.encre),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              if (widget.pets.length > 1) ...[
                etiquettePapier('Pour qui ?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in widget.pets)
                      PastillePapier(
                        texte: p.name,
                        actif: _pet?.id == p.id,
                        onTap: () => setState(() => _pet = p),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_pet != null) ...[
                etiquettePapier('Pour qui ?'),
                const SizedBox(height: 6),
                Text(_pet!.name, style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.encre)),
                const SizedBox(height: 16),
              ],

              etiquettePapier('Quel problème ?'),
              const SizedBox(height: 6),
              TextField(
                controller: _titre,
                textCapitalization: TextCapitalization.sentences,
                style: TytoText.ui(color: TytoColors.encre),
                decoration: decPapier('Conjonctivite, plaie à la patte…'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _suggestions)
                    PastillePapier(
                      texte: s,
                      actif: _titre.text.trim() == s,
                      onTap: () => setState(() => _titre.text = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              etiquettePapier('Ce qu\'a dit le vétérinaire (facultatif)'),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: TytoText.ui(color: TytoColors.encre),
                decoration: decPapier('Revoir dans 10 jours si ça ne passe pas…'),
              ),
              const SizedBox(height: 20),

              etiquettePapier('Traitements'),
              const SizedBox(height: 8),
              if (_traitements.isEmpty)
                Text(
                  'Aucun traitement pour l\'instant. Tu peux ouvrir le dossier sans traitement '
                  'pour suivre simplement l\'évolution jour après jour.',
                  style: TytoText.ui(size: 12.5, color: TytoColors.encre.withOpacity(0.6)),
                ),
              for (var i = 0; i < _traitements.length; i++) _carteTraitement(i),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _ajouter,
                  icon: const Icon(Icons.add_rounded, size: 18, color: TytoColors.encre),
                  label: Text('Ajouter un traitement', style: TytoText.ui(size: 14, color: TytoColors.encre)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: TytoColors.encre.withOpacity(0.25)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (_erreur != null) ...[
                const SizedBox(height: 14),
                Text(_erreur!, style: TytoText.ui(size: 13, color: TytoColors.urgence)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _envoi ? null : _creer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.fauve,
                    disabledBackgroundColor: TytoColors.fauve.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _envoi
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit),
                        )
                      : Text('Ouvrir le dossier', style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
