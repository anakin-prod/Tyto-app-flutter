import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/reglages_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Le choix d'une heure à la façon d'un iPhone : deux roulettes (heures et
/// minutes, de 5 en 5) qu'on fait glisser avec le doigt. La valeur au milieu,
/// dans la bande dorée, est celle qui est choisie. Les roulettes tournent en
/// boucle (après 23 h vient 0 h) et un léger « clic » accompagne chaque cran.
class RouletteHeure extends StatefulWidget {
  final int heure;
  final int minute;
  final void Function(int heure, int minute) onChanged;

  const RouletteHeure({
    super.key,
    required this.heure,
    required this.minute,
    required this.onChanged,
  });

  @override
  State<RouletteHeure> createState() => _RouletteHeureState();
}

class _RouletteHeureState extends State<RouletteHeure> {
  static const double _hauteurCase = 46;
  static const int _pasMinutes = 5;

  late final FixedExtentScrollController _controleurHeures;
  late final FixedExtentScrollController _controleurMinutes;
  late int _heure;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _heure = widget.heure.clamp(0, 23);
    _minute = (widget.minute ~/ _pasMinutes) * _pasMinutes;
    _controleurHeures = FixedExtentScrollController(initialItem: _heure);
    _controleurMinutes = FixedExtentScrollController(initialItem: _minute ~/ _pasMinutes);
  }

  @override
  void dispose() {
    _controleurHeures.dispose();
    _controleurMinutes.dispose();
    super.dispose();
  }

  void _clic() {
    if (Reglages.vibrations) HapticFeedback.selectionClick();
  }

  Widget _roulette({
    required FixedExtentScrollController controleur,
    required int nombre,
    required int pas,
    required ValueChanged<int> onChange,
  }) {
    return SizedBox(
      width: 66,
      child: ListWheelScrollView.useDelegate(
        controller: controleur,
        itemExtent: _hauteurCase,
        diameterRatio: 1.8,
        perspective: 0.003,
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.32,
        useMagnifier: true,
        magnification: 1.12,
        onSelectedItemChanged: (index) {
          _clic();
          onChange(index % nombre * pas);
        },
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < nombre; i++)
              Center(
                child: Text(
                  (i * pas).toString().padLeft(2, '0'),
                  style: TytoText.ui(size: 23, weight: FontWeight.w700, color: TytoColors.encre),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unite = TytoText.ui(
      size: 15,
      weight: FontWeight.w700,
      color: TytoColors.encre.withOpacity(0.7),
    );
    return SizedBox(
      height: _hauteurCase * 3.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // La bande dorée qui marque la valeur choisie.
          IgnorePointer(
            child: Container(
              height: _hauteurCase,
              decoration: BoxDecoration(
                color: TytoColors.fauve.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TytoColors.fauve.withOpacity(0.5)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roulette(
                controleur: _controleurHeures,
                nombre: 24,
                pas: 1,
                onChange: (h) {
                  _heure = h;
                  widget.onChanged(_heure, _minute);
                },
              ),
              SizedBox(width: 26, child: Center(child: Text('h', style: unite))),
              _roulette(
                controleur: _controleurMinutes,
                nombre: 60 ~/ _pasMinutes,
                pas: _pasMinutes,
                onChange: (m) {
                  _minute = m;
                  widget.onChanged(_heure, _minute);
                },
              ),
              SizedBox(width: 38, child: Center(child: Text('min', style: unite))),
            ],
          ),
        ],
      ),
    );
  }
}
