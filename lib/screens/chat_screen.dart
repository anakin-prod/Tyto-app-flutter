import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_service.dart';
import '../theme/colors.dart';
import '../theme/background.dart';
import '../theme/typography.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/tyto_icons.dart';
import '../widgets/owl_sketch.dart';
import '../widgets/paw_trails.dart';
import '../widgets/voice_button.dart';
import '../widgets/owl_eye_button.dart';
import '../models/pet.dart';
import '../models/health_event.dart';
import '../services/data_service.dart';
import '../data/facts.dart';
import 'emergency_sheet.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import '../services/notification_service.dart';
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

/// Les 10 questions génériques, pour la conversation « Général ».
const _suggestionPoolGeneral = [
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

/// Les 10 questions personnalisées au nom de l'animal, quand une
/// conversation précise est ouverte — mêmes textes que le site.
List<String> _suggestionPoolPour(String nom) => [
      'Fais un point santé sur $nom',
      'Que peut manger $nom sans danger ?',
      'Quels vaccins prévoir pour $nom ?',
      'Idées de jeux pour $nom',
      'Comment savoir si $nom a mal quelque part ?',
      'À quelle fréquence peser $nom ?',
      'Que faire si $nom ne mange plus ?',
      'Comment calmer $nom en cas de stress ?',
      "Signes d'un coup de chaleur chez $nom",
      'Quand emmener $nom chez le vétérinaire ?',
    ];


class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  StreamSubscription<AuthState>? _authSub;
  bool _peutRedescendre = false;
  bool _justPaid = false; // vient de passer en Premium/Pro, à l'instant
  File? _photoJointe;
  PhotoCompressee? _photoCompressee;
  bool _compressionEnCours = false;
  List<Pet> _pets = [];
  List<HealthEvent> _rappels = [];
  final Map<String, List<_Message>> _conversations = {};
  String? _activePetId; // null = conversation générale
  final List<_Message> _thread = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;
  int? _remaining;
  bool _isPremium = false;
  bool _isPro = false;
  String _fait = '';

  final List<int> _chipIdx = [0, 1, 2];
  final List<bool> _chipVisible = [true, true, true];
  final List<Timer?> _chipTimers = [null, null, null];

  static const _showDuration = Duration(milliseconds: 9500);
  static const _fadeDuration = Duration(milliseconds: 1100);
  static const _stagger = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600), // même durée que sosPulse
    )..repeat();
    _fait = pickFact(null, null);
    _scheduleSlot(0, _showDuration);
    _scheduleSlot(1, _showDuration + _stagger);
    _scheduleSlot(2, _showDuration + _stagger * 2);
    _loadProfile();
    _chargerAnimaux();
    // Quand l'utilisateur se connecte (ou se déconnecte), son plan change :
    // sans ça, le badge resterait figé sur l'ancien statut.
    _authSub = AuthService.onAuthStateChange.listen((_) {
      if (!mounted) return;
      _loadProfile();
      // Sans ça, se connecter ne rechargeait pas les animaux : ils ne
      // réapparaissaient qu'en revenant d'un autre écran par hasard.
      _chargerAnimaux();
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

  /// Pioche un autre fait — de l'espèce de l'animal ouvert si on en a
  /// choisi un, sinon dans tous les animaux mélangés (comme le site).
  void _nextFact() {
    setState(() => _fait = pickFact(_especeActive, _fait));
  }

  String? get _especeActive {
    if (_activePetId == null) return null;
    for (final p in _pets) {
      if (p.id == _activePetId) return p.species;
    }
    return null;
  }

  Future<void> _loadProfile() async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    final profile = await UserService.fetchMe(token);
    if (!mounted) return;
    final etaitDejaAbonne = _isPremium || _isPro;
    setState(() {
      _isPremium = profile.premium;
      _isPro = profile.pro;
      _remaining = profile.remaining;
      // On vient de passer en Premium/Pro à l'instant (retour du
      // paiement Stripe dans le navigateur) : le même message que le
      // site s'affiche.
      if (!etaitDejaAbonne && (_isPremium || _isPro)) _justPaid = true;
    });
  }

  /// Après un paiement, l'utilisateur revient du navigateur : on
  /// recharge son profil pour détecter le passage en Premium/Pro.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadProfile();
  }

  /// Les compagnons et les rappels à venir, affichés au-dessus du chat
  /// comme sur le site.
  Future<void> _chargerAnimaux() async {
    if (!AuthService.isSignedIn) return;
    try {
      final pets = await DataService.loadPets();
      final rappels = await DataService.loadUpcoming();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _rappels = rappels;
        _activePetId ??= pets.isNotEmpty ? pets.first.id : null;
      });
      // On (re)programme les notifications à chaque chargement, pour
      // qu'elles restent toujours à jour avec le vrai carnet.
      await NotificationService.demanderPermission();
      await NotificationService.reprogrammer(
        rappels: rappels,
        nomsAnimaux: {for (final p in pets) p.id: p.name},
      );
    } catch (_) {
      // Pas de rappels affichés si le chargement échoue : ce n'est pas
      // bloquant, le chat reste utilisable.
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _pulse.dispose();
    for (final t in _chipTimers) {
      t?.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Joindre une photo est réservé au Premium/Pro — comme sur le site,
  /// on l'explique plutôt que de bloquer sans un mot.
  Future<void> _choisirPhoto() async {
    if (!_isPremium && !_isPro) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'analyse de photo est réservée au plan Premium.")),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TytoColors.nuit2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: TytoColors.lune),
              title: Text('Prendre une photo', style: TytoText.ui(color: TytoColors.lune)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: TytoColors.lune),
              title: Text('Choisir dans la galerie', style: TytoText.ui(color: TytoColors.lune)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 100);
    if (img == null) return;

    setState(() => _compressionEnCours = true);
    final compressee = await compresserPhoto(File(img.path));
    if (!mounted) return;
    setState(() {
      _compressionEnCours = false;
      if (compressee != null) {
        _photoJointe = File(img.path);
        _photoCompressee = compressee;
      }
    });
  }

  void _retirerPhoto() {
    setState(() {
      _photoJointe = null;
      _photoCompressee = null;
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if ((text.isEmpty && _photoCompressee == null) || _sending) return;

    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion en cours, réessaie dans un instant.")),
      );
      return;
    }

    final photoEnvoyee = _photoCompressee;
    setState(() {
      _thread.add(_Message(
        role: 'user',
        content: text.isEmpty ? '(photo)' : text,
        hasImage: photoEnvoyee != null,
      ));
      _sending = true;
      _photoJointe = null;
      _photoCompressee = null;
    });
    _controller.clear();
    _scrollToBottom();

    // On n'envoie que les 12 derniers messages, comme le site : au-delà,
    // ça coûte cher sans améliorer la réponse.
    final recents = _thread.length > 12 ? _thread.sublist(_thread.length - 12) : _thread;
    final messages = recents.map((m) => {'role': m.role, 'content': m.content}).toList();
    final result = await ChatService.send(
      accessToken: token,
      messages: messages,
      petId: _activePetId,
      imageBase64: photoEnvoyee?.base64,
      imageMediaType: photoEnvoyee?.mediaType,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.isError) {
        _thread.add(_Message(role: 'assistant', content: _errorMessage(result.error!)));
      } else {
        _thread.add(_Message(role: 'assistant', content: result.text ?? ''));
        if (result.remaining != null) _remaining = result.remaining;
        if (result.premium != null) _isPremium = result.premium!;
        ReviewService.signalerReponseReussie();
      }
    });
    _scrollToBottom();
  }

  String _errorMessage(String error) {
    switch (error) {
      case 'quota':
        return "Tu as atteint la limite de questions gratuites pour aujourd'hui. Passe en Premium pour continuer sans limite.";
      case 'premium_photo':
        return "L'analyse de photo est réservée au plan Premium. Passe en Premium pour que Tyto puisse regarder tes photos.";
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _chargerAnimaux());
  }

  /// Les deux rappels les plus proches, en haut du chat. En doré vif
  /// quand c'est dans 3 jours ou moins — comme sur le site.
  Widget _rappelsImminents() {
    if (_rappels.isEmpty || _thread.isNotEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final deux = _rappels.take(2).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: deux.map((ev) {
          final j = ev.nextDue!.difference(now).inDays;
          final proche = j <= 3;
          final nom = _pets.where((p) => p.id == ev.petId).map((p) => p.name).join();
          final quand = j <= 0
              ? "aujourd'hui !"
              : j == 1
                  ? 'demain'
                  : 'dans $j jours';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: proche ? TytoColors.fauve.withOpacity(0.15) : TytoColors.lune.withOpacity(0.05),
              border: Border.all(
                  color: proche ? TytoColors.fauve.withOpacity(0.53) : TytoColors.lune.withOpacity(0.15)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: RichText(
              text: TextSpan(
                style: TytoText.ui(size: 13, color: TytoColors.lune).copyWith(height: 1.4),
                children: [
                  TextSpan(
                    text: _libelleRappel(ev.type),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' pour ${nom.isEmpty ? "ton compagnon" : nom} — $quand'),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _libelleRappel(String type) {
    switch (type) {
      case 'vaccin':
        return 'Rappel de vaccin';
      case 'vermifuge':
        return 'Vermifuge';
      case 'visite':
        return 'Visite vétérinaire';
      case 'traitement':
        return 'Traitement';
      default:
        return 'Rappel';
    }
  }

  /// Les pastilles pour choisir de quel animal on parle, plus « Général ».
  /// Chaque animal a sa propre conversation, comme sur le site.
  Widget _selecteurAnimal() {
    if (_pets.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        children: [
          ..._pets.map((p) {
            final on = _activePetId == p.id;
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => _changerAnimal(p.id),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: on ? TytoColors.fauve.withOpacity(0.15) : TytoColors.lune.withOpacity(0.05),
                    border: Border.all(color: on ? TytoColors.fauve : TytoColors.lune.withOpacity(0.18)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpeciesIcon(species: p.species, size: 14, color: TytoColors.lune),
                      const SizedBox(width: 6),
                      Text(p.name,
                          style: TytoText.ui(
                              size: 13,
                              weight: on ? FontWeight.w700 : FontWeight.w400,
                              color: TytoColors.lune)),
                    ],
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () => _changerAnimal(null),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: _activePetId == null ? TytoColors.fauve.withOpacity(0.15) : Colors.transparent,
                border: Border.all(
                    color: _activePetId == null ? TytoColors.fauve : TytoColors.lune.withOpacity(0.18)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded,
                      size: 13,
                      color: _activePetId == null ? TytoColors.lune : TytoColors.brume),
                  const SizedBox(width: 5),
                  Text('Général',
                      style: TytoText.ui(
                          size: 13,
                          color: _activePetId == null ? TytoColors.lune : TytoColors.brume)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Changer d'animal ouvre sa conversation : chacune est séparée,
  /// exactement comme sur le site.
  void _changerAnimal(String? petId) {
    if (petId == _activePetId) return;
    setState(() {
      _conversations[_cleConversation] = List.of(_thread);
      _activePetId = petId;
      _thread
        ..clear()
        ..addAll(_conversations[_cleConversation] ?? []);
      // Le fait affiché suit l'espèce de l'animal ouvert.
      _fait = pickFact(_especeActive, _fait);
      // Les 3 puces reprennent tout de suite les questions du bon animal,
      // sans attendre leur rotation naturelle.
      _chipIdx[0] = 0;
      _chipIdx[1] = 1;
      _chipIdx[2] = 2;
    });
  }

  String get _cleConversation => _activePetId ?? 'general';

  /// Le nom de l'animal ouvert, s'il y en a un.
  String? get _nomAnimalActif {
    if (_activePetId == null) return null;
    for (final p in _pets) {
      if (p.id == _activePetId) return p.name;
    }
    return null;
  }

  List<String> get _suggestionPool {
    final nom = _nomAnimalActif;
    return nom != null ? _suggestionPoolPour(nom) : _suggestionPoolGeneral;
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
          Builder(builder: (context) {
            // Rappels, sélecteur d'animal et quota prennent une vraie
            // place en hauteur ; avec le clavier ouvert, il n'en reste
            // plus assez et ça débordait. On les masque pendant la
            // saisie — ça libère aussi de la place pour lire la
            // conversation en tapant.
            final clavierOuvert = MediaQuery.of(context).viewInsets.bottom > 0;
            return Column(
        children: [
          if (_justPaid)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: TytoColors.fauve.withOpacity(0.12),
                border: Border.all(color: TytoColors.fauve.withOpacity(0.47)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isPro
                          ? "Bienvenue en Pro. L'équipe, les ordonnances et la veille sanitaire sont à toi."
                          : "Bienvenue en Premium. Questions illimitées, réponses avancées et l'œil de Tyto sont à toi.",
                      style: TytoText.ui(size: 13.5, color: TytoColors.lune).copyWith(height: 1.45),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _justPaid = false),
                    child: Icon(Icons.close_rounded, size: 18, color: TytoColors.lune.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          if (!clavierOuvert) _rappelsImminents(),
          if (!clavierOuvert) _selecteurAnimal(),
          if (!clavierOuvert && _remaining != null && !_isPremium && !_isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  // Même formulation que le site : un visiteur a des
                  // questions « d'essai », et on lui dit ce qu'il gagne
                  // en créant un compte.
                  () {
                    final n = _remaining!;
                    final pluriel = n > 1 ? 's' : '';
                    final visiteur = !AuthService.isSignedIn;
                    final nature = visiteur ? "d'essai" : 'gratuite$pluriel';
                    final suite = visiteur
                        ? ' — crée ton compte gratuit pour passer à 15/jour'
                        : '';
                    return '$n question$pluriel $nature restante$pluriel aujourd\'hui$suite';
                  }(),
                  style: TytoText.ui(size: 12, color: _remaining! <= 2 ? TytoColors.fauve : TytoColors.brume),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m.hasImage)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.photo_camera_outlined, size: 13, color: TytoColors.lune.withOpacity(0.75)),
                                        const SizedBox(width: 5),
                                        Text('Photo envoyée',
                                            style: TytoText.ui(size: 12, color: TytoColors.lune.withOpacity(0.75))),
                                      ],
                                    ),
                                  ),
                                Text(
                                  m.content,
                                  style: TytoText.ui(size: 15, color: TytoColors.lune).copyWith(height: 1.45),
                                ),
                              ],
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
          // « Le savais-tu ? » — même mise en forme que le site : titre
          // en clair, fait en italique, et on peut toucher pour en
          // piocher un autre.
          if (!clavierOuvert && _fait.isNotEmpty)
            GestureDetector(
              onTap: _nextFact,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TytoColors.nuit2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TytoColors.lune.withOpacity(0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.lightbulb_outline_rounded, size: 14, color: TytoColors.fauve),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TytoText.ui(size: 12.5, color: TytoColors.brume)
                              .copyWith(fontStyle: FontStyle.italic, height: 1.45),
                          children: [
                            TextSpan(
                              text: 'Le savais-tu ? ',
                              style: TytoText.ui(
                                      size: 12.5,
                                      weight: FontWeight.w700,
                                      color: TytoColors.lune)
                                  .copyWith(fontStyle: FontStyle.normal),
                            ),
                            TextSpan(text: _fait),
                          ],
                        ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_photoJointe != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_photoJointe!, height: 72, width: 72, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: _retirerPhoto,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: TytoColors.nuit, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 14, color: TytoColors.lune),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                children: [
                  _compressionEnCours
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.fauve),
                          ),
                        )
                      : OwlEyeButton(
                          onTap: _choisirPhoto,
                          actif: _isPremium || _isPro,
                        ),
                  const SizedBox(width: 4),
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
                ],
              ),
            ),
          ),
        ],
      );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      // Un Center par bloc, pas un seul Center autour de tout : sinon,
      // dès que les puces changent de taille (une question sur 2 lignes
      // au lieu d'une), tout le groupe se recentre — chouette comprise.
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OwlSketch(size: 96),
            const SizedBox(height: 18),
            Text(
              _activePetId != null && _pets.any((p) => p.id == _activePetId)
                  ? 'Que veux-tu savoir pour ${_pets.firstWhere((p) => p.id == _activePetId).name} ?'
                  : "Que veux-tu savoir sur les animaux\naujourd'hui ?",
              textAlign: TextAlign.center,
              style: TytoText.body(size: 17, color: TytoColors.brume)
                  .copyWith(fontStyle: FontStyle.italic, height: 1.5),
            ),
            if (!AuthService.isSignedIn) ...[
              const SizedBox(height: 10),
              Text(
                'Gratuit, sans inscription. Touche une question pour commencer.',
                textAlign: TextAlign.center,
                style: TytoText.ui(size: 12.5, color: TytoColors.brume),
              ),
            ],
            const SizedBox(height: 18),
            // Un espace toujours identique, quelle que soit la longueur
            // des questions affichées : les puces peuvent respirer et
            // passer sur 2 lignes sans jamais faire bouger la chouette.
            SizedBox(
              height: 250,
              child: Column(
                children: List.generate(_chipIdx.length, (slot) {
                  final pIdx = _chipIdx[slot];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: AnimatedSlide(
                        // Le même mouvement discret que sur le site : la
                        // puce glisse de quelques pixels en apparaissant.
                        offset: _chipVisible[slot] ? Offset.zero : const Offset(0, 0.15),
                        duration: _fadeDuration,
                        curve: Curves.easeInOut,
                        child: AnimatedOpacity(
                          opacity: _chipVisible[slot] ? 1 : 0,
                          duration: _fadeDuration,
                          curve: Curves.easeInOut,
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _sendMessage(_suggestionPool[pIdx]),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: TytoColors.lune.withOpacity(0.07),
                                side: BorderSide(color: TytoColors.lune.withOpacity(0.23)),
                                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                alignment: Alignment.centerLeft,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  TytoIcon.sparkle(size: 14, color: TytoColors.fauve),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _suggestionPool[pIdx],
                                      style: TytoText.ui(size: 14.5, color: TytoColors.lune).copyWith(height: 1.35),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
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
  final bool hasImage;
  _Message({required this.role, required this.content, this.hasImage = false});
}
