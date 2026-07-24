import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_drawer.dart';
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

class _ChatScreenState extends State<ChatScreen> {
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
    _factIdx = DateTime.now().millisecond % _funFacts.length;
    _scheduleSlot(0, _showDuration);
    _scheduleSlot(1, _showDuration + _stagger);
    _scheduleSlot(2, _showDuration + _stagger * 2);
    _loadProfile();
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        title: Text('Urgence', style: TytoText.display(size: 18)),
        content: Text(
          "L'écran d'urgence détaillé arrivera à une prochaine étape.",
          style: TytoText.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TytoText.ui(color: TytoColors.fauve)),
          ),
        ],
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
      backgroundColor: TytoColors.nuit,
      drawer: TytoDrawer(activeId: 'chat', onSelect: _onDrawerSelect, isPro: _isPro, isPremium: _isPremium),
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        titleSpacing: 4,
        title: Row(
          children: [
            Image.asset('assets/images/owl.png', width: 26, height: 26),
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
            TextButton.icon(
              onPressed: _openSos,
              icon: const Icon(Icons.warning_rounded, size: 14, color: Colors.white),
              label: Text('URGENCE', style: TytoText.ui(size: 11, weight: FontWeight.w700, color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: TytoColors.urgence,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ],
        ),
      ),
      body: Column(
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
            child: _thread.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _thread.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _thread.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: TytoColors.nuit2, borderRadius: BorderRadius.circular(14)),
                            child: const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.fauve),
                            ),
                          ),
                        );
                      }
                      final m = _thread[i];
                      final isUser = m.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser ? TytoColors.fauve.withOpacity(0.18) : TytoColors.nuit2,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(m.content, style: TytoText.body(size: 15)),
                        ),
                      );
                    },
                  ),
          ),
          GestureDetector(
            onTap: _nextFact,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: TytoColors.nuit2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TytoColors.lune.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: TytoColors.fauve),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Le savais-tu ? ${_funFacts[_factIdx]}',
                      style: TytoText.ui(size: 12.5, color: TytoColors.brume),
                    ),
                  ),
                ],
              ),
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
                  const SizedBox(width: 8),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/owl.png', width: 70, height: 70),
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

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}
