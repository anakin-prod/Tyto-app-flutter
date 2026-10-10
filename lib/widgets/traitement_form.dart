import 'package:flutter/material.dart';
import '../models/soin.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'fenetre_papier.dart';
import 'soin_widgets.dart';

/// Ouvre le formulaire d'un traitement (FormTraitement du site : nom,
/// dose, heures, rythme, début, durée, remarque). Retourne le traitement
/// saisi, ou null si l'on a fermé sans valider.
Future<NouveauTraitement?> ouvrirFormulaireTraitement(
  BuildContext context, {
  NouveauTraitement? initial,
}) {
  return showModalBottomSheet<NouveauTraitement>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC0A0E18),
    builder: (_) => _TraitementForm(initial: initial),
  );
}

const _dureesRapides = [3, 5, 7, 10, 14, 21, 30];

// HEURES_RAPIDES du site.
const _heuresRapides = [
  ['08:00', 'Matin'],
  ['12:00', 'Midi'],
  ['20:00', 'Soir'],
  ['21:00', 'Coucher'],
];

// RYTHMES du site.
const _rythmes = [
  [1, 'Tous les jours'],
  [2, '1 jour sur 2'],
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
  String? _autre; // l'heure choisie dans le champ, pas encore ajoutée
  int _pas = 1;
  String _debutChoix = 'auj'; // 'auj' | 'demain' | 'date'
  DateTime _debutDate = aujourdhui();
  String _dureeChoix = '7'; // un nombre de jours, 'infini' ou 'date'
  DateTime _finDate = aujourdhui().add(const Duration(days: 6));
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t == null) {
      // Comme sur le site : 21 h est proposé d'office.
      _heures.add('21:00');
      return;
    }
    _nom.text = t.nom;
    _dose.text = t.dose ?? '';
    _notes.text = t.notes ?? '';
    _heures.addAll(t.heures);
    _heures.sort();
    _pas = t.tousLesJours;
    // Comme sur le site : en modification, les dates sont montrées telles
    // quelles (« Autre date » et « Jusqu'au… » ou « Sans fin »).
    _debutChoix = 'date';
    _debutDate = t.debut;
    final fin = t.fin;
    if (fin != null) {
      _dureeChoix = 'date';
      _finDate = fin;
    } else {
      _dureeChoix = 'infini';
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

  void _basculer(String h) {
    setState(() {
      if (_heures.contains(h)) {
        _heures.remove(h);
      } else {
        _heures.add(h);
        _heures.sort();
      }
    });
  }

  Future<void> _choisirHeure() async {
    final morceaux = (_autre ?? '21:00').split(':');
    final choisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(morceaux.first) ?? 21,
        minute: morceaux.length > 1 ? (int.tryParse(morceaux[1]) ?? 0) : 0,
      ),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (choisie == null || !mounted) return;
    setState(() => _autre = _format(choisie));
  }

  void _ajouterHeure() {
    final h = _autre;
    setState(() {
      if (h != null && !_heures.contains(h)) {
        _heures.add(h);
        _heures.sort();
      }
      _autre = null;
    });
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

  void _valider() {
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreur = 'Indique le nom du traitement, par exemple « Gouttes oculaires ».');
      return;
    }
    if (_heures.isEmpty) {
      setState(() => _erreur = 'Choisis au moins une heure de prise.');
      return;
    }
    final auj = aujourdhui();
    final debut = _debutChoix == 'auj'
        ? auj
        : _debutChoix == 'demain'
            ? auj.add(const Duration(days: 1))
            : _debutDate;
    DateTime? fin;
    if (_dureeChoix == 'date') {
      fin = _finDate;
    } else if (_dureeChoix != 'infini') {
      final n = int.tryParse(_dureeChoix) ?? 7;
      fin = debut.add(Duration(days: n - 1));
    }
    if (fin != null && fin.isBefore(debut)) {
      setState(() => _erreur = 'La date de fin est avant le début.');
      return;
    }
    final heures = List<String>.from(_heures)..sort();
    Navigator.pop(
      context,
      NouveauTraitement(
        nom: nom,
        dose: _dose.text.trim().isEmpty ? null : _dose.text.trim(),
        heures: heures,
        tousLesJours: _pas,
        debut: debut,
        fin: fin,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  Widget _pastilles(List<Widget> enfants) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: enfants,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rapides = _heuresRapides.map((x) => x[0]).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: TytoColors.papier,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // Le cadre blanc du formulaire du site : bord encre à 15 %,
            // rayon 12, padding 6 14 14.
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: encreA(0x26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EtiquetteSoin('Traitement'),
                  ChampSoin(controller: _nom, indication: 'Gouttes oculaires, comprimé…'),
                  const EtiquetteSoin('Dose (facultatif)'),
                  ChampSoin(controller: _dose, indication: '1 goutte par œil, 1/2 comprimé…'),

                  const EtiquetteSoin('À quelle heure ?'),
                  _pastilles([
                    for (final x in _heuresRapides)
                      PastilleSoin(
                        texte: '${x[1]} · ${soinsHeureTexte(x[0])}',
                        actif: _heures.contains(x[0]),
                        onTap: () => _basculer(x[0]),
                      ),
                    for (final h in _heures.where((h) => !rapides.contains(h)))
                      PastilleSoin(
                        texte: '${soinsHeureTexte(h)} ×',
                        actif: true,
                        onTap: () => _basculer(h),
                      ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        ChampChoixSoin(
                          texte: _autre ?? '--:--',
                          largeur: 130,
                          hauteur: 41.2,
                          heure: true,
                          onTap: _choisirHeure,
                        ),
                        const SizedBox(width: 8),
                        BoutonDiscretSoin('Ajouter cette heure', onTap: _ajouterHeure),
                      ],
                    ),
                  ),

                  const EtiquetteSoin('Rythme'),
                  _pastilles([
                    for (final r in _rythmes)
                      PastilleSoin(
                        texte: r[1] as String,
                        actif: _pas == (r[0] as int),
                        onTap: () => setState(() => _pas = r[0] as int),
                      ),
                  ]),

                  const EtiquetteSoin('Début'),
                  _pastilles([
                    PastilleSoin(
                      texte: "Aujourd'hui",
                      actif: _debutChoix == 'auj',
                      onTap: () => setState(() => _debutChoix = 'auj'),
                    ),
                    PastilleSoin(
                      texte: 'Demain',
                      actif: _debutChoix == 'demain',
                      onTap: () => setState(() => _debutChoix = 'demain'),
                    ),
                    PastilleSoin(
                      texte: 'Autre date',
                      actif: _debutChoix == 'date',
                      onTap: () => setState(() => _debutChoix = 'date'),
                    ),
                    if (_debutChoix == 'date')
                      ChampChoixSoin(
                        texte: jourLong(_debutDate),
                        largeur: 160,
                        hauteur: 39,
                        heure: false,
                        onTap: () async {
                          final d = await _choisirDate(_debutDate);
                          if (d == null || !mounted) return;
                          setState(() => _debutDate = d);
                        },
                      ),
                  ]),

                  const EtiquetteSoin('Durée'),
                  _pastilles([
                    for (final n in _dureesRapides)
                      PastilleSoin(
                        texte: '$n jours',
                        actif: _dureeChoix == '$n',
                        onTap: () => setState(() => _dureeChoix = '$n'),
                      ),
                    PastilleSoin(
                      texte: 'Sans fin',
                      actif: _dureeChoix == 'infini',
                      onTap: () => setState(() => _dureeChoix = 'infini'),
                    ),
                    PastilleSoin(
                      texte: "Jusqu'au…",
                      actif: _dureeChoix == 'date',
                      onTap: () => setState(() => _dureeChoix = 'date'),
                    ),
                    if (_dureeChoix == 'date')
                      ChampChoixSoin(
                        texte: jourLong(_finDate),
                        largeur: 160,
                        hauteur: 39,
                        heure: false,
                        onTap: () async {
                          final d = await _choisirDate(_finDate);
                          if (d == null || !mounted) return;
                          setState(() => _finDate = d);
                        },
                      ),
                  ]),

                  const EtiquetteSoin('Remarque (facultatif)'),
                  ChampSoin(controller: _notes, indication: 'À donner pendant le repas…'),

                  if (_erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_erreur!, style: TytoText.ui(size: 13, color: TytoColors.urgence)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: rangeeBoutonsSoin([
                      BoutonOrSoin('Valider', onTap: _valider),
                      BoutonDiscretSoin('Annuler', onTap: () => Navigator.pop(context)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
