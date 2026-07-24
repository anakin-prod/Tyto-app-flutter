import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_tile.dart';
import '../models/pet.dart';
import '../models/health_event.dart';
import '../services/data_service.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.pet == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final events = await DataService.loadEvents(widget.pet!.id);
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

  Future<void> _openForm() async {
    if (widget.pet == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventForm(petId: widget.pet!.id),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pet == null ? 'Carnet de santé' : 'Carnet · ${widget.pet!.name}';
    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(
        title: Text(title, style: TytoText.display(size: 18)),
        actions: [
          if (widget.pet != null)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: TytoColors.fauve),
              tooltip: 'Ajouter au carnet',
              onPressed: _openForm,
            ),
        ],
      ),
      body: widget.pet == null
          ? const TytoEmptyState(
              icon: Icons.menu_book_rounded,
              message: "Choisis d'abord un compagnon dans « Mes animaux »\npour voir son carnet de santé.",
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
              : _events.isEmpty
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
    );
  }
}

class _EventForm extends StatefulWidget {
  final String petId;
  const _EventForm({required this.petId});

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
        hintStyle: TytoText.ui(color: TytoColors.brume),
        filled: true,
        fillColor: TytoColors.nuit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPick, {bool optional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
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
            decoration: BoxDecoration(color: TytoColors.nuit, borderRadius: BorderRadius.circular(12)),
            child: Text(
              value == null ? (optional ? 'Aucun rappel' : 'Choisir une date') : _fmt(value),
              style: TytoText.ui(color: value == null ? TytoColors.brume : TytoColors.lune),
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
          color: TytoColors.nuit2,
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
                    color: TytoColors.brume.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Ajouter au carnet', style: TytoText.display(size: 19)),
              const SizedBox(height: 18),
              Text('Type', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
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
                        color: on ? TytoColors.fauve.withOpacity(0.18) : TytoColors.nuit,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: on ? TytoColors.fauve : TytoColors.lune.withOpacity(0.12)),
                      ),
                      child: Text(_typeLabel(t), style: TytoText.ui(size: 13, color: on ? TytoColors.fauve : TytoColors.brume)),
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
                Text('Poids en kg', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
                const SizedBox(height: 6),
                TextField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TytoText.ui(color: TytoColors.lune),
                  decoration: _dec('24.5'),
                ),
                const SizedBox(height: 14),
              ],
              Text('Notes (facultatif)', style: TytoText.ui(size: 12.5, color: TytoColors.brume)),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 2,
                style: TytoText.ui(color: TytoColors.lune),
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
