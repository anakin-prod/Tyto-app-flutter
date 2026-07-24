import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/emergency_service.dart';

/// L'écran d'urgence, repris du site : on décrit ce qui se passe, Tyto
/// analyse et classe la gravité (vitale / aujourd'hui / à surveiller),
/// et on peut trouver un vétérinaire de garde à tout moment.
class EmergencySheet extends StatefulWidget {
  final String? petId;
  final String? petName;
  final double? petWeight;

  const EmergencySheet({super.key, this.petId, this.petName, this.petWeight});

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  EmergencyResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final desc = _controller.text.trim();
    if (desc.isEmpty || _loading) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _loading = true;
      _result = null;
    });
    final r = await EmergencyService.analyse(
      accessToken: token,
      description: desc,
      petId: widget.petId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = r.isError ? null : r;
    });
    if (r.isError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'analyse n'a pas abouti. Vérifie ta connexion et réessaie.")),
      );
    }
  }

  Color _gravityColor(String g) {
    switch (g) {
      case 'VITAL':
        return TytoColors.urgence;
      case 'URGENT':
        return const Color(0xFFC98A55);
      default:
        return TytoColors.vert;
    }
  }

  String _gravityTitle(String g) {
    switch (g) {
      case 'VITAL':
        return 'URGENCE VITALE';
      case 'URGENT':
        return "À VOIR AUJOURD'HUI";
      default:
        return 'À SURVEILLER';
    }
  }

  String _gravitySub(String g) {
    switch (g) {
      case 'VITAL':
        return 'Pars chez le vétérinaire MAINTENANT — préviens la clinique pendant le trajet.';
      case 'URGENT':
        return "Contacte un vétérinaire aujourd'hui.";
      default:
        return "Pas d'urgence immédiate, mais reste vigilant.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xEE0A0E18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, size: 20, color: TytoColors.lune),
            const SizedBox(width: 9),
            Text('Urgence', style: TytoText.display(size: 22)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                side: BorderSide(color: TytoColors.lune.withOpacity(0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text('Fermer', style: TytoText.ui(size: 12.5, color: TytoColors.lune)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: _result == null ? _buildForm() : _buildResult(),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1E7),
        borderRadius: BorderRadius.circular(14),
        border: const Border(top: BorderSide(color: TytoColors.urgence, width: 4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.petName != null
                ? "Pour ${widget.petName}${widget.petWeight != null ? ' — ${widget.petWeight} kg' : ''} — Tyto connaît déjà son âge, son poids et ses antécédents. Décris seulement ce qui se passe."
                : "Décris ce qui se passe. Précise l'espèce et le poids approximatif de l'animal.",
            style: TytoText.ui(size: 13, color: const Color(0xAA2A2118)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            style: TytoText.ui(size: 15, color: const Color(0xFF2A2118)),
            decoration: InputDecoration(
              hintText: "Ex : il a mangé du chocolat il y a 20 minutes / il respire mal / il saigne beaucoup…",
              hintStyle: TytoText.ui(size: 14, color: const Color(0x772A2118)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332A2118)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332A2118)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: TytoColors.urgence,
                disabledBackgroundColor: TytoColors.urgence.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(
                _loading ? 'Tyto analyse…' : 'Aide-moi maintenant',
                style: TytoText.ui(size: 15, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: EmergencyService.findVet,
              icon: const Icon(Icons.local_hospital_outlined, size: 15, color: Color(0xFF2A2118)),
              label: Text(
                'Trouver un vétérinaire ouvert près de moi',
                style: TytoText.ui(size: 13.5, weight: FontWeight.w700, color: const Color(0xFF2A2118)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0x332A2118)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final g = _result!.gravity!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _gravityColor(g),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(_gravityTitle(g),
                  textAlign: TextAlign.center,
                  style: TytoText.display(size: 20, color: Colors.white)),
              const SizedBox(height: 3),
              Text(_gravitySub(g),
                  textAlign: TextAlign.center,
                  style: TytoText.ui(size: 13, color: Colors.white.withOpacity(0.95))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: EmergencyService.findVet,
            icon: const Icon(Icons.local_hospital_rounded, size: 16, color: TytoColors.urgence),
            label: Text('Vétérinaire ouvert près de moi',
                style: TytoText.ui(size: 15, weight: FontWeight.w700, color: TytoColors.urgence)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F1E7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RichAdvice(text: _result!.text!),
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0x1A2A2118)),
              const SizedBox(height: 10),
              Text(
                "Tyto n'est pas vétérinaire. Ces conseils ne remplacent jamais un examen par un professionnel.",
                style: TytoText.ui(size: 11.5, color: const Color(0x882A2118)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _result = null;
              _controller.clear();
            }),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: TytoColors.lune.withOpacity(0.25)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text('Décrire une autre situation', style: TytoText.ui(color: TytoColors.lune)),
          ),
        ),
      ],
    );
  }
}

/// Le texte de Tyto met certains passages en gras avec des **étoiles**,
/// comme sur le site : on les affiche en gras plutôt qu'en brut.
class _RichAdvice extends StatelessWidget {
  final String text;
  const _RichAdvice({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    return RichText(
      text: TextSpan(
        style: TytoText.body(size: 16, color: const Color(0xFF2A2118)).copyWith(height: 1.7),
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
        ],
      ),
    );
  }
}
