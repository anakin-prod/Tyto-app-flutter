import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/tyto_drawer.dart';
import 'placeholder_screen.dart';

/// Première fondation de l'écran de chat : juste la coquille visuelle
/// (en-tête, zone de conversation, champ de saisie), sans encore l'appel
/// réel à l'API — on ajoutera la connexion et l'envoi de messages dans
/// une prochaine étape, une fois que cette base compile et s'affiche bien.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Message> _thread = [];
  final _controller = TextEditingController();

  void _sendPlaceholder() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _thread.add(_Message(role: 'user', content: text));
      // Réponse temporaire, le temps de brancher la vraie API à l'étape suivante.
      _thread.add(_Message(
        role: 'assistant',
        content: "(fondation visuelle — la vraie réponse de Tyto arrivera à la prochaine étape)",
      ));
    });
    _controller.clear();
  }

  void _onDrawerSelect(String id) {
    Navigator.pop(context); // referme le tiroir
    if (id == 'chat') return; // déjà sur cet écran
    final labels = {
      'pets': 'Mes animaux',
      'carnet': 'Carnet de santé',
      'tableau': 'Tableau des rappels',
      'veille': 'Veille sanitaire',
    };
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceholderScreen(title: labels[id] ?? id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TytoColors.nuit,
      drawer: TytoDrawer(activeId: 'chat', onSelect: _onDrawerSelect),
      appBar: AppBar(
        backgroundColor: TytoColors.nuit,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle_outlined, color: TytoColors.fauve, size: 22),
            const SizedBox(width: 10),
            Text('Tyto', style: TytoText.display(size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _thread.isEmpty
                ? Center(
                    child: Text(
                      "Que veux-tu savoir sur les animaux\naujourd'hui ?",
                      textAlign: TextAlign.center,
                      style: TytoText.body(size: 16, color: TytoColors.brume),
                    ),
                  )
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
                    onPressed: _sendPlaceholder,
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
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}
