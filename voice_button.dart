import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/colors.dart';

/// Le soigneur parle, le texte s'écrit — repris de components/VoiceButton.js.
///
/// Si l'appareil ne gère pas la reconnaissance vocale, le bouton ne
/// s'affiche simplement pas : rien ne casse, comme sur le site.
class VoiceButton extends StatefulWidget {
  /// Appelé à chaque mise à jour du texte dicté.
  final ValueChanged<String> onText;
  final double size;
  final String title;

  const VoiceButton({
    super.key,
    required this.onText,
    this.size = 38,
    this.title = 'Dicter',
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  late final AnimationController _pulse;

  bool _disponible = false;
  bool _ecoute = false;
  String _base = ''; // ce qui a déjà été dicté avant la phrase en cours

  @override
  void initState() {
    super.initState();
    // La pulsation du micro pendant l'écoute (animation "micPulse" du site).
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') setState(() => _ecoute = false);
        },
        onError: (_) {
          if (mounted) setState(() => _ecoute = false);
        },
      );
      if (mounted) setState(() => _disponible = ok);
    } catch (e) {
      if (mounted) setState(() => _disponible = false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _basculer() async {
    if (_ecoute) {
      await _speech.stop();
      if (mounted) setState(() => _ecoute = false);
      return;
    }

    _base = '';
    setState(() => _ecoute = true);
    await _speech.listen(
      localeId: 'fr_FR',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      // On laisse le temps de formuler : la dictée ne se coupe pas au
      // premier silence, comme sur le site (mode continu).
      listenFor: const Duration(minutes: 3),
      pauseFor: const Duration(seconds: 8),
      onResult: (r) {
        final mots = r.recognizedWords;
        if (r.finalResult) {
          _base = ('$_base $mots').trim();
          widget.onText(_base);
        } else {
          widget.onText(('$_base $mots').trim());
        }
      },
    );
  }

  static const _micSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <rect x="9" y="2.5" width="6" height="11" rx="3" fill="#FFFFFF" />
  <path d="M5.5 11a6.5 6.5 0 0 0 13 0" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" fill="none" />
  <path d="M12 17.5V21" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" />
</svg>''';

  @override
  Widget build(BuildContext context) {
    // Appareil sans reconnaissance vocale : on n'affiche rien.
    if (!_disponible) return const SizedBox.shrink();

    final couleurIcone = _ecoute ? TytoColors.nuit : TytoColors.lune;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // Le halo qui respire pendant l'écoute : 0 → 7 px en s'estompant.
        final t = _pulse.value;
        final p = t < 0.5 ? t * 2 : (1 - t) * 2;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _ecoute
                ? [
                    BoxShadow(
                      color: TytoColors.fauve.withOpacity(0.55 * (1 - p)),
                      blurRadius: 0,
                      spreadRadius: 7 * p,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Tooltip(
        message: _ecoute ? 'Arrêter la dictée' : widget.title,
        child: GestureDetector(
          onTap: _basculer,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ecoute ? TytoColors.fauve : Colors.transparent,
              border: _ecoute ? null : Border.all(color: TytoColors.lune.withOpacity(0.3)),
            ),
            child: SvgPicture.string(
              _micSvg,
              width: widget.size * 0.46,
              height: widget.size * 0.46,
              colorFilter: ColorFilter.mode(couleurIcone, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
