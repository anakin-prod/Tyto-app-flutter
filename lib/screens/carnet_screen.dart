import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/colors.dart';
import '../theme/background.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/pet.dart';
import '../models/health_event.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/account_gate.dart';
import '../widgets/pro_upsell.dart';
import '../widgets/voice_button.dart';
import '../services/user_service.dart';
import '../services/pro_service.dart';
import '../services/pdf_service.dart';
import 'prescription_screen.dart';

const _eventTypes = ['vaccin', 'poids', 'vermifuge', 'visite', 'traitement'];

IconData _typeIcon(String t) {
  switch (t) {
    case 'vaccin':
      return Icons.vaccines_rounded;
    case 'poids':
      return Icons.monitor_weight_rounded;
    case 'vermifuge':
      return Icons.medication_rounded;
    case 'visite':
      return Icons.local_hospital_rounded;
    default:
      return Icons.event_note_rounded;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'vaccin':
      return 'Vaccin';
    case 'poids':
      return 'Pesée';
    case 'vermifuge':
      return 'Vermifuge';
    case 'visite':
      return 'Visite vétérinaire';
    default:
      return 'Traitement';
  }
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Le carnet d'un compagnon précis. Si aucun animal n'est passé, l'écran
/// invite à en choisir un depuis "Mes animaux".
class CarnetScreen extends StatefulWidget {
  final Pet? pet;
  const CarnetScreen({super.key, this.pet});

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen> {
  List<HealthEvent> _events = [];
  List<Pet> _pets = [];
  Pet? _selected;
  bool _loading = true;
  bool _isPro = false;
  bool _synthLoading = false;
  bool _exportLoading = false;
  VetReport? _synthese;

  @override
  void initState() {
    super.initState();
    _selected = widget.pet;
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      // On charge la liste des compagnons pour pouvoir passer de l'un à
      // l'autre depuis le carnet, comme sur le site.
      final token = AuthService.currentSession?.accessToken;
      if (token != null) {
        final profil = await UserService.fetchMe(token);
        if (mounted) _isPro = profil.pro;
      }
      final pets = await DataService.loadPets();
      final choisi = _selected ?? (pets.isNotEmpty ? pets.first : null);
      final events = choisi == null ? <HealthEvent>[] : await DataService.loadEvents(choisi.id);
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _selected = choisi;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _selectPet(Pet p) async {
    setState(() {
      _selected = p;
      _loading = true;
    });
    try {
      final events = await DataService.loadEvents(p.id);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Les pastilles permettant de passer d'un compagnon à l'autre.
  Widget _petSelector() {
    if (_pets.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _pets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = _pets[i];
          final on = p.id == _selected?.id;
          return GestureDetector(
            onTap: () => _selectPet(p),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: on ? TytoColors.fauve.withOpacity(0.18) : TytoColors.nuit2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? TytoColors.fauve : TytoColors.lune.withOpacity(0.12)),
              ),
              child: Text(
                p.name,
                style: TytoText.ui(
                  size: 13.5,
                  weight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? TytoColors.fauve : TytoColors.brume,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm() async {
    if (_selected == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventForm(petId: _selected!.id, isPro: _isPro),
    );
    if (saved == true) _load();
  }

  /// Fonction Pro : photographier une ordonnance pour en extraire les
  /// traitements. Sans abonnement Pro, on explique ce que c'est.
  /// Le dossier PDF, disponible pour tout compte connecté (pas besoin
  /// d'être Pro) — généré sur l'appareil, puis proposé au partage.
  Future<void> _exporterPdf() async {
    if (_selected == null || _exportLoading) return;
    setState(() => _exportLoading = true);
    try {
      final fichier = await PdfService.genererDossier(pet: _selected!, evenements: _events);
      if (!mounted) return;
      await Share.shareXFiles([XFile(fichier.path)], text: 'Dossier de ${_selected!.name}, par Tyto.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("L'export n'a pas abouti, réessaie.")),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  Future<void> _ouvrirOrdonnance() async {
    if (!_isPro) return ProUpsell.afficher(context);
    if (_selected == null) return;
    final ajoute = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PrescriptionScreen(pet: _selected!)),
    );
    if (ajoute == true) _load();
  }

  /// Fonction Pro : la synthèse rédigée par Tyto pour le vétérinaire.
  Future<void> _genererSynthese() async {
    if (!_isPro) return ProUpsell.afficher(context);
    if (_selected == null || _synthLoading) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _synthLoading = true;
      _synthese = null;
    });
    final r = await ProService.vetReport(accessToken: token, petId: _selected!.id);
    if (!mounted) return;
    setState(() {
      _synthLoading = false;
      _synthese = r;
    });
    if (r == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La synthèse n'a pas pu être générée. Réessaie dans un instant.")),
      );
    }
  }

  /// La rangée de boutons Pro, sous le sélecteur de compagnon.
  Widget _actionsPro() {
    Widget bouton({
      required IconData icone,
      required String texte,
      required VoidCallback onTap,
      bool charge = false,
      bool proRequis = true,
    }) {
      // Export n'est pas une fonction Pro : elle reste toujours dorée
      // et sans cadenas, contrairement à Ordonnance et Synthèse.
      final actif = !proRequis || _isPro;
      final couleur = proRequis ? TytoColors.vert : TytoColors.fauve;
      return Expanded(
        child: OutlinedButton(
          onPressed: charge ? null : onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: actif ? couleur.withOpacity(0.55) : TytoColors.lune.withOpacity(0.18)),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (charge)
                SizedBox(
                    height: 13, width: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: couleur))
              else
                Icon(icone, size: 15, color: actif ? couleur : TytoColors.brume),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TytoText.ui(size: 12.5, color: actif ? couleur : TytoColors.brume),
                ),
              ),
              // Le cadenas rappelle que la fonction demande le plan Pro —
              // jamais affiché pour Export, qui n'en a pas besoin.
              if (proRequis && !_isPro) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock_outline_rounded, size: 12, color: TytoColors.brume),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          bouton(
            icone: Icons.description_outlined,
            texte: 'Export',
            onTap: _exporterPdf,
            proRequis: false,
            charge: _exportLoading,
          ),
          const SizedBox(width: 8),
          bouton(
            icone: Icons.photo_camera_outlined,
            texte: 'Ordonnance',
            onTap: _ouvrirOrdonnance,
          ),
          const SizedBox(width: 8),
          bouton(
            icone: Icons.medical_services_outlined,
            texte: 'Synthèse',
            onTap: _genererSynthese,
            charge: _synthLoading,
          ),
        ],
      ),
    );
  }

  /// La synthèse affichée sur le papier ivoire, comme sur le site.
  Widget _carteSynthese() {
    final morceaux = _synthese!.content.split('**');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TytoColors.papier,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, size: 17, color: TytoColors.encre),
              const SizedBox(width: 7),
              Expanded(
                child: Text('Synthèse pour le vétérinaire',
                    style: TytoText.display(size: 17, color: TytoColors.encre)),
              ),
              GestureDetector(
                onTap: () => setState(() => _synthese = null),
                child: Icon(Icons.close_rounded, size: 18, color: TytoColors.encre.withOpacity(0.55)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TytoText.body(size: 15, color: TytoColors.encre).copyWith(height: 1.65),
              children: [
                for (var i = 0; i < morceaux.length; i++)
                  TextSpan(
                    text: morceaux[i],
                    style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selected == null ? 'Carnet de santé' : 'Carnet · ${_selected!.name}';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title, style: TytoText.display(size: 18)),
        actions: [
          if (_selected != null)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: TytoColors.fauve),
              tooltip: 'Ajouter au carnet',
              onPressed: _openForm,
            ),
        ],
      ),
      body: !AuthService.isSignedIn
          ? const AccountGate()
          : _loading
              ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
              : _pets.isEmpty
                  ? const TytoEmptyState(
                      icon: Icons.menu_book_rounded,
                      message: "Ajoute d'abord un compagnon dans « Mes animaux »\npour ouvrir son carnet de santé.",
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 8),
                        _petSelector(),
                        _actionsPro(),
                        if (_synthese != null) _carteSynthese(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _events.isEmpty
                              ? const TytoEmptyState(
                                  icon: Icons.menu_book_rounded,
                                  message: "Aucun événement enregistré.\nAjoute un vaccin, une pesée ou une visite avec le bouton +.",
                                )
                              : RefreshIndicator(
                                  color: TytoColors.fauve,
                                  backgroundColor: TytoColors.nuit2,
                                  onRefresh: _load,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _events.length,
                                    itemBuilder: (context, i) {
                                      final e = _events[i];
                                      final parts = [
                                        _fmt(e.eventDate),
                                        if (e.nextDue != null) 'Rappel : ${_fmt(e.nextDue!)}',
                                        if (e.notes != null) e.notes!,
                                      ];
                                      return TytoTile(
                                        icon: _typeIcon(e.type),
                                        title: _typeLabel(e.type),
                                        subtitle: parts.join(' · '),
                                        trailing: e.valueNum != null ? '${e.valueNum} kg' : null,
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }
}

class _EventForm extends StatefulWidget {
  final String petId;
  /// La dictée vocale est une fonction Pro : le micro n'apparaît que
  /// pour les comptes qui y ont droit, comme sur le site.
  final bool isPro;
  const _EventForm({required this.petId, this.isPro = false});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  String _type = 'vaccin';
  DateTime _eventDate = DateTime.now();
  DateTime? _nextDue;
  final _value = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DataService.saveEvent(
        petId: widget.petId,
        type: _type,
        eventDate: _eventDate,
        nextDue: _nextDue,
        valueNum: double.tryParse(_value.text.replaceAll(',', '.')),
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'enregistrement n'a pas abouti, réessaie.")),
      );
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
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

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPick, {bool optional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6))
                .copyWith(letterSpacing: 1.1)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TytoColors.encre.withOpacity(0.2)),
            ),
            child: Text(
              value == null ? (optional ? 'Aucun rappel' : 'Choisir une date') : _fmt(value),
              style: TytoText.ui(color: value == null ? TytoColors.encre.withOpacity(0.4) : TytoColors.encre),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Ajouter au carnet', style: TytoText.display(size: 19, color: TytoColors.encre)),
              const SizedBox(height: 18),
              Text('Type', style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6)).copyWith(letterSpacing: 1.1)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eventTypes.map((t) {
                  final on = t == _type;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: on ? TytoColors.fauve.withOpacity(0.22) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: on ? TytoColors.fauve : TytoColors.encre.withOpacity(0.2)),
                      ),
                      child: Text(_typeLabel(t), style: TytoText.ui(size: 13, color: on ? const Color(0xFF7A5A2A) : TytoColors.encre.withOpacity(0.7))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _dateField('Date', _eventDate, (d) => setState(() => _eventDate = d)),
              const SizedBox(height: 14),
              _dateField('Prochain rappel (facultatif)', _nextDue, (d) => setState(() => _nextDue = d), optional: true),
              const SizedBox(height: 14),
              if (_type == 'poids') ...[
                Text('Poids en kg', style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6)).copyWith(letterSpacing: 1.1)),
                const SizedBox(height: 6),
                TextField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TytoText.ui(color: TytoColors.encre),
                  decoration: _dec('24.5'),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Text('Notes (facultatif)', style: TytoText.ui(size: 11, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6)).copyWith(letterSpacing: 1.1)),
                  const Spacer(),
                  if (widget.isPro)
                    VoiceButton(
                      size: 34,
                      title: 'Dicter la note',
                      onText: (t) {
                        _notes.text = t;
                        _notes.selection = TextSelection.fromPosition(
                          TextPosition(offset: _notes.text.length),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 2,
                style: TytoText.ui(color: TytoColors.encre),
                decoration: _dec('Rappel annuel, clinique du parc…'),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TytoColors.fauve,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit))
                      : Text('Enregistrer', style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
