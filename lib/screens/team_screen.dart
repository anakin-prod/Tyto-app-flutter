import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/auth_service.dart';
import '../widgets/site_icons.dart';
import '../widgets/animaux_styles.dart';
import 'tableau_site.dart';

const _baseUrl = 'https://tytoai.app';

// Les teintes d'encre du site (ENCRE + "99", "aa", "88", "77", "33", "26", "14").
const _encre60 = Color(0x992A2118);
const _encre67 = Color(0xAA2A2118);
const _encre53 = Color(0x882A2118);
const _encre47 = Color(0x772A2118);
const _encre20 = Color(0x332A2118);
const _encre15 = Color(0x262A2118);
const _encre8 = Color(0x142A2118);
const _vertMessage = Color(0xFF2E6A55); // #2e6a55
const _rougeMessage = Color(0xFFAA3333); // #a33

/// Un nombre écrit comme le navigateur l'écrit : « 5 » et non « 5.0 ».
String _nb(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

num _num(Object? v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);

class _Ligne {
  final String id;
  final String email;
  const _Ligne(this.id, this.email);
}

class _Sieges {
  final num used;
  final num included;
  final num extra;
  final num prix;
  const _Sieges({required this.used, required this.included, required this.extra, required this.prix});
}

/// Ce que renvoie /api/team, lu exactement comme le site : les membres
/// actifs, les invitations en attente, et les sièges.
class _Equipe {
  final List<_Ligne> membres;
  final List<_Ligne> invitations;
  final _Sieges? sieges;
  const _Equipe({required this.membres, required this.invitations, this.sieges});

  static _Equipe? lire(Object? d) {
    if (d is! Map) return null;
    List<_Ligne> liste(Object? l) => l is List
        ? l.whereType<Map>().map((m) => _Ligne(m['id']?.toString() ?? '', m['email']?.toString() ?? '')).toList()
        : <_Ligne>[];
    final s = d['seats'];
    return _Equipe(
      membres: liste(d['members']),
      invitations: liste(d['invites']),
      sieges: s is Map
          ? _Sieges(
              used: _num(s['used']),
              included: _num(s['included']),
              extra: _num(s['extra']),
              prix: _num(s['extraPriceEur']),
            )
          : null,
    );
  }
}

class _Message {
  final bool ok;
  final String texte;
  final String? lien;
  const _Message(this.ok, this.texte, {this.lien});
}

/// Fonction Pro : inviter des soigneurs à partager le carnet des animaux.
/// Même fenêtre « Équipe » que sur le site : une carte papier centrée sur
/// un voile sombre, qui se ferme par la croix ou en touchant à côté.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  /// Ouvre la fenêtre par-dessus l'écran courant, comme sur le site (le
  /// voile laisse deviner la page derrière).
  static Future<void> ouvrir(BuildContext context) {
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => const TeamScreen(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _email = TextEditingController();
  late final TapGestureRecognizer _lienCgv = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.parse('$_baseUrl/cgv-pro'), mode: LaunchMode.externalApplication);

  bool _chargement = true;
  bool _membre = false; // soigneur invité dans l'équipe de quelqu'un d'autre
  String? _titulaire;
  _Equipe? _equipe;
  bool _envoi = false;
  _Message? _message;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _email.dispose();
    _lienCgv.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }
    // Comme le site : un soigneur invité voit sa propre vue (quitter
    // l'équipe) ; le titulaire voit ses sièges, ses membres, ses invitations.
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final team = d is Map ? d['team'] : null;
        if (team is Map && team['isMember'] == true) {
          if (!mounted) return;
          setState(() {
            _membre = true;
            _titulaire = team['ownerEmail']?.toString();
            _chargement = false;
          });
          return;
        }
      }
    } catch (_) {}
    final equipe = await _lireEquipe(token);
    if (!mounted) return;
    setState(() {
      _equipe = equipe;
      _chargement = false;
    });
  }

  Future<_Equipe?> _lireEquipe(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/team'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return null;
      return _Equipe.lire(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  Future<void> _rafraichir() async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    final equipe = await _lireEquipe(token);
    if (!mounted || equipe == null) return;
    setState(() => _equipe = equipe);
  }

  Future<void> _inviter() async {
    final email = _email.text.trim();
    if (email.isEmpty || _envoi) return;
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;

    setState(() {
      _envoi = true;
      _message = null;
    });

    _Message? message;
    _Equipe? equipe;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/team'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'email': email}),
      );
      Object? d;
      try {
        d = jsonDecode(res.body);
      } catch (_) {
        d = null;
      }
      final Map<dynamic, dynamic> r = d is Map ? d : <dynamic, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _email.clear();
        message = r['emailSent'] == true
            ? _Message(true, 'Invitation envoyée à $email')
            : _Message(
                true,
                "Invitation créée, mais l'email n'a pas pu être envoyé automatiquement.",
                lien: r['inviteUrl']?.toString(),
              );
        equipe = await _lireEquipe(token);
      } else {
        final code = r['error'];
        message = _Message(
          false,
          code == 'self_invite'
              ? "Tu ne peux pas t'inviter toi-même."
              : code == 'bad_email'
                  ? 'Adresse email invalide.'
                  : code == 'seats_apple_full'
                      ? 'Ton abonnement inclut 2 places (toi compris) : elles sont toutes prises ou réservées.'
                      : "L'invitation n'a pas pu être envoyée.",
        );
      }
    } catch (_) {
      message = const _Message(false, "L'invitation n'a pas pu être envoyée.");
    }
    if (!mounted) return;
    setState(() {
      _envoi = false;
      _message = message;
      if (equipe != null) _equipe = equipe;
    });
  }

  Future<bool> _confirmer(String question, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        surfaceTintColor: Colors.transparent,
        title: Text(question, style: TytoText.display(size: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: TytoText.ui(color: TytoColors.urgence, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _post(String chemin, Map<String, dynamic> corps) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl$chemin'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(corps),
      );
    } catch (_) {}
  }

  Future<void> _retirer(_Ligne m) async {
    if (!await _confirmer("Retirer ce soigneur de l'équipe ?", 'Retirer')) return;
    await _post('/api/team/remove', {'memberId': m.id});
    await _rafraichir();
  }

  Future<void> _annulerInvitation(_Ligne i) async {
    await _post('/api/team/remove', {'inviteId': i.id});
    await _rafraichir();
  }

  Future<void> _quitter() async {
    if (!await _confirmer('Quitter cette équipe ? Tu ne verras plus ses animaux ni son carnet.', 'Quitter')) return;
    await _post('/api/team/leave', {});
    if (mounted) Navigator.of(context).maybePop();
  }

  void _fermer() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final hauteurEcran = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Le voile du site : rgba(10,14,24,0.8). Un toucher à côté referme.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fermer,
        child: Container(
          color: const Color(0xCC0A0E18),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, contraintes) {
                final dispo = contraintes.maxHeight - 32;
                final maxHauteur = hauteurEcran * 0.85 < dispo ? hauteurEcran * 0.85 : dispo;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      // Un toucher dans la carte ne la referme pas.
                      onTap: () {},
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 460, maxHeight: maxHauteur < 0 ? 0 : maxHauteur),
                        child: Container(
                          // paperCard du site (flou CSS de 14 px = 11,3 ici) ;
                          // le contenu qui défile reste dans l'arrondi.
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            color: TytoColors.papier,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            border: Border.fromBorderSide(BorderSide(color: _encre15)),
                            boxShadow: [BoxShadow(color: Color(0x47000000), blurRadius: 11.3, offset: Offset(0, 3))],
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: _contenu(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenu() {
    // Les marges verticales du site se chevauchent (la plus grande des deux
    // l'emporte) : on reproduit ce calcul en empilant les éléments.
    final enfants = <Widget>[];
    double margeEnAttente = 0;
    void ajouter(Widget w, {double haut = 0, double bas = 0}) {
      final ecart = haut > margeEnAttente ? haut : margeEnAttente;
      if (ecart > 0) enfants.add(SizedBox(height: ecart));
      enfants.add(w);
      margeEnAttente = bas;
    }

    ajouter(_entete(), bas: 12);

    if (_membre) {
      ajouter(
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: "Tu fais partie de l'équipe de "),
            TextSpan(
              text: (_titulaire == null || _titulaire!.isEmpty) ? 'ton titulaire' : _titulaire!,
              style: GoogleFonts.newsreader(fontSize: 15.5, fontWeight: FontWeight.w700, color: TytoColors.encre),
            ),
            const TextSpan(text: '. Tu vois et modifies les mêmes compagnons, le même carnet et les mêmes outils Pro.'),
          ]),
          style: interligne(TytoText.body(size: 15.5, color: TytoColors.encre), 1.6),
        ),
        bas: 16,
      );
      ajouter(
        GestureDetector(
          onTap: _quitter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x77C9553F)),
            ),
            child: Text('Quitter cette équipe',
                style: karla(13.5, poids: FontWeight.w700, couleur: TytoColors.urgence)),
          ),
        ),
      );
    } else if (_chargement) {
      ajouter(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('Chargement…', style: karla(16, couleur: _encre53)),
          ),
        ),
      );
    } else {
      _vueTitulaire(ajouter);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: enfants,
    );
  }

  Widget _entete() {
    return Row(
      children: [
        const SiteIcon('IconTeam', size: 18, color: TytoColors.encre),
        const SizedBox(width: 8),
        Expanded(child: Text('Équipe', style: fraunces(19))),
        const SizedBox(width: 8),
        CroixFermerAnimaux(onTap: _fermer),
      ],
    );
  }

  void _vueTitulaire(void Function(Widget w, {double haut, double bas}) ajouter) {
    final eq = _equipe;
    final s = eq?.sieges;
    final vide = _email.text.trim().isEmpty;
    final grise = vide || _envoi;
    final gras = TytoText.ui(size: 13, weight: FontWeight.w700, color: TytoColors.encre);

    if (s != null) {
      ajouter(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x1A7FB2A6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x557FB2A6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: _nb(s.used), style: gras),
                  TextSpan(text: ' / ${_nb(s.included)} sièges inclus'),
                  if (s.extra > 0) ...[
                    const TextSpan(text: ' — '),
                    TextSpan(text: _nb(s.extra), style: gras),
                    TextSpan(
                      text: ' siège${s.extra > 1 ? 's' : ''} supplémentaire${s.extra > 1 ? 's' : ''} '
                          '(+${_nb(s.extra * s.prix)} €/mois, ajusté automatiquement sur ta facture)',
                    ),
                  ],
                ]),
                style: interligne(TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.encre), 1.5),
              ),
              if (s.extra == 0 && s.used >= s.included)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Opacity(
                    opacity: 0.85,
                    child: Text(
                      'Tu peux continuer à inviter : chaque soigneur au-delà ajoute ${_nb(s.prix)} €/mois, '
                      'ajusté automatiquement sur ta facture.',
                      style: interligne(
                        TytoText.ui(size: 11.5, weight: FontWeight.w400, color: TytoColors.encre),
                        1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bas: 14,
      );
    }

    // labelStyle du site
    ajouter(
      Text(
        'INVITER UN SOIGNEUR',
        style: karla(11, poids: FontWeight.w700, couleur: _encre60).copyWith(letterSpacing: 0.88),
      ),
      haut: 10,
      bas: 4,
    );

    OutlineInputBorder bord(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    ajouter(
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _inviter(),
              onChanged: (_) => setState(() {}),
              cursorColor: TytoColors.encre,
              style: karla(14.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'email@exemple.fr',
                hintStyle: karla(14.5, couleur: const Color(0xFF757575)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: bord(_encre20, 1),
                enabledBorder: bord(_encre20, 1),
                focusedBorder: bord(TytoColors.fauve, 2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TableauBouton(
            onTap: grise ? null : _inviter,
            opacite: grise ? 0.5 : 1,
            echellePresse: 0.98,
            fond: TytoColors.fauve,
            hauteur: 39,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              _envoi ? '…' : 'Inviter',
              style: karla(13.5, poids: FontWeight.w700, couleur: TytoColors.nuit),
            ),
          ),
        ],
      ),
      bas: 6,
    );

    final msg = _message;
    if (msg != null) {
      final couleur = msg.ok ? _vertMessage : _rougeMessage;
      final lien = msg.lien ?? '';
      ajouter(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.texte, style: karla(12.5, couleur: couleur)),
            if (lien.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x08000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Envoie ce lien toi-même (WhatsApp, SMS…) :',
                        style: karla(11, couleur: _encre53)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(lien,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontFamilyFallback: const ['Menlo', 'Courier'],
                                fontSize: 11.5,
                                color: couleur,
                              )),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => Clipboard.setData(ClipboardData(text: lien)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: TytoColors.fauve,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Copier',
                                style: styleSysteme(context, size: 11, weight: FontWeight.w700, color: TytoColors.nuit)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        bas: 10,
      );
    }

    if (eq != null && eq.membres.isNotEmpty) {
      ajouter(_titreSection('MEMBRES ACTIFS'), haut: 16, bas: 8);
      for (final m in eq.membres) {
        ajouter(_ligne(
          Text(m.email, style: karla(14)),
          'Retirer',
          () => _retirer(m),
        ));
      }
    }

    if (eq != null && eq.invitations.isNotEmpty) {
      ajouter(_titreSection('INVITATIONS EN ATTENTE'), haut: 16, bas: 8);
      for (final i in eq.invitations) {
        ajouter(_ligne(
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${i.email} '),
              const TextSpan(text: '(en attente)', style: TextStyle(fontSize: 11)),
            ]),
            style: karla(14, couleur: _encre67),
          ),
          'Annuler',
          () => _annulerInvitation(i),
        ));
      }
    }

    ajouter(
      Text.rich(
        TextSpan(children: [
          const TextSpan(
            text: 'Chaque soigneur invité voit les mêmes compagnons et le même carnet que toi, et profite '
                "du plan Pro de l'équipe. Un compte reste personnel : voir les ",
          ),
          TextSpan(
            text: 'CGV professionnelles',
            style: const TextStyle(
              color: _encre67,
              decoration: TextDecoration.underline,
              decorationColor: _encre67,
            ),
            recognizer: _lienCgv,
          ),
          const TextSpan(text: '.'),
        ]),
        style: interligne(TytoText.ui(size: 11, weight: FontWeight.w400, color: _encre47), 1.4),
      ),
      haut: 16,
    );
  }

  Widget _titreSection(String texte) => Text(
        texte,
        style: karla(11, poids: FontWeight.w700, couleur: _encre47).copyWith(letterSpacing: 1.1),
      );

  /// Une ligne de la liste : l'adresse, puis l'action soulignée en rouge.
  Widget _ligne(Widget texte, String action, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _encre8)),
      ),
      child: Row(
        children: [
          Expanded(child: texte),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              // Bouton sans police précisée sur le site : police du système.
              child: Text(
                action,
                style: styleSysteme(context, size: 12.5, color: TytoColors.urgence).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: TytoColors.urgence,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
