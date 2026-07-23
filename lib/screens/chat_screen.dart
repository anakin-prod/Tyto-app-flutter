import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_drawer.dart';
import 'placeholder_screen.dart';
import 'pets_screen.dart';
import 'carnet_screen.dart';
import 'tableau_screen.dart';
import 'veille_screen.dart';

/// L'écran de chat, dans le même esprit que celui du site : en-tête avec
/// le bouton urgence et le rafraîchissement, questions suggérées qui
/// tournent lentement, bulles de conversation. L'appel réel à l'IA (et
/// le vrai statut Premium/Pro) arriveront à l'étape suivante — pour
/// l'instant, la réponse est un texte provisoire.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Le même pool de questions que sur le site (cas "sans animal actif").
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

class _ChatScreenState extends State<ChatScreen> {
  final List<_Message> _thread = [];
  final _controller = TextEditingController();

  // Rotation des 3 puces de suggestion, comme sur le site : chacune à son
  // propre rythme, un fondu lent et posé plutôt qu'un changement brutal.
  final List<int> _chipIdx = [0, 1, 2];
  final List<bool> _chipVisible = [true, true, true];
  final List<Timer?> _chipTimers = [null, null, null];

  static const _showDuration = Duration(milliseconds: 6500);
  static const _fadeDuration = Duration(milliseconds: 900);
  static const _stagger = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _scheduleSlot(0, _showDuration);
    _scheduleSlot(1, _showDuration + _stagger);
    _scheduleSlot(2, _showDuration + _stagger * 2);
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
    super.dispose();
  }

  void _sendPlaceholder([String? preset]) {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _thread.add(_Message(role: 'user', content: text));
      _thread.add(_Message(
        role: 'assistant',
        content: "(fondation visuelle — la vraie réponse de Tyto arrivera à la prochaine étape)",
      ));
    });
    _controller.clear();
  }

  void _resetConversation() {
    setState(() => _thread.clear());
  }

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
      drawer: TytoDrawer(activeId: 'chat', onSelect: _onDrawerSelect),
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        titleSpacing: 4,
        title: Row(
          children: [
            Image.asset('assets/images/owl.png', width: 26, height: 26),
            const SizedBox(width: 8),
            Text('Tyto', style: TytoText.display(size: 19)),
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
          Expanded(
            child: _thread.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _thread.length,
                    itemBuilder: (context, i) {
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
                      onSubmitted: (_) => _sendPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendPlaceholder(),
                    icon: const Icon(Icons.arrow_upward_rounded),
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
                      onPressed: () => _sendPlaceholder(_suggestionPool[pIdx]),
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
