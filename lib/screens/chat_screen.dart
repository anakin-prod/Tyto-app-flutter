import 'dart:async';
import 'dart:io';
import 'dart:math' show Random, min;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/photo_service.dart';
import '../theme/colors.dart';
import '../services/platform_service.dart';
import '../theme/typography.dart';
import '../widgets/tyto_drawer.dart';
import '../widgets/tyto_icons.dart';
import '../widgets/site_icons.dart';
import '../widgets/owl_sketch.dart';
import '../widgets/paw_trails.dart';
import '../widgets/voice_button.dart';
import '../widgets/owl_eye_button.dart';
import '../widgets/history_sheet.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/chat_apparition.dart';
import '../widgets/chat_faits_site.dart';
import '../widgets/chat_reflet_badge.dart';
import '../models/pet.dart';
import '../models/health_event.dart';
import '../services/data_service.dart';
import '../services/achats_service.dart';
import '../services/billing_service.dart';
import 'emergency_sheet.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import '../widgets/soin_widgets.dart';
import '../widgets/compte_fenetre_email.dart';
import '../services/notification_service.dart';
import '../services/soins_service.dart';
import 'placeholder_screen.dart';
import 'pets_screen.dart';
import 'carnet_screen.dart';
import 'tableau_screen.dart';
import 'veille_screen.dart';
import 'soins_screen.dart';

/// L'écran de chat, maintenant relié à la vraie IA (même API que le site)
/// et au vrai statut Premium/Pro.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Le prix affiché sur le site (PRIX_PREMIUM de page.js).
const _prixPremium = '10,99 €/mois';

/// Les espèces qui ont leur propre page « Peut-il manger ça ? » sur le site ;
/// les autres arrivent sur la liste générale (guideAlimentsHref de page.js).
const _especesAvecGuide = ['chien', 'chat', 'lapin', 'oiseau', 'cheval', 'poisson'];

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

// ---------- Les pictogrammes écrits directement dans page.js ----------
// (ceux de components/Icons.js passent par SiteIcon). Mêmes tracés, sur la
// même grille de 24, pour un rendu identique.

const _tracBol = '<path d="M3.5 11h17c0 4.6-3.5 8-8.5 8s-8.5-3.4-8.5-8z" />'
    '<path d="M8 7.2c0-1.1.9-1.4.9-2.5M12 7.2c0-1.1.9-1.4.9-2.5M16 7.2c0-1.1.9-1.4.9-2.5" />';
const _tracFlecheHaut = '<path d="M12 19V5M6 11l6-6 6 6" />';
const _tracFlecheBas = '<path d="M12 5v14M6 13l6 6 6-6" />';

