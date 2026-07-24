import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../models/pet.dart';
import '../models/health_event.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/account_gate.dart';
import '../widgets/tyto_icons.dart';

class VeilleScreen extends StatefulWidget {
  const VeilleScreen({super.key});

  @override
  State<VeilleScreen> createState() => _VeilleScreenState();
}

class _VeilleScreenState extends State<VeilleScreen> {
  bool _loading = true;
  bool _running = false;
  List<Pet> _pets = [];
  String? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final pets = await DataService.loadPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Une analyse honnête, basée sur les vraies données : on ne prétend pas
  /// que "tout va bien" sans avoir rien regardé.
  Future<void> _runWatch() async {
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final upcoming = await DataService.loadUpcoming();
      final now = DateTime.now();
      final urgent = upcoming.where((e) => e.nextDue!.difference(now).inDays <= 14).toList();

      String text;
      if (upcoming.isEmpty) {
        text = "Aucun rappel n'est programmé pour tes compagnons. "
            "Pense à noter les vaccins et vermifuges dans le carnet de santé : "
            "Tyto pourra alors te prévenir avant chaque échéance.";
      } else if (urgent.isEmpty) {
        text = "Rien d'urgent dans les deux prochaines semaines. "
            "${upcoming.length} rappel${upcoming.length > 1 ? 's sont programmés' : ' est programmé'} plus tard — "
            "tu peux les retrouver dans le tableau des rappels.";
      } else {
        final lignes = urgent.map((e) => _describe(e, now)).join('\n');
        text = "${urgent.length} point${urgent.length > 1 ? 's demandent' : ' demande'} ton attention :\n\n$lignes";
      }

      if (!mounted) return;
      setState(() {
        _running = false;
        _result = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = "L'analyse n'a pas abouti. Vérifie ta connexion et réessaie.";
      });
    }
  }

  String _describe(HealthEvent e, DateTime now) {
    final days = e.nextDue!.difference(now).inDays;
    final quand = days < 0
        ? 'en retard'
        : days == 0
            ? "aujourd'hui"
            : 'dans $days jour${days > 1 ? 's' : ''}';
    final nom = _pets.where((p) => p.id == e.petId).map((p) => p.name).join();
    final sujet = nom.isEmpty ? '' : '$nom — ';
    return '• $sujet${_typeLabel(e.type)} $quand';
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'vaccin':
        return 'rappel de vaccin';
      case 'vermifuge':
        return 'vermifuge à renouveler';
      case 'visite':
        return 'visite à prévoir';
      case 'traitement':
        return 'traitement à renouveler';
      default:
        return 'rappel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(title: Text('Veille sanitaire', style: TytoText.display(size: 19))),
      body: !AuthService.isSignedIn
          ? const AccountGate()
          : _loading
          ? const Center(child: CircularProgressIndicator(color: TytoColors.fauve))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  TytoIcon.monitor(size: 46, color: TytoColors.fauve),
                  const SizedBox(height: 18),
                  Text(
                    _pets.isEmpty
                        ? "Ajoute d'abord un compagnon dans « Mes animaux » :\nTyto pourra ensuite veiller sur sa santé au quotidien."
                        : "L'analyse quotidienne passe en revue la santé de tes compagnons.",
                    textAlign: TextAlign.center,
                    style: TytoText.body(size: 15, color: TytoColors.brume),
                  ),
                  const SizedBox(height: 26),
                  if (_pets.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _running ? null : _runWatch,
                        icon: _running
                            ? const SizedBox(
                                height: 16, width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit))
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _running ? 'Tyto examine tes animaux…' : 'Lancer la veille du jour',
                          style: TytoText.ui(weight: FontWeight.w700, color: TytoColors.nuit),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TytoColors.fauve,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  if (_result != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TytoColors.nuit2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TytoColors.fauve.withOpacity(0.3)),
                      ),
                      child: Text(_result!, style: TytoText.body(size: 14)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
