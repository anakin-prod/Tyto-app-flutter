import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class VeilleScreen extends StatefulWidget {
  const VeilleScreen({super.key});

  @override
  State<VeilleScreen> createState() => _VeilleScreenState();
}

class _VeilleScreenState extends State<VeilleScreen> {
  bool _loading = false;
  String? _result;

  Future<void> _runWatch() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = "Tout va bien pour tes compagnons aujourd'hui — rien à signaler.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TytoColors.nuit,
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        title: Text('Veille sanitaire', style: TytoText.display(size: 19)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monitor_heart_rounded, size: 52, color: TytoColors.fauve),
            const SizedBox(height: 18),
            Text(
              "L'analyse quotidienne passe en revue la santé de tes compagnons.",
              textAlign: TextAlign.center,
              style: TytoText.body(size: 15, color: TytoColors.brume),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _runWatch,
                icon: _loading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _loading ? 'Tyto examine tes animaux…' : 'Lancer la veille du jour',
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TytoColors.nuit2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TytoColors.fauve.withOpacity(0.3)),
                ),
                child: Text(_result!, style: TytoText.body(size: 14), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