/// Un pictogramme au trait, coloré comme le texte qui l'accompagne.
Widget _picto(String trace, {required double size, required Color color, double epaisseur = 1.6}) {
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
    'stroke-width="$epaisseur" stroke-linecap="round" stroke-linejoin="round">$trace</svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  StreamSubscription<AuthState>? _authSub;
  bool _peutRedescendre = false;
  bool _peutRemonter = false;
  bool _etaitConnecte = false; // pour repérer le passage « compte → visiteur »
  bool _justPaid = false; // vient de passer en Premium/Pro, à l'instant
  bool _faitEstSaison = false; // l'encart affiche un conseil de saison plutôt qu'un fait
  bool _animauxCharges = false; // comme petsLoaded sur le site
  bool _erreurEnvoi = false; // « Mes plumes se sont emmêlées » dans la conversation ouverte
  bool _anniversaireMasque = false; // le bandeau d'anniversaire a été touché (fermé)
  String? _cleEnvoi; // la conversation qui attend une réponse de Tyto
  String? _profilUserId; // le compte dont le statut Premium/Pro est actuellement affiché
  File? _photoJointe;
  PhotoCompressee? _photoCompressee;
  bool _compressionEnCours = false;
  List<Pet> _pets = [];
  List<HealthEvent> _rappels = [];
  final Map<String, List<_Message>> _conversations = {};
  String? _activePetId; // null = conversation générale
  final List<_Message> _thread = [];
  // Comme « convos » sur le site : le fil affiché de chaque conversation
  // reste en mémoire pendant la visite. Revenir sur un animal retrouve sa
  // conversation telle quelle, et sa pastille porte un point « · ».
  final Map<String, List<_Message>> _filsAffiches = {};
  final Set<String> _clesEnErreur = {};
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  // L'accueil défile à part (chouette et puces), comme le haut du site.
  final _scrollAccueil = ScrollController();

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
  // La courbe des puces du site : cubic-bezier(0.22, 1, 0.36, 1).
  static const _courbePuces = Cubic(0.22, 1.0, 0.36, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // « En parler à Tyto » depuis un dossier de soin ouvre le chat de l'animal.
    soinsDemandeChat.addListener(_demandeSoins);
    // Les achats intégrés Apple (iOS seulement ; sans effet sur Android).
    AchatsService.demarrer();
    AchatsService.achatReussi.addListener(_apresAchat);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600), // même durée que sosPulse
    )..repeat();
    _fait = chatPiocherFait(null, null);
    _demarrerPuces();
    _loadProfile();
    // Un visiteur n'a pas de compagnons à attendre.
    _animauxCharges = !AuthService.isSignedIn;
    _chargerAnimaux();
    // Quand l'utilisateur se connecte (ou se déconnecte), son plan change :
    // sans ça, le badge resterait figé sur l'ancien statut.
    _etaitConnecte = AuthService.isSignedIn;
    _authSub = AuthService.onAuthStateChange.listen((_) {
      if (!mounted) return;
      final connecte = AuthService.isSignedIn;
      if (_etaitConnecte && !connecte) {
        // On vient de quitter un vrai compte (déconnexion ou suppression) :
        // on efface tout ce qui venait de lui — animaux, conversations,
        // statut Premium/Pro et rappels programmés sur le téléphone. On ne
        // le fait QUE lors de ce passage : un simple renouvellement de
        // session d'un visiteur ne doit jamais vider sa conversation.
        NotificationService.annulerTout();
        setState(() {
          _pets = [];
          _rappels = [];
          _conversations.clear();
          _thread.clear();
          _filsAffiches.clear();
          _clesEnErreur.clear();
          _activePetId = null;
          _isPremium = false;
          _isPro = false;
          _remaining = null;
          _justPaid = false;
          _profilUserId = null;
          _erreurEnvoi = false;
        });
      }
      // Les achats Apple suivent le compte : l'identifiant utilisé chez RevenueCat
      // est celui de Supabase, comme côté serveur.
      if (connecte && !_etaitConnecte) {
        final id = Supabase.instance.client.auth.currentUser?.id;
        if (id != null) AchatsService.connecter(id);
      } else if (!connecte && _etaitConnecte) {
        AchatsService.deconnecter();
      }
      _etaitConnecte = connecte;
      _loadProfile();
      // Sans ça, se connecter ne rechargeait pas les animaux : ils ne
      // réapparaissaient qu'en revenant d'un autre écran par hasard.
      _chargerAnimaux();
    });
    // Dans une longue conversation, une flèche permet de remonter tout en
    // haut (comme sur le site, au-delà de 400 px), une autre de revenir en bas.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final loinDuBas = _scrollController.position.maxScrollExtent -
              _scrollController.position.pixels >
          260;
      if (loinDuBas != _peutRedescendre) {
        setState(() => _peutRedescendre = loinDuBas);
      }
      final loinDuHaut = _scrollController.position.pixels > 400;
      if (loinDuHaut != _peutRemonter) {
        setState(() => _peutRemonter = loinDuHaut);
      }
    });
  }

  /// Après un achat intégré réussi : on relit le statut tout de suite, ce qui
  /// affiche le message de bienvenue (même compte, pas abonné puis abonné).
  void _apresAchat() => _loadProfile(detecterAchat: true);

  /// Toucher l'encart pioche autre chose (nextEntry du site).
  void _nextFact() {
    setState(_tirerEntree);
  }

  /// nextEntry du site : on tire au sort, à parts égales, parmi un conseil
  /// de saison (s'il y en a un ce mois-ci et que l'encart n'en affiche pas
  /// déjà un) et un fait — de l'espèce de l'animal ouvert, ou de toutes
  /// les espèces mélangées dans la conversation générale.
  void _tirerEntree() {
    final espece = _especeActive;
    final candidats = <MapEntry<bool, String>>[];
    if (!_faitEstSaison) {
      final conseil = chatPiocherConseilSaison(DateTime.now().month, espece, null);
      if (conseil != null) candidats.add(MapEntry(true, conseil));
    }
    candidats.add(MapEntry(false, chatPiocherFait(espece, _faitEstSaison ? null : _fait)));
    final choix = candidats[Random().nextInt(candidats.length)];
    _faitEstSaison = choix.key;
    _fait = choix.value;
  }

  /// Quand l'espèce affichée change, l'encart repart sur un fait de cette
  /// espèce (l'effet sur currentFactSpecies du site).
  void _faitPourEspece() {
    _fait = chatPiocherFait(_especeActive, null);
    _faitEstSaison = false;
  }

  /// Change la conversation affichée (setActivePetId du site) : le fil de
  /// la conversation quittée est mis de côté, celui de la nouvelle revient
  /// tel qu'on l'avait laissé. À appeler dans un setState.
  void _basculerVers(String? petId) {
    final ancienne = _cleConversation;
    _filsAffiches[ancienne] = List<_Message>.of(_thread);
    if (_erreurEnvoi) {
      _clesEnErreur.add(ancienne);
    } else {
      _clesEnErreur.remove(ancienne);
    }
    _activePetId = petId;
    final nouvelle = _cleConversation;
    _thread
      ..clear()
      ..addAll(_filsAffiches[nouvelle] ?? const <_Message>[]);
    _erreurEnvoi = _clesEnErreur.contains(nouvelle);
  }

  /// La conversation de cette clé a-t-elle un fil affiché (le point « · »
  /// des pastilles du site) ?
  bool _filNonVide(String cle) =>
      cle == _cleConversation ? _thread.isNotEmpty : (_filsAffiches[cle]?.isNotEmpty ?? false);

  String? get _especeActive {
    if (_activePetId == null) return null;
    for (final p in _pets) {
      if (p.id == _activePetId) return p.species;
    }
    return null;
  }

  Future<void> _loadProfile({bool detecterAchat = false}) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final profile = await UserService.fetchMe(token);
    if (!mounted) return;
    final etaitDejaAbonne = _isPremium || _isPro;
    // Un achat = le MÊME compte qui passe de « pas abonné » à « abonné » alors
    // qu'on revient du navigateur. Se connecter à un compte déjà abonné change
    // de compte : ce n'est pas un achat, et ne doit pas afficher « Bienvenue ».
    final memeCompte = _profilUserId != null && _profilUserId == userId;
    final change =
        profile.premium != _isPremium || profile.pro != _isPro || profile.remaining != _remaining;
    setState(() {
      _isPremium = profile.premium;
      _isPro = profile.pro;
      _remaining = profile.remaining;
      if (detecterAchat && memeCompte && !etaitDejaAbonne && (_isPremium || _isPro)) {
        _justPaid = true;
      }
    });
    _profilUserId = userId;
    // Comme le site : quand le statut change (quota, Premium), la page
    // redescend en bas pour montrer l'encart qui apparaît.
    if (change) _scrollToBottom();
  }

  /// Après un paiement, l'utilisateur revient du navigateur : on
  /// recharge son profil pour détecter le passage en Premium/Pro.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadProfile(detecterAchat: true);
  }

  /// Les compagnons et les rappels à venir, affichés au-dessus du chat
  /// comme sur le site.
  Future<void> _chargerAnimaux() async {
    if (!AuthService.isSignedIn) {
      // Un visiteur n'a pas de compagnons : l'accueil peut afficher tout de
      // suite les phrases prévues pour lui.
      if (mounted && !_animauxCharges) setState(() => _animauxCharges = true);
      return;
    }
    try {
      final pets = await DataService.loadPets();
      final rappels = await DataService.loadUpcoming();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _rappels = rappels;
        _animauxCharges = true;
        // Comme loadPets sur le site : on garde l'animal ouvert s'il existe
        // encore, sinon on ouvre le premier de la liste.
        final actifExiste = _activePetId != null && pets.any((p) => p.id == _activePetId);
        if (!actifExiste) {
          final premier = pets.isNotEmpty ? pets.first.id : null;
          if (premier != _activePetId) {
            _basculerVers(premier);
            _faitPourEspece();
          }
        }
      });
      // Le site redescend en bas de la page à chaque changement d'animal.
      _scrollToBottom();
      // On (re)programme les notifications à chaque chargement, pour
      // qu'elles restent toujours à jour avec le vrai carnet.
      await NotificationService.demanderPermission();
      await NotificationService.reprogrammer(
        rappels: rappels,
        nomsAnimaux: {for (final p in pets) p.id: p.name},
        animaux: [for (final p in pets) {'nom': p.name, 'espece': p.species}],
      );
      // Les rappels de soins (gouttes, comprimés…) suivent le même chemin.
      try {
        await SoinsService.reprogrammerNotifications();
      } catch (_) {}

      // On charge l'historique de chaque conversation pour le panneau
      // d'historique — mais on ne l'affiche plus directement à l'arrivée :
      // on tombe sur l'accueil, comme demandé, et on y accède seulement
      // en touchant le bouton historique.
      final historique = await DataService.loadConversations();
      if (!mounted) return;
      setState(() {
        historique.forEach((cle, messages) {
          _conversations[cle] = messages
              .map((m) => _Message(
                    role: m['role'] as String,
                    content: m['content'] as String,
                    hasImage: m['hasImage'] as bool,
                    date: m['date'] as DateTime,
                  ))
              .toList();
        });
      });
    } catch (_) {
      // Pas de rappels affichés si le chargement échoue : ce n'est pas
      // bloquant, le chat reste utilisable.
      if (mounted && !_animauxCharges) setState(() => _animauxCharges = true);
    }
  }

  /// (Re)lance la rotation des 3 puces, comme l'effet du site qui repart à
  /// zéro à chaque changement d'animal.
  void _demarrerPuces() {
    for (var i = 0; i < _chipTimers.length; i++) {
      _chipTimers[i]?.cancel();
      _chipTimers[i] = null;
      _chipVisible[i] = true;
    }
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
    WidgetsBinding.instance.removeObserver(this);
    soinsDemandeChat.removeListener(_demandeSoins);
    AchatsService.achatReussi.removeListener(_apresAchat);
    _authSub?.cancel();
    _pulse.dispose();
    for (final t in _chipTimers) {
      t?.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    _scrollAccueil.dispose();
    super.dispose();
  }

  /// Le quota du jour est épuisé (compte gratuit ou visiteur), comme
  /// quotaExhausted sur le site.
  bool get _quotaEpuise => !_isPremium && !_isPro && _remaining != null && _remaining! <= 0;

  /// Sur iOS, aucune offre payante hors App Store (règle 3.1.1 d'Apple) :
  /// les boutons « Passer Premium » n'y existent que si les achats
  /// intégrés sont en place.
  bool get _offresAccessibles => !PlatformInfo.estIOS || AchatsService.disponible;

  void _ouvrirOffres() {
    if (PlatformInfo.estIOS) {
      AchatsService.ouvrirOffres(context);
    } else {
      BillingService.openOffers();
    }
  }

  void _ouvrirConnexion() {
    // Comme sur le site : un visiteur ouvre la fenêtre « Crée ton compte
    // gratuit » (qui garde ses conversations), pas l'écran de connexion.
    FenetreCreerCompte.afficher(context);
  }

  /// Ouvre une page du site dans le navigateur.
  Future<void> _ouvrirSite(String chemin) async {
    try {
      await launchUrl(Uri.parse('https://tytoai.app$chemin'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _ouvrirEcran(Widget ecran) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ecran)).then((_) => _chargerAnimaux());
  }

  /// Joindre une photo est réservé au Premium/Pro — comme sur le site,
  /// on l'explique plutôt que de bloquer sans un mot.
  Future<void> _choisirPhoto() async {
    if (!_isPremium && !_isPro) {
      _afficherOeilPremium();
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
              leading: SiteIcon('IconCamera', size: 22, color: TytoColors.lune),
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
    // Quota du jour atteint : rien ne part, comme sur le site.
    if (_quotaEpuise) return;

    if (AuthService.currentSession?.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion en cours, réessaie dans un instant.")),
      );
      return;
    }

    final photoEnvoyee = _photoCompressee;
    // Une photo seule part avec la même phrase que sur le site.
    final contenu = text.isEmpty ? 'Analyse cette photo.' : text;
    final messageUtilisateur = _Message(
      role: 'user',
      content: contenu,
      hasImage: photoEnvoyee != null,
      image: photoEnvoyee != null ? _photoJointe : null,
    );
    setState(() {
      _thread.add(messageUtilisateur);
      _erreurEnvoi = false;
      _photoJointe = null;
      _photoCompressee = null;
      // Le panneau d'historique lit cette liste : on la tient à jour au
      // fil de l'eau, plutôt que de la reconstruire depuis le fil affiché
      // (qui, lui, redémarre vide à chaque visite).
      (_conversations[_cleConversation] ??= []).add(messageUtilisateur);
    });
    _controller.clear();
    _scrollToBottom();
    // Sauvegardé au fil de l'eau, comme sur le site : rien n'est perdu
    // si l'app se ferme en cours de route.
    DataService.saveMessage(
      threadKey: _cleConversation,
      role: 'user',
      content: contenu,
      hasImage: photoEnvoyee != null,
    );
    await _demanderReponse(photo: photoEnvoyee);
  }

  /// Envoie la conversation ouverte à Tyto et affiche sa réponse. Sert aussi
  /// au bouton « Réessayer » (alors sans photo, comme sur le site).
  Future<void> _demanderReponse({PhotoCompressee? photo}) async {
    final token = AuthService.currentSession?.accessToken;
    final cle = _cleConversation;
    if (token == null) {
      setState(() => _erreurEnvoi = true);
      return;
    }
    setState(() {
      _sending = true;
      _cleEnvoi = cle;
      _erreurEnvoi = false;
    });
    _scrollToBottom();

    // On n'envoie que les 12 derniers messages, comme le site : au-delà,
    // ça coûte cher sans améliorer la réponse.
    final recents = _thread.length > 12 ? _thread.sublist(_thread.length - 12) : List<_Message>.of(_thread);
    final messages = recents.map((m) => {'role': m.role, 'content': m.content}).toList();
    final result = await ChatService.send(
      accessToken: token,
      messages: messages,
      petId: _activePetId,
      imageBase64: photo?.base64,
      imageMediaType: photo?.mediaType,
    );

    if (!mounted) return;
    // L'utilisateur a pu changer d'animal entre-temps : la réponse reste
    // alors rangée dans la bonne conversation, sans s'afficher dans l'autre.
    final toujoursIci = cle == _cleConversation;
    if (result.isError) {
      setState(() {
        _sending = false;
        _cleEnvoi = null;
        if (result.error == 'quota') {
          // Comme le site : plus de carte d'erreur, c'est l'encart du
          // quota épuisé qui prend le relais.
          _remaining = 0;
        } else if (result.error != 'premium_photo') {
          // L'erreur reste attachée à SA conversation, comme sur le site.
          if (toujoursIci) {
            _erreurEnvoi = true;
          } else {
            _clesEnErreur.add(cle);
          }
        }
      });
      if (result.error == 'premium_photo') _afficherOeilPremium();
      _scrollToBottom();
      return;
    }

    final reponse = _Message(role: 'assistant', content: result.text ?? '');
    setState(() {
      _sending = false;
      _cleEnvoi = null;
      if (toujoursIci) {
        _thread.add(reponse);
      } else {
        // La réponse rejoint le fil de sa conversation, retrouvé tel quel
        // quand on revient sur cet animal.
        (_filsAffiches[cle] ??= []).add(reponse);
      }
      (_conversations[cle] ??= []).add(reponse);
      if (result.remaining != null) _remaining = result.remaining;
      if (result.premium != null) _isPremium = result.premium!;
    });
    ReviewService.signalerReponseReussie();
    DataService.saveMessage(
      threadKey: cle,
      role: 'assistant',
      content: result.text ?? '',
    );
    _scrollToBottom();
  }

  /// « Réessayer » : la même conversation repart, comme retry() sur le site.
  void _relancer() {
    if (_sending || _thread.isEmpty) return;
    _demanderReponse();
  }

  /// Redescend en bas, comme le site (scrollIntoView du repère placé juste
  /// avant la marge de 24 px du bas) : le dernier élément touche le bas de
  /// la zone, la marge reste cachée en dessous. Vaut pour la conversation
  /// comme pour l'accueil.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final c in [_scrollController, _scrollAccueil]) {
        if (!c.hasClients) continue;
        final double fin = c.position.maxScrollExtent;
        final double cible = fin > 24 ? fin - 24 : 0.0;
        c.animateTo(
          cible,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Le texte d'invite du champ de saisie : celui du site (avec le nom de
  /// l'animal choisi, sinon la formule générale).
  String get _texteInvite {
    if (_quotaEpuise) {
      return _offresAccessibles
          ? 'Quota du jour atteint — reviens demain ou passe Premium'
          : 'Quota du jour atteint — reviens demain';
    }
    for (final p in _pets) {
      if (p.id == _activePetId) return 'Une question pour ${p.name}…';
    }
    return 'Pose ta question sur un animal…';
  }

  /// La pastille « fantôme » du site (ghostBtn) : fine bordure ivoire
  /// translucide, icône brume, bords entièrement arrondis.
  Widget _boutonFantome(Widget icone, String libelle, VoidCallback onTap) {
    return Tooltip(
      message: libelle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              // ghostBtn du site : border 1px LUNE + "33" (20 %)
              border: Border.all(color: TytoColors.lune.withOpacity(0.2)),
            ),
            child: icone,
          ),
        ),
      ),
    );
  }

  /// Le même bouton fantôme, avec un texte (« Retirer la photo »).
  Widget _boutonFantomeTexte(String libelle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TytoColors.lune.withOpacity(0.2)),
        ),
        child: Text(libelle, style: TytoText.ui(size: 12, weight: FontWeight.w400, color: TytoColors.brume)),
      ),
    );
  }

  /// Le bouton doré du site (goldBtn) : fond fauve, texte nuit en gras.
  Widget _boutonDore(
    String libelle,
    VoidCallback onTap, {
    Widget? icone,
    double ecart = 6,
    double taille = 14.5,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
    bool pleineLargeur = false,
    // Avec une icône, le navigateur aligne le libellé sur le bas de l'icône
    // et ajoute quelques pixels sous la ligne (mesurés sur le site).
    double extraBas = 0,
  }) {
    return Material(
      color: TytoColors.fauve,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: padding.copyWith(bottom: padding.bottom + extraBas),
          child: Row(
            mainAxisSize: pleineLargeur ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icone != null) ...[icone, SizedBox(width: ecart)],
              Flexible(
                child: Text(
                  libelle,
                  textAlign: TextAlign.center,
                  style: TytoText.ui(size: taille, weight: FontWeight.w700, color: TytoColors.nuit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La carte ivoire du site (paperCard).
  Widget _cartePapier(Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: TytoColors.papier,
        border: Border.all(color: TytoColors.encre.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  /// Les boutons du site sans police précisée s'affichent dans la police
  /// du système (Roboto sur Android) : c'est le cas de l'encart
  /// « Le savais-tu ? » et du bandeau d'anniversaire.
  TextStyle _policeSysteme({required double size, FontWeight weight = FontWeight.w400, Color color = TytoColors.lune}) {
    return TextStyle(
      fontFamily: Theme.of(context).typography.white.bodyMedium?.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  /// Le petit bouton rond, bord doré fin, pour se déplacer dans une longue
  /// conversation (même style que la flèche du site).
  Widget _boutonDefilement(String trace, VoidCallback onTap, String libelle) {
    return Semantics(
      button: true,
      label: libelle,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TytoColors.nuit2,
            border: Border.all(color: TytoColors.fauve.withOpacity(0.55)),
            boxShadow: const [
              BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 3)),
            ],
          ),
          child: _picto(trace, size: 18, color: TytoColors.fauve),
        ),
      ),
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _resetConversation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TytoColors.nuit2,
        surfaceTintColor: Colors.transparent,
        title: Text('Effacer cette conversation ?', style: TytoText.display(size: 17, color: TytoColors.lune)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TytoText.ui(color: TytoColors.brume))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Effacer', style: TytoText.ui(color: TytoColors.urgence, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    final cle = _cleConversation;
    setState(() {
      _thread.clear();
      _conversations.remove(cle);
      _erreurEnvoi = false;
      // Comme reset() sur le site : la saisie et la photo jointe repartent à zéro.
      _photoJointe = null;
      _photoCompressee = null;
    });
    _controller.clear();
    _scrollToBottom();
    await DataService.deleteConversation(cle);
  }

  /// Regroupe la conversation actuelle par jour, et ouvre le panneau
  /// pour la parcourir ou l'effacer.
  void _ouvrirHistorique() {
    // On regroupe par jour depuis la vraie mémoire complète — le fil
    // affiché, lui, est vide par défaut tant qu'on n'a pas choisi un jour.
    final source = _conversations[_cleConversation] ?? [];
    final jours = <HistoryDay>[];
    DateTime? jourCourant;
    int debutJour = 0;
    String apercuJour = '';
    int compteJour = 0;

    void cloreJour() {
      if (jourCourant == null) return;
      jours.add(HistoryDay(
        jour: jourCourant,
        apercu: apercuJour,
        nombreMessages: compteJour,
        indexPremierMessage: debutJour,
      ));
    }

    for (var i = 0; i < source.length; i++) {
      final m = source[i];
      final j = DateTime(m.date.year, m.date.month, m.date.day);
      if (jourCourant == null || j != jourCourant) {
        cloreJour();
        jourCourant = j;
        debutJour = i;
        compteJour = 0;
        apercuJour = m.content;
      }
      compteJour++;
    }
    cloreJour();

    HistorySheet.afficher(
      context,
      jours: jours.reversed.toList(),
      titre: _nomAnimalActif ?? 'Général',
      onJumpTo: (index) {
        // On charge la conversation complète dans le fil affiché, puis
        // on amène le premier message du jour choisi en haut de la zone,
        // comme le scrollIntoView du site.
        setState(() {
          _thread
            ..clear()
            ..addAll(source);
          _erreurEnvoi = false;
        });
        if (index >= 0 && index < source.length) _allerAuMessage(source[index], index);
      },
      onEffacer: () async {
        final cle = _cleConversation;
        setState(() {
          _thread.clear();
          _conversations.remove(cle);
          _erreurEnvoi = false;
        });
        _scrollToBottom();
        await DataService.deleteConversation(cle);
      },
    );
  }

  /// Fait défiler la conversation jusqu'à ce message (en haut de la zone).
  /// La liste ne construit que ce qui est proche de l'écran : si le message
  /// n'est pas encore construit, on s'en approche d'abord par estimation.
  void _allerAuMessage(_Message m, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final cle = GlobalObjectKey(m);
      if (cle.currentContext == null) {
        final double fin = _scrollController.position.maxScrollExtent;
        final double estimation = index * 92.0;
        _scrollController.jumpTo(estimation > fin ? fin : estimation);
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      final contexte = cle.currentContext;
      if (contexte == null) return;
      await Scrollable.ensureVisible(
        contexte,
        alignment: 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _openSos() {
    final pet = _animalActif;
    EmergencySheet.ouvrir(context, petId: pet?.id, petName: pet?.name, petWeight: pet?.weightKg);
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
      case 'soins':
        screen = const SoinsScreen();
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

  /// Les deux rappels les plus proches (dans les 60 jours, comme le site),
  /// en haut de l'accueil. En doré vif quand c'est dans 3 jours ou moins.
  /// Un toucher ouvre le carnet.
  Widget? _rappelsImminents() {
    if (_rappels.isEmpty || _thread.isNotEmpty) return null;
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final proches = <MapEntry<HealthEvent, int>>[];
    for (final ev in _rappels) {
      final due = ev.nextDue;
      if (due == null) continue;
      // Écart en jours calendaires (daysUntil du site), pas en heures.
      final j = (DateTime(due.year, due.month, due.day).difference(aujourdhui).inHours / 24).round();
      if (j < 0 || j > 60) continue;
      proches.add(MapEntry(ev, j));
      if (proches.length == 2) break;
    }
    if (proches.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (var i = 0; i < proches.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: _rappel(proches[i].key, proches[i].value),
            ),
        ],
      ),
    );
  }

  Widget _rappel(HealthEvent ev, int j) {
    final proche = j <= 3;
    final nom = _pets.where((p) => p.id == ev.petId).map((p) => p.name).join();
    final quand = j == 0
        ? "aujourd'hui !"
        : j == 1
            ? 'demain'
            : 'dans $j jours';
    return GestureDetector(
      onTap: () => _ouvrirEcran(const CarnetScreen()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: proche ? TytoColors.fauve.withOpacity(0.15) : TytoColors.lune.withOpacity(0.05),
          border: Border.all(
              color: proche ? TytoColors.fauve.withOpacity(0.53) : TytoColors.lune.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text.rich(
          TextSpan(
            style: TytoText.ui(size: 13, weight: FontWeight.w400, color: TytoColors.lune).copyWith(height: 1.4),
            children: [
              TextSpan(
                text: ev.libelle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' pour ${nom.isEmpty ? "votre compagnon" : nom} — $quand'),
            ],
          ),
        ),
      ),
    );
  }

  /// Les pastilles pour choisir de quel animal on parle, plus « Général ».
  /// Chaque animal a sa propre conversation, comme sur le site ; un point
  /// suit le nom quand sa conversation est ouverte et non vide.
  Widget _selecteurAnimal() {
    final pointGeneral = _filNonVide('general') ? ' ·' : '';
    return SizedBox(
      // 12 au-dessus, pastilles de 31,5 px (mesurées sur le site), 2 dessous.
      height: 45.5,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        children: [
          for (final p in _pets)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _pastille(
                actif: _activePetId == p.id,
                general: false,
                icone: SiteIcon.espece(p.species, size: 14, color: TytoColors.lune),
                ecart: 6,
                // Le point « · » suit le nom de chaque animal dont la
                // conversation a été ouverte pendant la visite (site).
                libelle: '${p.name}${_filNonVide(p.id) ? ' ·' : ''}',
                onTap: () => _changerAnimal(p.id),
              ),
            ),
          _pastille(
            actif: _activePetId == null,
            general: true,
            icone: SiteIcon('IconGlobe',
                size: 13, color: _activePetId == null ? TytoColors.lune : TytoColors.brume),
            ecart: 5,
            libelle: 'Général$pointGeneral',
            onTap: () => _changerAnimal(null),
          ),
        ],
      ),
    );
  }

  Widget _pastille({
    required bool actif,
    required bool general,
    required Widget icone,
    required double ecart,
    required String libelle,
    required VoidCallback onTap,
  }) {
    final Color fond = actif
        ? TytoColors.fauve.withOpacity(0.15)
        : (general ? Colors.transparent : TytoColors.lune.withOpacity(0.05));
    final Color couleurTexte = general && !actif ? TytoColors.brume : TytoColors.lune;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        // Sur le site, le libellé est calé 1,25 px au-dessus du milieu de la
        // pastille (alignement du navigateur) : 2,5 px de plus en bas.
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 2.5),
        decoration: BoxDecoration(
          color: fond,
          border: Border.all(color: actif ? TytoColors.fauve : TytoColors.lune.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icone,
            SizedBox(width: ecart),
            Text(
              libelle,
              style: TytoText.ui(
                size: 13,
                // Seuls les animaux passent en gras une fois choisis.
                weight: actif && !general ? FontWeight.w700 : FontWeight.w400,
                color: couleurTexte,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Le lien « Peut-il manger ça ? » vers le guide des aliments de l'espèce.
  Widget _lienAliments(Pet animal) {
    final chemin = _especesAvecGuide.contains(animal.species) ? '/aliments/${animal.species}' : '/aliments';
    return GestureDetector(
      onTap: () => _ouvrirSite(chemin),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: TytoColors.lune.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _picto(_tracBol, size: 14, color: TytoColors.brume, epaisseur: 1.8),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'Peut-il manger ça ? Les aliments pour ${animal.name}',
                // Ligne de 14 px comme dans le navigateur : pastille de 26 px.
                style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.brume)
                    .copyWith(height: 14 / 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _demandeSoins() {
    final id = soinsDemandeChat.value;
    if (id == null || !mounted) return;
    soinsDemandeChat.value = null;
    _changerAnimal(id);
  }

  /// Changer d'animal ouvre sa conversation : chacune est séparée,
  /// exactement comme sur le site.
  void _changerAnimal(String? petId) {
    if (petId == _activePetId) return;
    final ancienneEspece = _especeActive;
    setState(() {
      // La conversation quittée est mise de côté ; celle de l'animal choisi
      // revient telle qu'on l'avait laissée (vide = accueil), comme le site.
      _basculerVers(petId);
      _peutRemonter = false;
      _peutRedescendre = false;
      // Le fait affiché suit l'espèce de l'animal ouvert.
      if (_especeActive != ancienneEspece) _faitPourEspece();
      // La rotation des 3 puces repart de zéro, comme l'effet du site.
      _demarrerPuces();
    });
    _scrollToBottom();
  }

  String get _cleConversation => _activePetId ?? 'general';

  /// L'animal ouvert, s'il y en a un.
  Pet? get _animalActif {
    if (_activePetId == null) return null;
    for (final p in _pets) {
      if (p.id == _activePetId) return p;
    }
    return null;
  }

  /// Le nom de l'animal ouvert, s'il y en a un.
  String? get _nomAnimalActif => _animalActif?.name;

  List<String> get _suggestionPool {
    final nom = _nomAnimalActif;
    return nom != null ? _suggestionPoolPour(nom) : _suggestionPoolGeneral;
  }

  /// Le compagnon dont c'est l'anniversaire aujourd'hui (pas l'année de sa
  /// naissance), comme birthdayPet sur le site.
  Pet? get _animalAnniversaire {
    final auj = DateTime.now();
    for (final p in _pets) {
      final n = p.birthdate;
      if (n != null && n.month == auj.month && n.day == auj.day && n.year < auj.year) return p;
    }
    return null;
  }

  /// Les boutons historique / nouvelle conversation n'apparaissent que s'il
  /// y a quelque chose à revoir.
  bool get _boutonsConversation =>
      _thread.isNotEmpty || (_conversations[_cleConversation]?.isNotEmpty ?? false);

  /// Sur le site, l'en-tête passe sur deux lignes quand tout ne tient pas
  /// (badge Premium + boutons de conversation) : les boutons de droite
  /// descendent alors sous le logo. Largeurs mesurées sur le site.
  bool _enTeteSurDeuxLignes(double largeurEcran) {
    double gauche = 16.0 + 38 + 8 + 30 + 8 + 45; // menu, chouette, « Tyto »
    if (_isPro) {
      gauche += 8 + 66;
    } else if (_isPremium) {
      gauche += 8 + 98;
    }
    double droite = 105; // URGENCE
    if (_boutonsConversation) droite += 40 + 6 + 40 + 6;
    return gauche + 8 + droite + 16 > largeurEcran;
  }

  /// Le badge PRO / PREMIUM à côté du nom, avec son pictogramme et le reflet
  /// qui le traverse une fois à son apparition (.plan-badge du site).
  Widget _badgePlan() {
    final couleur = _isPro ? TytoColors.vert : TytoColors.fauve;
    return ChatRefletBadge(
      // Une clé par plan : passer de Premium à Pro rejoue le reflet, comme
      // le nouveau badge qui apparaît sur le site.
      key: ValueKey(_isPro ? 'badge-pro' : 'badge-premium'),
      child: _badgePlanCorps(couleur),
    );
  }

  Widget _badgePlanCorps(Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.15),
        border: Border.all(color: couleur.withOpacity(_isPro ? 0.53 : 0.47)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isPro
              ? SiteIcon('IconShield', size: 12, color: couleur)
              : SiteIcon('IconSparkle', size: 12, color: couleur),
          const SizedBox(width: 5),
          Text(
            _isPro ? 'PRO' : 'PREMIUM',
            style: TytoText.ui(size: 11, weight: FontWeight.w700, color: couleur).copyWith(letterSpacing: 0.88),
          ),
        ],
      ),
    );
  }

  /// Le bouton URGENCE, avec le halo de sosPulse (globals.css) : un anneau
  /// qui s'écarte de 0 à 6 px en s'estompant, sur 2,6 s.
  Widget _boutonUrgence() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // Les étapes exactes de sosPulse :
        //  0 % et 100 % → anneau à 0 px, opacité 0,5
        //  50 %         → anneau à 6 px, opacité 0
        // (avec la courbe « ease » appliquée entre deux étapes, comme le
        // navigateur pour une animation CSS)
        final t = _pulse.value;
        final double spread, opacity;
        if (t < 0.5) {
          final p = Curves.ease.transform(t * 2);
          spread = 6 * p;
          opacity = 0.5 * (1 - p);
        } else {
          final p = Curves.ease.transform((t - 0.5) * 2);
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
      child: Tooltip(
        message: 'Urgence : mon animal va mal',
        child: TextButton(
          onPressed: _openSos,
          style: TextButton.styleFrom(
            backgroundColor: TytoColors.urgence,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SiteIcon('IconAlert', size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text('URGENCE',
                  style: TytoText.ui(size: 12, weight: FontWeight.w700, color: Colors.white)
                      .copyWith(letterSpacing: 0.36)),
            ],
          ),
        ),
      ),
    );
  }

  /// Les boutons de droite de l'en-tête : historique, nouvelle conversation
  /// (s'il y a une conversation) et URGENCE.
  Widget _groupeDroite() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Comme sur le site : deux petites pastilles entourées, qui
        // n'apparaissent que s'il y a une conversation à revoir.
        if (_boutonsConversation) ...[
          _boutonFantome(TytoIcon.historique(size: 14, color: TytoColors.brume),
              'Historique des conversations', _ouvrirHistorique),
          const SizedBox(width: 6),
          _boutonFantome(SiteIcon('IconRefresh', size: 14, color: TytoColors.brume),
              'Nouvelle conversation', _resetConversation),
          const SizedBox(width: 6),
        ],
        _boutonUrgence(),
      ],
    );
  }

  /// Le bas de l'en-tête du site : le compteur de questions (plume), puis
  /// le filet qui sépare l'en-tête du contenu.
  Widget _basEnTete(bool visiteur) {
    final afficherQuota = _remaining != null && !_isPremium && !_isPro;
    Widget? compteur;
    if (afficherQuota) {
      final n = _remaining!;
      final pluriel = n > 1 ? 's' : '';
      // Même formulation que le site : un visiteur a des questions
      // « d'essai », et on lui dit ce qu'il gagne en créant un compte.
      final nature = visiteur ? "d'essai" : 'gratuite$pluriel';
      final suite = visiteur ? ' — crée ton compte gratuit pour passer à 15/jour' : '';
      final couleur = n <= 2 ? TytoColors.fauve : TytoColors.brume;
      compteur = Row(
        children: [
          SiteIcon('IconFeather', size: 13, color: couleur),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$n question$pluriel $nature restante$pluriel aujourd\'hui$suite',
              style: TytoText.ui(size: 12, weight: FontWeight.w400, color: couleur),
            ),
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: compteur != null ? EdgeInsets.fromLTRB(_marge, 6, _marge, 8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: TytoColors.lune.withOpacity(0.1))),
      ),
      child: compteur,
    );
  }

  /// Le bandeau qui accueille un nouvel abonné.
  Widget _bandeauBienvenue() {
    // Comme sur le site : un simple encadré doré, sans croix. Le toucher
    // le referme (sur le site, il disparaît au rechargement de la page).
    return GestureDetector(
      onTap: () => setState(() => _justPaid = false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: TytoColors.fauve.withOpacity(0.12),
          border: Border.all(color: TytoColors.fauve.withOpacity(0.47)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Bienvenue en Premium. Questions illimitées, réponses avancées et l'œil de Tyto sont à toi.",
          style: TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.lune).copyWith(height: 1.5),
        ),
      ),
    );
  }

  /// Le haut du contenu, qui défile avec la conversation comme sur le site :
  /// bienvenue, rappels imminents, choix de l'animal et lien aliments.
  Widget _hautDuFil() {
    final enfants = <Widget>[];
    if (_justPaid) {
      enfants.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ChatApparition(child: _bandeauBienvenue()),
      ));
    }
    final rappels = _rappelsImminents();
    if (rappels != null) enfants.add(rappels);
    if (_pets.isNotEmpty) enfants.add(_selecteurAnimal());
    final animal = _animalActif;
    if (_pets.isNotEmpty && animal != null) {
      enfants.add(Padding(padding: const EdgeInsets.only(top: 2), child: _lienAliments(animal)));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: enfants,
    );
  }

  /// La fenêtre « L'œil de Tyto » du site, quand on touche l'œil sans
  /// être Premium.
  void _afficherOeilPremium() {
    final visiteur = !AuthService.isSignedIn;
    final peutPasser = visiteur || _offresAccessibles;
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB80A0E18), // rgba(10,14,24,0.72)
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _cartePapier(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("L'œil de Tyto", style: TytoText.display(size: 19, color: TytoColors.encre)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.55),
                    children: const [
                      TextSpan(
                          text: "Photographie une plante, un aliment, un insecte ou un bouton suspect : "
                              "Tyto l'analyse pour ton compagnon. C'est une fonction "),
                      TextSpan(text: 'Premium', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: ', avec les questions illimitées.'),
                    ],
                  ),
                ),
                if (peutPasser) ...[
                  const SizedBox(height: 12),
                  _boutonDore(
                    PlatformInfo.estIOS ? 'Passer Premium' : 'Passer Premium — $_prixPremium',
                    () {
                      Navigator.pop(ctx);
                      if (visiteur) {
                        _ouvrirConnexion();
                      } else {
                        _ouvrirOffres();
                      }
                    },
                    pleineLargeur: true,
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Plus tard',
                        style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.encre.withOpacity(0.53))
                            .copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// L'encart du quota épuisé, sous l'accueil ou la conversation.
  Widget _carteQuota(bool visiteur) {
    final corps = TytoText.body(size: 15.5, color: TytoColors.encre).copyWith(height: 1.55);
    const gras = TextStyle(fontWeight: FontWeight.w700);
    final note = TytoText.ui(size: 11.5, weight: FontWeight.w400, color: TytoColors.encre.withOpacity(0.53));
    final titre = TytoText.display(size: 19, color: TytoColors.encre);
    final List<Widget> enfants;
    if (visiteur) {
      enfants = [
        Text("Tes 8 questions d'essai sont utilisées", style: titre),
        const SizedBox(height: 6),
        Text.rich(TextSpan(style: corps, children: const [
          TextSpan(text: 'Crée ton '),
          TextSpan(text: 'compte gratuit', style: gras),
          TextSpan(text: ' — juste un email — pour passer à '),
          TextSpan(text: '15 questions par jour', style: gras),
          TextSpan(
              text: ' et débloquer les profils de compagnons, le carnet de santé et les rappels de vaccins.'),
        ])),
        const SizedBox(height: 12),
        _boutonDore('Créer mon compte gratuit', _ouvrirConnexion,
            icone: SiteIcon('IconMail', size: 15, color: TytoColors.nuit), extraBas: 3),
        const SizedBox(height: 8),
        Text('Ou reviens demain pour 8 nouvelles questions.', style: note),
      ];
    } else if (_offresAccessibles) {
      enfants = [
        Text('Tes 15 questions du jour se sont envolées', style: titre),
        const SizedBox(height: 6),
        Text.rich(TextSpan(style: corps, children: const [
          TextSpan(text: 'Reviens demain — ou passe en '),
          TextSpan(text: 'Premium', style: gras),
          TextSpan(text: ' : questions illimitées, réponses plus poussées et '),
          TextSpan(text: "l'œil de Tyto", style: gras),
          TextSpan(text: ' (analyse de photos).'),
        ])),
        const SizedBox(height: 12),
        _boutonDore(PlatformInfo.estIOS ? 'Passer Premium' : 'Passer Premium — $_prixPremium', _ouvrirOffres),
        if (!PlatformInfo.estIOS) ...[
          const SizedBox(height: 8),
          Text('Sans engagement, résiliable en deux clics.', style: note),
        ],
      ];
    } else {
      // iOS sans achats intégrés : aucune offre payante à proposer.
      enfants = [
        Text('Tes 15 questions du jour se sont envolées', style: titre),
        const SizedBox(height: 6),
        Text('Reviens demain pour 15 nouvelles questions.', style: corps),
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ChatApparition(
        child: SizedBox(
          width: double.infinity,
          child: _cartePapier(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: enfants,
            ),
          ),
        ),
      ),
    );
  }

  /// La bulle de l'utilisateur : fond fauve translucide, liseré doré,
  /// coin bas-droit rentré.
  Widget _bulleUtilisateur(_Message m, double largeurUtile) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: largeurUtile * 0.85),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.image != null)
              // La photo envoyée pendant cette visite, comme sur le site.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(m.image!),
                ),
              )
            else if (m.hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Opacity(
                  opacity: 0.75,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SiteIcon('IconCamera', size: 13, color: TytoColors.lune),
                      const SizedBox(width: 5),
                      Text('Photo envoyée',
                          style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.lune)),
                    ],
                  ),
                ),
              ),
            Text(
              m.content,
              style: TytoText.ui(size: 15, weight: FontWeight.w400, color: TytoColors.lune).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  /// La réponse de Tyto : la carte ivoire, avec son en-tête « TYTO » et
  /// la chouette.
  Widget _carteTyto(_Message m, double largeurUtile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        constraints: BoxConstraints(maxWidth: largeurUtile * 0.94),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OwlSketch(size: 17, ink: TytoColors.encre, detail: false),
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
  }

  /// « Tyto observe… » — la carte ivoire avec la chouette qui cligne vite.
  Widget _carteAttente() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
            const OwlSketch(size: 19, ink: TytoColors.encre, detail: false, thinking: true),
            const SizedBox(width: 9),
            Text(
              'Tyto observe',
              style: TytoText.body(size: 15, color: TytoColors.encre).copyWith(fontStyle: FontStyle.italic),
            ),
            _PointsAnimes(controller: _pulse),
          ],
        ),
      ),
    );
  }

  /// La réponse n'est pas arrivée : le cadre pointillé doré du site, avec
  /// le bouton « Réessayer ».
  Widget _carteErreur(double largeurUtile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeurUtile * 0.94),
        child: CustomPaint(
          foregroundPainter: _BordPointille(couleur: TytoColors.fauve.withOpacity(0.53), rayon: 12),
          child: Container(
            // 12 / 16 de marge intérieure, plus le trait de 1 px.
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            decoration: BoxDecoration(
              color: TytoColors.lune.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mes plumes se sont emmêlées en chemin — la réponse n'est pas arrivée.",
                  style: TytoText.ui(size: 14, weight: FontWeight.w400, color: TytoColors.lune).copyWith(height: 1.5),
                ),
                const SizedBox(height: 9),
                _boutonDore(
                  'Réessayer',
                  _relancer,
                  taille: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La conversation ouverte, précédée du haut de page (qui défile avec
  /// elle, comme sur le site).
  Widget _buildFil(bool visiteur) {
    final largeurUtile = min(MediaQuery.of(context).size.width, 720.0) - 32;
    final enAttente = _sending && _cleEnvoi == _cleConversation;
    // Chaque bloc apparaît comme les « .msg » du site (fondu + montée de
    // 7 px). La clé propre à chaque message sert aussi à y faire défiler
    // depuis le panneau d'historique.
    final elements = <Widget>[
      for (final m in _thread)
        KeyedSubtree(
          key: GlobalObjectKey(m),
          child: ChatApparition(
            child: m.role == 'user' ? _bulleUtilisateur(m, largeurUtile) : _carteTyto(m, largeurUtile),
          ),
        ),
      if (enAttente)
        KeyedSubtree(
          key: const ValueKey('tyto-observe'),
          child: ChatApparition(child: _carteAttente()),
        ),
      if (_erreurEnvoi && !enAttente)
        KeyedSubtree(
          key: const ValueKey('plumes-emmelees'),
          child: ChatApparition(child: _carteErreur(largeurUtile)),
        ),
    ];
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(_marge, 8, _marge, 24),
      children: [
        _hautDuFil(),
        const SizedBox(height: 14),
        // 14 px entre deux messages, comme le « gap » du site.
        for (var i = 0; i < elements.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
            child: elements[i],
          ),
        if (_quotaEpuise) _carteQuota(visiteur),
      ],
    );
  }

  /// L'encart au-dessus de la saisie : l'anniversaire du jour d'abord,
  /// sinon « Le savais-tu ? » / conseil de saison, qu'on touche pour en
  /// piocher un autre.
  Widget _encart() {
    final anniv = _animalAnniversaire;
    if (anniv != null && !_anniversaireMasque) {
      final age = DateTime.now().year - anniv.birthdate!.year;
      return GestureDetector(
        onTap: () => setState(() => _anniversaireMasque = true),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Color.alphaBlend(TytoColors.fauve.withOpacity(0.078), TytoColors.nuit2),
            border: Border.all(color: TytoColors.fauve.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SiteIcon('IconSparkle', size: 14, color: TytoColors.fauve),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: _policeSysteme(size: 12.5).copyWith(height: 1.45),
                    children: [
                      TextSpan(
                        text: 'Joyeux anniversaire ${anniv.name} !',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: TytoColors.fauve),
                      ),
                      TextSpan(
                          text: " $age an${age > 1 ? 's' : ''} aujourd'hui — Tyto lui souhaite une belle journée."),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_fait.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _nextFact,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: TytoColors.nuit2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TytoColors.lune.withOpacity(0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SiteIcon(_faitEstSaison ? 'IconAlert' : 'IconBulb', size: 14, color: TytoColors.fauve),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: _policeSysteme(size: 12.5, color: TytoColors.brume)
                      .copyWith(fontStyle: FontStyle.italic, height: 1.45),
                  children: [
                    TextSpan(
                      text: _faitEstSaison ? 'Conseil de saison : ' : 'Le savais-tu ? ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontStyle: FontStyle.normal, color: TytoColors.lune),
                    ),
                    TextSpan(text: _fait),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// L'aperçu de la photo prête à partir, comme sur le site.
  Widget _apercuPhoto() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TytoColors.fauve),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.file(_photoJointe!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Photo prête à envoyer',
                style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.brume)),
          ),
          const SizedBox(width: 10),
          _boutonFantomeTexte('Retirer la photo', _retirerPhoto),
        ],
      ),
    );
  }

  /// Le petit bouton doré au-dessus de la saisie quand le quota est épuisé.
  Widget _boutonQuotaPied(bool visiteur) {
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Align(
        alignment: Alignment.centerRight,
        child: visiteur
            ? _boutonDore('Se connecter pour continuer', _ouvrirConnexion,
                icone: SiteIcon('IconMail', size: 12, color: TytoColors.nuit),
                ecart: 5,
                taille: 12,
                padding: padding,
                extraBas: 2)
            : _boutonDore('Passer Premium', _ouvrirOffres,
                icone: SiteIcon('IconSparkle', size: 12, color: TytoColors.nuit),
                ecart: 5,
                taille: 12,
                padding: padding,
                extraBas: 2),
      ),
    );
  }

  /// Le gris des textes d'invite du navigateur (::placeholder).
  static const _gristInvite = Color(0xFF757575);

  /// Le texte du champ de saisie du site : Karla 15,5 px, interligne 1,4.
  TextStyle _styleSaisie(Color couleur) =>
      TytoText.ui(size: 15.5, weight: FontWeight.w400, color: couleur).copyWith(height: 1.4);

  /// Le champ vide quand le quota est épuisé, tel que le site l'affiche :
  /// son textarea ne fait qu'une ligne (21,7 px + 8 px de marge en haut et
  /// en bas) ; l'invite, trop longue, passe à la ligne et le haut de la
  /// deuxième ligne dépasse dans la marge du bas, le reste est coupé.
  Widget _inviteQuotaCoupee() {
    return SizedBox(
      height: 15.5 * 1.4 + 16,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_texteInvite, style: _styleSaisie(_gristInvite)),
          ),
        ),
      ),
    );
  }

  /// La barre de saisie : un seul conteneur arrondi, l'œil de Tyto, le
  /// champ et la flèche d'envoi.
  Widget _barreDeSaisie() {
    final quota = _quotaEpuise;
    return Opacity(
      opacity: quota ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: TytoColors.nuit2,
          borderRadius: BorderRadius.circular(22),
          // border: 1px solid LUNE + "30" (19 %), comme le site
          border: Border.all(color: TytoColors.lune.withOpacity(0.19)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _compressionEnCours
                ? const SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TytoColors.fauve),
                      ),
                    ),
                  )
                : OwlEyeButton(
                    onTap: quota ? null : _choisirPhoto,
                    actif: _isPremium || _isPro,
                  ),
            const SizedBox(width: 8),
            Expanded(
              // Le champ grandit avec la question jusqu'à 120 px de haut,
              // marges comprises (max-height du site), puis défile.
              child: quota && _controller.text.isEmpty
                  ? _inviteQuotaCoupee()
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _controller,
                        enabled: !quota,
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        style: _styleSaisie(TytoColors.lune),
                        cursorColor: TytoColors.lune,
                        decoration: InputDecoration(
                          hintText: _texteInvite,
                          hintMaxLines: 1,
                          hintStyle: _styleSaisie(_gristInvite),
                          isDense: true,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Dicter sa question plutôt que la taper (fonction Pro de l'app).
            if (_isPro && !quota) ...[
              VoiceButton(
                size: 38,
                title: 'Dicter ma question',
                onText: (t) {
                  _controller.text = t;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            // Comme sur le site : toujours doré, mais plus terne tant
            // qu'il n'y a rien à envoyer, pendant l'attente ou sans quota.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, valeur, _) {
                final peutEnvoyer =
                    (valeur.text.trim().isNotEmpty || _photoJointe != null) && !_sending && !quota;
                return Semantics(
                  button: true,
                  label: 'Envoyer',
                  child: GestureDetector(
                    onTap: peutEnvoyer ? () => _sendMessage() : null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: peutEnvoyer ? 1.0 : 0.35,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: TytoColors.fauve),
                        alignment: Alignment.center,
                        child: TytoIcon.envoyer(size: 18, color: TytoColors.nuit),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// La ligne de liens sous la saisie, comme le pied de page du site.
  Widget _liensDuPied(bool visiteur) {
    final style = TytoText.ui(size: 10.5, weight: FontWeight.w400, color: TytoColors.brume);
    Widget lien(String texte, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Text(
          texte,
          style: style.copyWith(decoration: TextDecoration.underline, decorationColor: TytoColors.brume),
        ),
      );
    }

    final liens = <Widget>[
      // Pas de lien vers les tarifs du site sur iOS (règle 3.1.1 d'Apple).
      if (!PlatformInfo.estIOS) lien('Tarifs', () => _ouvrirSite('/tarifs')),
      lien('Blog', () => _ouvrirSite('/blog')),
      lien('Aide', () => _ouvrirSite('/support')),
      if (_isPro) lien('CGV Pro', () => _ouvrirSite('/cgv-pro')),
      lien('Mentions légales', () => _ouvrirSite('/mentions-legales')),
      lien('CGU/CGV', () => _ouvrirSite('/cgu-cgv')),
      lien('Confidentialité', () => _ouvrirSite('/confidentialite')),
      if (!visiteur) lien('Supprimer mon compte', () => DeleteAccountDialog.afficher(context)),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 0,
      children: [
        for (var i = 0; i < liens.length; i++)
          // Chaque séparateur reste collé au lien qui le précède, pour que
          // les retours à la ligne tombent comme sur le site.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              liens[i],
              if (i < liens.length - 1) Text(' · ', style: style),
            ],
          ),
      ],
    );
  }

  /// Le pied de l'écran : encart, saisie et mentions, au-dessus d'un filet.
  Widget _piedDePage(bool clavierOuvert, bool visiteur) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: TytoColors.lune.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(_margePied, 10, _margePied, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_photoJointe != null) _apercuPhoto(),
              // Pendant la saisie, l'encart s'efface pour laisser de la
              // place à la conversation.
              if (!clavierOuvert) _encart(),
              if (_quotaEpuise && (visiteur || _offresAccessibles)) _boutonQuotaPied(visiteur),
              _barreDeSaisie(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
                child: Text(
                  'Tyto peut se tromper et ne remplace pas un vétérinaire.',
                  textAlign: TextAlign.center,
                  style: TytoText.ui(size: 11, weight: FontWeight.w400, color: TytoColors.brume).copyWith(height: 1.4),
                ),
              ),
              if (!clavierOuvert)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: _liensDuPied(visiteur),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// La colonne du site fait 720 px au plus, centrée (en-tête, contenu) :
  /// sur un téléphone il reste 16 px de chaque côté, sur une tablette la
  /// colonne est centrée et garde ses 16 px de marge intérieure.
  double get _marge {
    final largeur = MediaQuery.of(context).size.width;
    return largeur > 720 ? (largeur - 720) / 2 + 16 : 16.0;
  }

  /// Le pied du site : 16 px autour d'une colonne de 720 px au plus.
  double get _margePied {
    final largeur = MediaQuery.of(context).size.width;
    return largeur > 752 ? (largeur - 720) / 2 : 16.0;
  }

  @override
  Widget build(BuildContext context) {
    final visiteur = !AuthService.isSignedIn;
    final marge = _marge;
    final deuxLignes = _enTeteSurDeuxLignes(min(MediaQuery.of(context).size.width, 720.0));
    // Les empreintes couvrent tout l'écran, derrière l'en-tête comme sur le
    // site (couche « position: fixed » sous l'en-tête transparent).
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: SafeArea(child: PawTrails())),
        _echafaudage(visiteur, marge, deuxLignes),
      ],
    );
  }

  Widget _echafaudage(bool visiteur, double marge, bool deuxLignes) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: TytoDrawer(activeId: 'chat', onSelect: _onDrawerSelect, isPro: _isPro, isPremium: _isPremium),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // La ligne du site : 10 px au-dessus, éléments de 38 px, 6 px dessous.
        toolbarHeight: 54,
        centerTitle: false,
        // Le bouton du menu et le logo reprennent les mesures du site :
        // bouton 38 px à 16 px du bord, logo 30 px, « Tyto » en 20 px.
        leadingWidth: marge + 38,
        leading: Builder(
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(left: marge, top: 4),
            child: Center(
              child: Semantics(
                button: true,
                label: 'Ouvrir le menu',
                child: GestureDetector(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: TytoColors.lune.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TytoColors.lune.withOpacity(0.1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(height: 4.5),
                          Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: TytoColors.fauve,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              OwlSketch(size: 30, thinking: _sending),
              const SizedBox(width: 8),
              Text('Tyto', style: TytoText.display(size: 20)),
              if (_isPro || _isPremium) ...[
                const SizedBox(width: 8),
                _badgePlan(),
              ],
              if (!deuxLignes) ...[
                const Spacer(),
                // Le titre s'arrête déjà 8 px avant le bord : 8 de plus
                // placent URGENCE à 16 px du bord, comme sur le site.
                Padding(
                  padding: EdgeInsets.only(right: marge - 8),
                  child: _groupeDroite(),
                ),
              ],
            ],
          ),
        ),
        bottom: deuxLignes
            ? PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(marge, 0, marge, 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _groupeDroite(),
                  ),
                ),
              )
            : null,
      ),
      body: Builder(builder: (context) {
        final clavierOuvert = MediaQuery.of(context).viewInsets.bottom > 0;
        return Column(
          children: [
            _basEnTete(visiteur),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _thread.isEmpty ? _buildEmptyState(visiteur) : _buildFil(visiteur),
                  ),
                  // Remonter tout en haut d'une longue conversation, ou
                  // revenir au dernier message, d'un geste (à droite de la
                  // colonne, comme la flèche du site).
                  if (_thread.isNotEmpty && (_peutRedescendre || _peutRemonter))
                    Positioned(
                      right: marge,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_peutRemonter)
                            _boutonDefilement(_tracFlecheHaut, _scrollToTop, 'Remonter en haut'),
                          if (_peutRemonter && _peutRedescendre) const SizedBox(height: 10),
                          if (_peutRedescendre)
                            _boutonDefilement(_tracFlecheBas, _scrollToBottom, 'Revenir en bas'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _piedDePage(clavierOuvert, visiteur),
          ],
        );
      }),
    );
  }

  /// L'accueil : la chouette, la question et les puces de suggestion.
  /// Comme sur le site, le bloc d'accueil a une hauteur minimale de
  /// « 100dvh - 380px » (sa marge du haut de 8 px comprise), et son contenu
  /// y est centré ; tout défile avec le haut de page.
  Widget _buildEmptyState(bool visiteur) {
    // 100dvh = la hauteur visible de la page, sans la barre d'état ni la
    // barre système du bas (qui ne font pas partie de la fenêtre du site).
    final media = MediaQuery.of(context);
    final double hauteurMin = media.size.height - media.padding.top - media.padding.bottom - 380;
    return SingleChildScrollView(
      controller: _scrollAccueil,
      padding: EdgeInsets.fromLTRB(_marge, 8, _marge, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hautDuFil(),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: hauteurMin > 0 ? hauteurMin : 0.0),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(child: _accueil()),
            ),
          ),
          if (_quotaEpuise) _carteQuota(visiteur),
        ],
      ),
    );
  }

  Widget _accueil() {
    final animal = _animalActif;
    final sansAnimal = _animauxCharges && _pets.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const OwlSketch(size: 96),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            animal != null
                ? 'Que veux-tu savoir pour ${animal.name} ?'
                : "Que veux-tu savoir sur les animaux aujourd'hui ?",
            textAlign: TextAlign.center,
            style: TytoText.body(size: 17, color: TytoColors.brume).copyWith(fontStyle: FontStyle.italic, height: 1.5),
          ),
        ),
        if (sansAnimal) ...[
          const SizedBox(height: 10),
          Text(
            'Gratuit, sans inscription. Touche une question pour commencer.',
            textAlign: TextAlign.center,
            style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.brume),
          ),
        ],
        const SizedBox(height: 18),
        // Une hauteur minimale réservée (216 px, comme le site) : les puces
        // peuvent passer sur 2 lignes sans faire bouger la chouette.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, minHeight: 216),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var slot = 0; slot < _chipIdx.length; slot++)
                Padding(
                  padding: EdgeInsets.only(top: slot == 0 ? 0 : 9),
                  child: _puce(slot),
                ),
            ],
          ),
        ),
        if (sansAnimal)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: GestureDetector(
              // Comme le site (setEditingPet({})) : on arrive directement
              // sur le formulaire « Nouveau compagnon ».
              onTap: () => _ouvrirEcran(const PetsScreen(nouveauCompagnon: true)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SiteIcon('IconPlus', size: 12, color: TytoColors.brume),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Ou enregistre ton compagnon pour des réponses personnalisées',
                      textAlign: TextAlign.center,
                      style: TytoText.ui(size: 12.5, weight: FontWeight.w400, color: TytoColors.brume).copyWith(
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: TytoColors.brume,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Une puce de suggestion, avec le fondu et le léger glissement du site.
  Widget _puce(int slot) {
    final pIdx = _chipIdx[slot] % _suggestionPool.length;
    // Le site fait glisser la puce de 7 px exactement (translateY(7px)).
    return AnimatedContainer(
      duration: _fadeDuration,
      curve: _courbePuces,
      transform: Matrix4.translationValues(0.0, _chipVisible[slot] ? 0.0 : 7.0, 0.0),
      child: AnimatedOpacity(
        opacity: _chipVisible[slot] ? 1 : 0,
        duration: _fadeDuration,
        curve: _courbePuces,
        child: OutlinedButton(
          onPressed: () => _sendMessage(_suggestionPool[pIdx]),
          style: OutlinedButton.styleFrom(
            backgroundColor: TytoColors.lune.withOpacity(0.07),
            side: BorderSide(color: TytoColors.lune.withOpacity(0.23)),
            // 13 / 17 de marge comme le site, plus le trait de 1 px
            // (ici dessiné par-dessus la marge).
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            // Pas de hauteur minimale imposée : la puce fait sa taille
            // (47,6 px sur une ligne, comme sur le site).
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.centerLeft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SiteIcon('IconSparkle', size: 14, color: TytoColors.fauve),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _suggestionPool[pIdx],
                  style: TytoText.ui(size: 14.5, weight: FontWeight.w400, color: TytoColors.lune).copyWith(height: 1.35),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le cadre en pointillés du site (border: 1px dashed) : traits de 3 px,
/// espaces de 2 px, comme le dessine le navigateur.
class _BordPointille extends CustomPainter {
  final Color couleur;
  final double rayon;
  const _BordPointille({required this.couleur, required this.rayon});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final chemin = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rayon - 0.5)));
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final mesure in chemin.computeMetrics()) {
      double d = 0;
      while (d < mesure.length) {
        canvas.drawPath(mesure.extractPath(d, min(d + 3, mesure.length)), pinceau);
        d += 5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordPointille old) => old.couleur != couleur || old.rayon != rayon;
}

/// Les trois points de « Tyto observe… » : chacun s'allume à son tour,
/// avec le rythme exact de l'animation "dot" du site (cycle 1,3 s,
/// opacité 0,2 → 1, décalage de 0,2 s entre chaque point).
class _PointsAnimes extends StatelessWidget {
  final AnimationController controller;
  const _PointsAnimes({required this.controller});

  double _opacite(double t) {
    // 0 %, 60 % et 100 % -> 0,2   |   30 % -> 1, avec la courbe « ease »
    // que le navigateur applique entre deux étapes d'une animation CSS.
    if (t < 0.3) return 0.2 + 0.8 * Curves.ease.transform(t / 0.3);
    if (t < 0.6) return 1 - 0.8 * Curves.ease.transform((t - 0.3) / 0.3);
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

/// La mise en forme légère des réponses, comme RichText sur le site :
/// une ligne = un paragraphe, les lignes « • », « - » ou « * » forment
/// une liste à puces, et **…** passe en gras.
class _TexteRiche extends StatelessWidget {
  final String texte;
  const _TexteRiche({required this.texte});

  static final _puce = RegExp(r'^[•\-\*]\s+');
  static final _gras = RegExp(r'\*\*(.+?)\*\*');

  // Les mesures du site, en « em » d'une police de 16,5 px.
  static const double _taille = 16.5;
  static const double _hauteurLigne = 1.55;

  List<TextSpan> _morceaux(String ligne) {
    final spans = <TextSpan>[];
    var dernier = 0;
    for (final m in _gras.allMatches(ligne)) {
      if (m.start > dernier) spans.add(TextSpan(text: ligne.substring(dernier, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      dernier = m.end;
    }
    if (dernier < ligne.length) spans.add(TextSpan(text: ligne.substring(dernier)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // Découpage en blocs : paragraphes (String) et listes (List<String>).
    final blocs = <Object>[];
    var liste = <String>[];
    for (final brut in texte.split('\n')) {
      final t = brut.trim();
      if (_puce.hasMatch(t)) {
        liste.add(t.replaceFirst(_puce, ''));
      } else {
        if (liste.isNotEmpty) {
          blocs.add(liste);
          liste = <String>[];
        }
        if (t.isNotEmpty) blocs.add(t);
      }
    }
    if (liste.isNotEmpty) blocs.add(liste);

    final style = TytoText.body(size: _taille, color: TytoColors.encre).copyWith(
      height: _hauteurLigne,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final enfants = <Widget>[];
    for (var i = 0; i < blocs.length; i++) {
      final bloc = blocs[i];
      if (bloc is String) {
        enfants.add(Padding(
          // margin: 0.65em entre deux paragraphes
          padding: EdgeInsets.only(top: i == 0 ? 0 : 0.65 * _taille),
          child: Text.rich(TextSpan(style: style, children: _morceaux(bloc))),
        ));
      } else if (bloc is List<String>) {
        enfants.add(Padding(
          // margin: 0.55em au-dessus de la liste, 0.3em entre deux puces
          padding: const EdgeInsets.only(top: 0.55 * _taille),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < bloc.length; j++)
                Padding(
                  padding: EdgeInsets.only(top: j == 0 ? 0 : 0.3 * _taille),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // La puce ronde du navigateur : 5 px, centrée sur la
                      // première ligne, dans un retrait de 20 px.
                      SizedBox(
                        width: 20,
                        height: _taille * _hauteurLigne,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2.5),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: TytoColors.encre,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text.rich(TextSpan(style: style, children: _morceaux(bloc[j]))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ));
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: enfants,
    );
  }
}

class _Message {
  final String role;
  final String content;
  final bool hasImage;
  final File? image; // la photo envoyée pendant cette visite, pour l'afficher
  final DateTime date;
  _Message({required this.role, required this.content, this.hasImage = false, this.image, DateTime? date})
      : date = date ?? DateTime.now();
}
