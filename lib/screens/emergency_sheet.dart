import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../services/emergency_service.dart';
import '../widgets/fenetre_papier.dart';

/// L'écran d'urgence, repris du site : on décrit ce qui se passe, Tyto
/// analyse et classe la gravité (vitale / aujourd'hui / à surveiller),
/// on peut répondre à ses questions, et trouver un vétérinaire de garde
/// à tout moment.
class EmergencySheet extends StatefulWidget {
  final String? petId;
  final String? petName;
  final double? petWeight;

  const EmergencySheet({super.key, this.petId, this.petName, this.petWeight});

  /// Ouvre la fenêtre par-dessus l'écran courant, comme le voile du site
  /// (la page reste devinée derrière).
  static Future<void> ouvrir(BuildContext context, {String? petId, String? petName, double? petWeight}) {
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => EmergencySheet(petId: petId, petName: petName, petWeight: petWeight),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  final _controller = TextEditingController();
  final _reponse = TextEditingController();
  bool _loading = false;
  EmergencyResult? _result;
  // L'échange en cours, renvoyé au serveur quand on répond à Tyto.
  List<Map<String, String>> _historique = [];

  static const _texteEchec = "La connexion a échoué. **N'attends pas** : appelle immédiatement ton vétérinaire "
      'ou la clinique vétérinaire de garde la plus proche.';

  @override
  void dispose() {
    _controller.dispose();
    _reponse.dispose();
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
      if (r.isError) {
        // Comme sur le site : en cas d'échec, on pousse à appeler sans attendre.
        _result = EmergencyResult(gravity: 'URGENT', text: _texteEchec);
        _historique = [];
      } else {
        _result = r;
        _historique = [
          {'role': 'user', 'content': desc},
          {'role': 'assistant', 'content': r.text ?? ''},
        ];
      }
    });
  }

  /// Répondre à une question posée par Tyto pendant l'urgence, sans
  /// perdre le contexte de l'échange (même route, avec l'historique).
  Future<void> _repondre() async {
    final rep = _reponse.text.trim();
    if (rep.isEmpty || _loading) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() => _loading = true);
    EmergencyResult? r;
    try {
      final res = await http.post(
        Uri.parse('https://tytoai.app/api/emergency'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'description': rep, 'petId': widget.petId, 'history': _historique}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data is Map && data['text'] is String) {
        r = EmergencyResult(
          text: data['text'] as String,
          gravity: data['gravity'] is String ? data['gravity'] as String : 'SURVEILLER',
        );
      }
    } catch (e) {
      r = null;
    }
    if (!mounted) return;
    if (r == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La connexion a échoué. Réessaie, ou appelle directement un vétérinaire.')),
      );
      return;
    }
    final suite = r;
    setState(() {
      _loading = false;
      _result = suite;
      _historique = [
        ..._historique,
        {'role': 'user', 'content': rep},
        {'role': 'assistant', 'content': suite.text ?? ''},
      ];
      _reponse.clear();
    });
  }

  void _decrireAutreChose() {
    setState(() {
      _result = null;
      _controller.clear();
      _historique = [];
      _reponse.clear();
    });
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

  /// Le poids tel que le site l'affiche : « 4.2 », « 23 ».
  String _poids(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le voile du site : rgba(10,14,24,0.93)
      backgroundColor: const Color(0xED0A0E18),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: math.max(0.0, contraintes.maxHeight - 32)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _entete(),
                      const SizedBox(height: 12),
                      if (_result == null) _buildForm() else ..._buildResult(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entete() {
    return Row(
      children: [
        const IconeTrait.alerte(size: 22, color: TytoColors.lune),
        const SizedBox(width: 9),
        Expanded(
          child: Text('Urgence', style: TytoText.display(size: 24, color: TytoColors.lune)),
        ),
        const SizedBox(width: 10),
        BoutonPilule(
          texte: 'Fermer',
          onTap: () => Navigator.pop(context),
          bord: const Color(0x40EDE7D6),
          encre: TytoColors.lune,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          taille: 12.5,
          gras: false,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final introStyle = TytoText.ui(size: 13, weight: FontWeight.w400, color: encreA(0xAA))
        .copyWith(height: 1.45, leadingDistribution: TextLeadingDistribution.even);
    final pret = _controller.text.trim().isNotEmpty && !_loading;
    return FenetrePapier(
      lisere: TytoColors.urgence,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.petName != null
              ? Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Pour '),
                    TextSpan(
                      text: widget.petName,
                      style: TytoText.ui(size: 13, weight: FontWeight.w700, color: encreA(0xAA))
                          .copyWith(height: 1.45, leadingDistribution: TextLeadingDistribution.even),
                    ),
                    TextSpan(
                      text: (widget.petWeight != null && widget.petWeight! > 0
                              ? ' — ${_poids(widget.petWeight!)} kg'
                              : '') +
                          ' — Tyto connaît déjà son âge, son poids et ses antécédents. Décris seulement ce qui se passe.',
                    ),
                  ]),
                  style: introStyle,
                )
              : Text(
                  "Décris ce qui se passe. Précise l'espèce et le poids approximatif de l'animal.",
                  style: introStyle,
                ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 4,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: TytoText.ui(size: 15, weight: FontWeight.w400, color: TytoColors.encre)
                .copyWith(height: 1.5, leadingDistribution: TextLeadingDistribution.even),
            decoration: decorationChampPapier(
              indication: 'Ex : il a mangé du chocolat il y a 20 minutes / il respire mal / il saigne beaucoup…',
              taille: 15,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              hauteurLigne: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          BoutonPilule(
            texte: _loading ? 'Tyto analyse…' : 'Aide-moi maintenant',
            onTap: _send,
            actif: pret,
            fond: TytoColors.urgence,
            encre: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            taille: 15,
          ),
          const SizedBox(height: 8),
          BoutonPilule(
            texte: 'Trouver un vétérinaire ouvert près de moi',
            onTap: EmergencyService.findVet,
            bord: const Color(0x332A2118),
            encre: TytoColors.encre,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            taille: 13.5,
            icone: const IconeTrait.croix(size: 15, color: TytoColors.encre),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResult() {
    final g = _result!.gravity ?? 'SURVEILLER';
    final peutRepondre = _reponse.text.trim().isNotEmpty && !_loading;
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _gravityColor(g),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(_gravityTitle(g), textAlign: TextAlign.center, style: TytoText.display(size: 20, color: Colors.white)),
            const SizedBox(height: 3),
            Text(
              _gravitySub(g),
              textAlign: TextAlign.center,
              style: TytoText.ui(size: 13, weight: FontWeight.w400, color: Colors.white.withOpacity(0.95))
                  .copyWith(height: 1.4, leadingDistribution: TextLeadingDistribution.even),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      BoutonPilule(
        texte: 'Vétérinaire ouvert près de moi',
        onTap: EmergencyService.findVet,
        fond: Colors.white,
        encre: TytoColors.urgence,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        taille: 15,
        icone: const IconeTrait.croix(size: 16, color: TytoColors.urgence),
      ),
      const SizedBox(height: 12),
      FenetrePapier(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RichAdvice(text: _result!.text ?? ''),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x1A2A2118))),
              ),
              child: Text(
                "Tyto n'est pas vétérinaire. Ces conseils ne remplacent jamais un examen par un professionnel.",
                style: TytoText.ui(size: 11.5, weight: FontWeight.w400, color: encreA(0x88))
                    .copyWith(height: 1.45, leadingDistribution: TextLeadingDistribution.even),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // align-items: stretch du site : « Répondre » prend la hauteur du champ.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _reponse,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _repondre(),
                textInputAction: TextInputAction.send,
                style: TytoText.ui(size: 14.5, weight: FontWeight.w400, color: TytoColors.encre),
                decoration: decorationChampPapier(
                  indication: 'Réponds à Tyto ici…',
                  taille: 14.5,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  rayon: 999,
                ),
              ),
            ),
            const SizedBox(width: 8),
            BoutonPilule(
              texte: _loading ? '…' : 'Répondre',
              onTap: _repondre,
              actif: peutRepondre,
              fond: TytoColors.urgence,
              encre: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              taille: 14,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: BoutonPilule(
              texte: 'Décrire autre chose',
              onTap: _decrireAutreChose,
              bord: const Color(0x40EDE7D6),
              encre: TytoColors.lune,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              taille: 13.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BoutonPilule(
              texte: 'Fermer',
              onTap: () => Navigator.pop(context),
              bord: const Color(0x40EDE7D6),
              encre: TytoColors.lune,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              taille: 13.5,
            ),
          ),
        ],
      ),
    ];
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
        style: TytoText.body(size: 16, color: TytoColors.encre)
            .copyWith(height: 1.7, leadingDistribution: TextLeadingDistribution.even),
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              // <strong> du site : le vrai Newsreader gras, pas un gras simulé.
              style: i.isOdd
                  ? GoogleFonts.newsreader(fontSize: 16, fontWeight: FontWeight.w700, color: TytoColors.encre)
                      .copyWith(height: 1.7, leadingDistribution: TextLeadingDistribution.even)
                  : null,
            ),
        ],
      ),
    );
  }
}
