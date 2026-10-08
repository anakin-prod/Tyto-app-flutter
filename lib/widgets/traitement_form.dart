import 'package:flutter/material.dart';
import '../models/soin.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'soin_widgets.dart';

/// Ouvre le formulaire d'un traitement (nom, dose, heures, rythme, durée).
/// Retourne le traitement saisi, ou null si l'on a fermé sans valider.
Future<NouveauTraitement?> ouvrirFormulaireTraitement(
  BuildContext context, {
  NouveauTraitement? initial,
}) {
  return showModalBottomSheet<NouveauTraitement>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TraitementForm(initial: initial),
  );
}

const _dureesRapides = [3, 5, 7, 10, 14, 21, 30];

const _heuresRapides = [
  ['Matin', '08:00'],
  ['Midi', '12:00'],
  ['Soir', '20:00'],
  ['Coucher', '21:00'],
];

const _rythmes = [
  [1, 'Tous les jours'],
  [2, 'Un jour sur 2'],
  [3, 'Tous les 3 jours'],
  [7, 'Chaque semaine'],
];

class _TraitementForm extends StatefulWidget {
  final NouveauTraitement? initial;
  const _TraitementForm({this.initial});

  @override
  State<_TraitementForm> createState() => _TraitementFormState();
}

class _TraitementFormState extends State<_TraitementForm> {
  final _nom = TextEditingController();
  final _dose = TextEditingController();
  final _notes = TextEditingController();
  final List<String> _heures = [];
  int _pas = 1;
  int? _jours = 7; // durée rapide choisie ; null = pas de durée rapide
  DateTime? _finPerso; // date de fin choisie à la main
  String _debutChoix = 'auj'; // 'auj' | 'demain' | 'perso'
  DateTime _debut = aujourdhui();
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t == null) return;
    _nom.text = t.nom;
    _dose.text = t.dose ?? '';
    _notes.text = t.notes ?? '';
    _heures.addAll(t.heures);
    _pas = t.tousLesJours;
    _debut = t.debut;
    final auj = aujourdhui();
    if (_debut == auj) {
      _debutChoix = 'auj';
    } else if (_debut == auj.add(const Duration(days: 1))) {
      _debutChoix = 'demain';
    } else {
      _debutChoix = 'perso';
    }
    if (t.fin == null) {
      _jours = null;
      _finPerso = null;
    } else {
      final n = t.fin!.difference(t.debut).inDays + 1;
      if (_dureesRapides.contains(n)) {
        _jours = n;
        _finPerso = null;
      } else {
        _jours = null;
        _finPerso = t.fin;
      }
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _basculerHeure(String h) {
    setState(() {
      if (_heures.contains(h)) {
        _heures.remove(h);
      } else {
        _heures.add(h);
        _heures.sort();
      }
      _erreur = null;
    });
  }

  Future<void> _autreHeure() async {
    final choisie = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (choisie == null) return;
    final h = _format(choisie);
    if (!_heures.contains(h)) {
      setState(() {
        _heures.add(h);
        _heures.sort();
        _erreur = null;
      });
    }
  }

  Future<DateTime?> _choisirDate(DateTime depart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: depart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return null;
    return jourSeul(d);
  }

  DateTime? _calculerFin() {
    if (_finPerso != null) return _finPerso;
    if (_jours == null) return null;
    return _debut.add(Duration(days: _jours! - 1));
  }

  void _valider() {
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreur = 'Donne un nom au traitement, par exemple « Gouttes oculaires ».');
      return;
    }
    if (_heures.isEmpty) {
      setState(() => _erreur = 'Ajoute au moins une heure de prise.');
      return;
    }
    final fin = _calculerFin();
    if (fin != null && fin.isBefore(_debut)) {
      setState(() => _erreur = 'La date de fin est avant le début du traitement.');
      return;
    }
    Navigator.pop(
      context,
      NouveauTraitement(
        nom: nom,
        dose: _dose.text.trim().isEmpty ? null : _dose.text.trim(),
        heures: List<String>.from(_heures),
        tousLesJours: _pas,
        debut: _debut,
        fin: fin,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = _calculerFin();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: TytoColors.papier,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TytoColors.encre.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.initial == null ? 'Ajouter un traitement' : 'Modifier le traitement',
                style: TytoText.display(size: 19, color: TytoColors.encre),
              ),
              const SizedBox(height: 18),

              etiquettePapier('Traitement'),
              const SizedBox(height: 6),
              TextField(
                controller: _nom,
                textCapitalization: TextCapitalization.sentences,
                style: TytoText.ui(color: TytoColors.encre),
                decoration: decPapier('Gouttes oculaires, comprimé, pommade…'),
              ),
              const SizedBox(height: 14),

              etiquettePapier('Dose (facultatif)'),
              const SizedBox(height: 6),
              TextField(
                controller: _dose,
                style: TytoText.ui(color: TytoColors.encre),
                decoration: decPapier('1 goutte par œil, 1/2 comprimé…'),
              ),
              const SizedBox(height: 16),

              etiquettePapier('À quelle heure ?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in _heuresRapides)
                    PastillePapier(
                      texte: '${h[0]} ${h[1]}',
                      actif: _heures.contains(h[1]),
                      onTap: () => _basculerHeure(h[1]),
                    ),
                  PastillePapier(
                    texte: 'Autre heure',
                    icone: Icons.access_time_rounded,
                    actif: false,
                    onTap: _autreHeure,
                  ),
                ],
              ),
              if (_heures.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final h in _heures)
                      Chip(
                        label: Text(h, style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: TytoColors.encre)),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: TytoColors.fauve.withOpacity(0.6)),
                        deleteIcon: Icon(Icons.close_rounded, size: 16, color: TytoColors.encre.withOpacity(0.6)),
                        onDeleted: () => _basculerHeure(h),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              etiquettePapier('Rythme'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _rythmes)
                    PastillePapier(
                      texte: r[1] as String,
                      actif: _pas == (r[0] as int),
                      onTap: () => setState(() => _pas = r[0] as int),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              etiquettePapier('Début'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PastillePapier(
                    texte: "Aujourd'hui",
                    actif: _debutChoix == 'auj',
                    onTap: () => setState(() {
                      _debutChoix = 'auj';
                      _debut = aujourdhui();
                    }),
                  ),
                  PastillePapier(
                    texte: 'Demain',
                    actif: _debutChoix == 'demain',
                    onTap: () => setState(() {
                      _debutChoix = 'demain';
                      _debut = aujourdhui().add(const Duration(days: 1));
                    }),
                  ),
                  PastillePapier(
                    texte: _debutChoix == 'perso' ? 'Le ${jourLong(_debut)}' : 'Autre date',
                    icone: Icons.event_rounded,
                    actif: _debutChoix == 'perso',
                    onTap: () async {
                      final d = await _choisirDate(_debut);
                      if (d == null) return;
                      setState(() {
                        _debutChoix = 'perso';
                        _debut = d;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              etiquettePapier('Pendant combien de temps ?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in _dureesRapides)
                    PastillePapier(
                      texte: '$n jours',
                      actif: _finPerso == null && _jours == n,
                      onTap: () => setState(() {
                        _jours = n;
                        _finPerso = null;
                      }),
                    ),
                  PastillePapier(
                    texte: 'Sans fin',
                    actif: _finPerso == null && _jours == null,
                    onTap: () => setState(() {
                      _jours = null;
                      _finPerso = null;
                    }),
                  ),
                  PastillePapier(
                    texte: _finPerso != null ? "Jusqu'au ${jourLong(_finPerso!)}" : 'Date de fin',
                    icone: Icons.event_available_rounded,
                    actif: _finPerso != null,
                    onTap: () async {
                      final d = await _choisirDate(fin ?? _debut);
                      if (d == null) return;
                      setState(() {
                        _finPerso = d;
                        _jours = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                fin == null
                    ? "Le traitement continue jusqu'à ce que tu l'arrêtes."
                    : 'Dernier jour : ${jourLong(fin)}.',
                style: TytoText.ui(size: 12, color: TytoColors.encre.withOpacity(0.6)),
              ),
              const SizedBox(height: 16),

              etiquettePapier('Précisions (facultatif)'),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: TytoText.ui(color: TytoColors.encre),
                decoration: decPapier('Pendant le repas, à jeun, bien agiter…'),
              ),

              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: TytoText.ui(size: 13, color: TytoColors.urgence)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _valider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.fauve,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.initial == null ? 'Ajouter' : 'Enregistrer',
                    style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
