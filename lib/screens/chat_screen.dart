import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../theme/background.dart';
import '../theme/typography.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/tyto_icons.dart';
import '../widgets/owl_sketch.dart';
import '../widgets/paw_trails.dart';
import '../widgets/voice_button.dart';
import 'emergency_sheet.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import 'placeholder_screen.dart';
import 'pets_screen.dart';
import 'carnet_screen.dart';
import 'tableau_screen.dart';
import 'veille_screen.dart';

/// L'écran de chat, maintenant relié à la vraie IA (même API que le site)
/// et au vrai statut Premium/Pro.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

const _suggestionPool = [
  "Mon chien a mangé du chocolat, c'est grave ?",
  "Pourquoi mon chat pétrit avec ses pattes ?",
  "Mon lapin ne mange plus depuis hier",
  "Que faire si je trouve un oiseau tombé du nid ?",
  "Mon chat est tombé du balcon, que faire ?",
  "Mon chien a mangé du raisin, c'est dangereux ?",
  "Ma tortue ne mange plus, est-ce grave ?",
  "Comment reconnaître un coup de chaleur chez le chien ?",
  "Ma perruche reste en boule, que faire ?",
  "Quels aliments sont toxiques pour un chat ?",
];

// Le petit encart "Le savais-tu ?" au-dessus du champ de saisie, comme sur
// le site — un fait amusant ou utile, qui change quand on tape dessus.
const _funFacts = [
  "Un chat ronronne aussi bien en inspirant qu'en expirant.",
  "Les chiens peuvent sentir une odeur environ 40 fois mieux qu'un humain.",
  "Les perruches peuvent apprendre plus de 100 mots.",
  "Un lapin a besoin de ronger en permanence : ses dents poussent toute sa vie.",
  "Les chats passent près de 70 % de leur vie à dormir.",
  "Une tortue peut retenir sa respiration plus d'une heure sous l'eau.",
  "Le cœur d'un chien bat entre 60 et 140 fois par minute selon sa taille.",
  "Les chats ont un troisième œil : la membrane nictitante, qui protège leur regard.",
];

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  StreamSubscription<AuthState>? _authSub;
  bool _peutRedescendre = false;
  final List<_Message> _thread = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;
  int? _remaining;
  bool _isPremium = false;
  bool _isPro = false;
  int _factIdx = 0;

  final List<int> _chipIdx = [0, 1, 2];
  final List<bool> _chipVisible = [true, true, true];
  final List<Timer?> _chipTimers = [null, null, null];

  static const _showDuration = Duration(milliseconds: 9500);
  static const _fadeDuration = Duration(milliseconds: 1100);
  static const _stagger = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600), // même durée que sosPulse
    )..repeat();
    _factIdx = DateTime.now().millisecond % _funFacts.length;
    _scheduleSlot(0, _showDuration);
    _scheduleSlot(1, _showDuration + _stagger);
    _scheduleSlot(2, _showDuration + _stagger * 2);
    _loadProfile();
    // Quand l'utilisateur se connecte (ou se déconnecte), son plan change :
    // sans ça, le badge resterait figé sur l'ancien statut.
    _authSub = AuthService.onAuthStateChange.listen((_) {
      if (mounted) _loadProfile();
    });
    // Quand la conversation est longue et qu'on est remonté la lire, un
    // bouton apparaît pour revenir en bas d'un geste.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final loinDuBas = _scrollController.position.maxScrollExtent -
              _scrollController.position.pixels >
          260;
      if (loinDuBas != _peutRedescendre) {
        setState(() => _peutRedescendre = loinDuBas);
      }
    });
  }

  void _nextFact() {
    setState(() => _factIdx = (_factIdx + 1) % _funFacts.length);
  }

  Future<void> _loadProfile() async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    final profile = await UserService.fetchMe(token);
    if (!mounted) return;
    setState(() {
      _isPremium = profile.premium;
      _isPro = profile.pro;
      _remaining = profile.remaining;
    });
  }

  void _scheduleSlot(int slot, Duration delay) {
    _chipTimers[slot] = Timer(delay, () {
      if (!mounted) return;
      setState(() => _chipVisible[slot] = false);
      _chipTimers[slot] = Timer(_fadeDuration, () {
        if (!mounted) return;
        setState(() {
          int candidate = (_chipIdx[slot] + 3) % _suggestionPool.length;
          int guard = 0;
          while (_chipIdx.contains(candidate) && guard < _suggestionPool.length) {
            candidate = (candidate + 1) % _suggestionPool.length;
            guard++;
          }
          _chipIdx[slot] = candidate;
          _chipVisible[slot] = true;
        });
        _scheduleSlot(slot, _showDuration);
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pulse.dispose();
    for (final t in _chipTimers) {
      t?.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion en cours, réessaie dans un instant.")),
      );
      return;
    }

    setState(() {
      _thread.add(_Message(role: 'user', content: text));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final messages = _thread.map((m) => {'role': m.role, 'content': m.content}).toList();
    final result = await ChatService.send(accessToken: token, messages: messages);

    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.isError) {
        _thread.add(_Message(role: 'assistant', content: _errorMessage(result.error!)));
      } else {
        _thread.add(_Message(role: 'assistant', content: result.text ?? ''));
        if (result.remaining != null) _remaining = result.remaining;
        if (result.premium != null) _isPremium = result.premium!;
      }
    });
    _scrollToBottom();
  }

  String _errorMessage(String error) {
    switch (error) {
      case 'quota':
        return "Tu as atteint la limite de questions gratuites pour aujourd'hui. Passe en Premium pour continuer sans limite.";
      case 'auth':
        return "Ta session a expiré, reconnecte-toi.";
      case 'network':
        return "Impossible de joindre Tyto pour l'instant — vérifie ta connexion et réessaie.";
      default:
        return "Une erreur est survenue, réessaie dans un instant.";
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetConversation() => setState(() => _thread.clear());

  void _openSos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const EmergencySheet(),
      ),
    );
  }

  void _onDrawerSelect(String id) {
    Navigator.pop(context);
    if (id == 'chat') return;
    Widget screen;
    switch (id) {
      case 'pets':
        screen = const PetsScreen();
        break;
      case 'carnet':
        screen = const CarnetScreen();
        break;
      case 'tableau':
        screen = const TableauScreen();
        break;
      case 'veille':
        screen = const VeilleScreen();
        break;
      default:
        screen = const PlaceholderScreen(title: 'Section');
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: TytoDrawer(activeId: 'chat', onSelect: _onDrawerSelect, isPro: _isPro, isPremium: _isPremium),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        title: Row(
          children: [
            OwlSketch(size: 22, thinking: _sending),
            const SizedBox(width: 8),
            Text('Tyto', style: TytoText.display(size: 19)),
            if (_isPro || _isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (_isPro ? TytoColors.vert : TytoColors.fauve).withOpacity(0.16),
                  border: Border.all(color: (_isPro ? TytoColors.vert : TytoColors.fauve).withOpacity(0.6)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isPro ? 'PRO' : 'PREMIUM',
                  style: TytoText.ui(size: 10, weight: FontWeight.w700, color: _isPro ? TytoColors.vert : TytoColors.fauve),
                ),
              ),
            ],
            const Spacer(),
            if (_thread.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: TytoColors.brume, size: 21),
                tooltip: 'Nouvelle conversation',
                onPressed: _resetConversation,
              ),
            // Le halo de l'urgence, repris de sosPulse dans globals.css :
            // un anneau qui s'écarte de 0 à 6 px en s'estompant, sur 2,6 s.
            // La couleur du bouton, elle, ne bouge pas.
            Padding(
              padding: const EdgeInsets.all(7),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  // Les étapes exactes de sosPulse :
                  //  0 % et 100 % → anneau à 0 px, opacité 0,5
                  //  50 %         → anneau à 6 px, opacité 0
                  final t = _pulse.value;
                  final double spread, opacity;
                  if (t < 0.5) {
                    final p = t * 2;
                    spread = 6 * p;
                    opacity = 0.5 * (1 - p);
                  } else {
                    final p = (t - 0.5) * 2;
                    spread = 6 * (1 - p);
                    opacity = 0.5 * p;
                  }
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC9553F).withOpacity(opacity),
                          blurRadius: 0,
                          spreadRadius: spread,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: TextButton.icon(
                  onPressed: _openSos,
                  icon: const Icon(Icons.warning_rounded, size: 14, color: Colors.white),
                  label: Text('URGENCE',
                      style: TytoText.ui(size: 11, weight: FontWeight.w700, color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: TytoColors.urgence,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: PawTrails()),
          Column(
        children: [
          if (_remaining != null && !_isPremium && !_isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_remaining question${_remaining! > 1 ? 's' : ''} gratuite${_remaining! > 1 ? 's' : ''} restante${_remaining! > 1 ? 's' : ''} aujourd\'hui',
                  style: TytoText.ui(size: 11.5, color: _remaining! <= 2 ? TytoColors.urgence : TytoColors.brume),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
            _thread.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _thread.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _thread.length) {
                        // "Tyto observe…" — la carte ivoire avec la chouette
                        // qui cligne vite, exactement comme sur le site.
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 7),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: TytoColors.papier,
                              border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                                bottomLeft: Radius.circular(4),
                              ),
                              boxShadow: const [
                                BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const OwlSketch(size: 15, ink: TytoColors.encre, detail: false, thinking: true),
                                const SizedBox(width: 9),
                                Text(
                                  'Tyto observe',
                                  style: TytoText.body(size: 15, color: TytoColors.encre)
                                      .copyWith(fontStyle: FontStyle.italic),
                                ),
                                _PointsAnimes(controller: _pulse),
                              ],
                            ),
                          ),
                        );
                      }
                      final m = _thread[i];
                      final isUser = m.role == 'user';

                      if (isUser) {
                        // La bulle de l'utilisateur : fond fauve translucide,
                        // liseré doré, coin bas-droit rentré.
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 7),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                            decoration: BoxDecoration(
                              color: TytoColors.fauve.withOpacity(0.14),
                              border: Border.all(color: TytoColors.fauve.withOpacity(0.4)),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                                bottomRight: Radius.circular(4),
                                bottomLeft: Radius.circular(14),
                              ),
                            ),
                            child: Text(
                              m.content,
                              style: TytoText.ui(size: 15, color: TytoColors.lune).copyWith(height: 1.45),
                            ),
                          ),
                        );
                      }

                      // La réponse de Tyto : la carte ivoire, avec son
                      // en-tête "TYTO" et la chouette.
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 7),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
                          decoration: BoxDecoration(
                            color: TytoColors.papier,
                            border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                              bottomLeft: Radius.circular(4),
                            ),
                            boxShadow: const [
                              BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const OwlSketch(size: 13, ink: TytoColors.encre, detail: false),
                                  const SizedBox(width: 7),
                                  Text(
                                    'TYTO',
                                    style: TytoText.ui(size: 10, weight: FontWeight.w700, color: TytoColors.encre.withOpacity(0.6))
                                        .copyWith(letterSpacing: 2.2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              _TexteRiche(texte: m.content),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                // Revenir au dernier message d'un geste, quand on est
                // remonté lire le début d'une longue conversation.
                if (_peutRedescendre)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: TytoColors.nuit2,
                          border: Border.all(color: TytoColors.fauve.withOpacity(0.55)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.arrow_downward_rounded,
                            size: 20, color: TytoColors.fauve),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TytoText.ui(color: TytoColors.lune),
                      decoration: InputDecoration(
                        hintText: 'Pose ta question à Tyto…',
                        hintStyle: TytoText.ui(color: TytoColors.brume),
                        filled: true,
                        fillColor: TytoColors.nuit2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Dicter sa question plutôt que la taper (fonction Pro).
                  if (_isPro)
                    VoiceButton(
                      size: 40,
                      title: 'Dicter ma question',
                      onText: (t) {
                        _controller.text = t;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                      },
                    ),
                  if (_isPro) const SizedBox(width: 6),
                  IconButton(
                    onPressed: _sending ? null : () => _sendMessage(),
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.nuit))
                        : const Icon(Icons.arrow_upward_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: TytoColors.fauve,
                      foregroundColor: TytoColors.nuit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OwlSketch(size: 64),
            const SizedBox(height: 18),
            Text(
              "Que veux-tu savoir sur les animaux\naujourd'hui ?",
              textAlign: TextAlign.center,
              style: TytoText.body(size: 16, color: TytoColors.brume),
            ),
            const SizedBox(height: 22),
            ...List.generate(_chipIdx.length, (slot) {
              final pIdx = _chipIdx[slot];
              return AnimatedOpacity(
                opacity: _chipVisible[slot] ? 1 : 0,
                duration: _fadeDuration,
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _sendMessage(_suggestionPool[pIdx]),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: TytoColors.lune.withOpacity(0.05),
                        side: BorderSide(color: TytoColors.lune.withOpacity(0.22)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 14, color: TytoColors.fauve),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _suggestionPool[pIdx],
                              style: TytoText.ui(size: 14, color: TytoColors.lune),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Les trois points de « Tyto observe… » : chacun s'allume à son tour,
/// avec le rythme exact de l'animation "dot" du site (cycle 1,3 s,
/// opacité 0,2 → 1, décalage de 0,2 s entre chaque point).
class _PointsAnimes extends StatelessWidget {
  final AnimationController controller;
  const _PointsAnimes({required this.controller});

  double _opacite(double t) {
    // 0 %, 60 % et 100 % -> 0,2   |   30 % -> 1
    if (t < 0.3) return 0.2 + 0.8 * (t / 0.3);
    if (t < 0.6) return 1 - 0.8 * ((t - 0.3) / 0.3);
    return 0.2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Le contrôleur tourne sur 2,6 s : on prend deux cycles de 1,3 s.
        final base = (controller.value * 2) % 1.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final decalage = i * (0.2 / 1.3); // 0,2 s de retard par point
            final t = (base - decalage) % 1.0;
            return Opacity(
              opacity: _opacite(t < 0 ? t + 1 : t),
              child: Text(
                '.',
                style: TytoText.body(size: 15, color: TytoColors.encre)
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Le texte de Tyto met certains passages en gras avec des **étoiles**.
/// On les affiche en gras plutôt que de laisser les étoiles apparentes.
class _TexteRiche extends StatelessWidget {
  final String texte;
  const _TexteRiche({required this.texte});

  @override
  Widget build(BuildContext context) {
    final morceaux = texte.split('**');
    return RichText(
      text: TextSpan(
        style: TytoText.body(size: 16.5, color: TytoColors.encre).copyWith(height: 1.55),
        children: [
          for (var i = 0; i < morceaux.length; i++)
            TextSpan(
              text: morceaux[i],
              style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
        ],
      ),
    );
  }
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}
