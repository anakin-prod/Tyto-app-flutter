import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// La phrase de la page de lancement : un fait sur les animaux, différent à
// chaque ouverture. Ce sont des faits déjà présents sur le site
// (« Le savais-tu ? »), choisis parmi les plus courts et les plus sûrs.
// ============================================================

const List<String> phrasesLancement = [
  'Le colibri est le seul oiseau capable de voler en marche arrière.',
  'Les os des oiseaux sont creux, ce qui les allège pour le vol.',
  'Le hibou ne bouge pas ses yeux : il tourne la tête jusqu\'à 270°.',
  'Les perruches se donnent des « noms » : un cri unique par individu.',
  'Les corbeaux fabriquent et utilisent des outils.',
  'Les oiseaux voient des couleurs invisibles pour nous, dans l\'ultraviolet.',
  'Un colibri peut battre des ailes plus de 50 fois par seconde.',
  'Un pigeon voyageur retrouve son pigeonnier à plus de 1 000 km.',
  'La truffe d\'un chien a une empreinte unique, comme nos doigts.',
  'Un chiot naît sourd et aveugle, et ouvre les yeux vers 10 jours.',
  'Les dalmatiens naissent entièrement blancs : les taches viennent après.',
  'Un lévrier peut atteindre 70 km/h.',
  'Un chat peut sauter jusqu\'à six fois sa longueur, sans élan.',
  'Les chats ne perçoivent pas le goût sucré.',
  'La langue râpeuse du chat démêle son pelage comme une brosse.',
  'Les chats roux sont majoritairement des mâles.',
  'Les chats ont une troisième paupière, qui protège leur œil.',
  'Les moustaches d\'un chat mesurent à peu près la largeur de son corps.',
  'Le ronronnement d\'un chat vibre entre 25 et 150 hertz.',
  'Les dents d\'un lapin ne s\'arrêtent jamais de pousser.',
  'Un lapin ne peut pas vomir.',
  'Un lapin voit presque à 360° sans bouger la tête.',
  'Les cochons d\'Inde ne fabriquent pas leur vitamine C, comme nous.',
  'Les rats rient : ils émettent des ultrasons de joie quand on les chatouille.',
  'Les incisives des rongeurs sont orange : leur émail contient du fer.',
  'Le cochon d\'Inde naît les yeux ouverts et court dès les premières heures.',
  'Les serpents n\'ont pas de paupières : une écaille protège leurs yeux.',
  'Les serpents muent en une seule pièce, comme une chaussette retournée.',
  'Un caméléon bouge ses deux yeux indépendamment l\'un de l\'autre.',
  'Le gecko nettoie ses yeux d\'un coup de langue.',
  'Les carpes koï peuvent vivre plus de 50 ans.',
  'Le combattant respire l\'air de la surface grâce à son « labyrinthe ».',
  'Un poulain se lève dans l\'heure qui suit sa naissance.',
  'Chaque oreille du cheval est orientée par une dizaine de muscles.',
  'L\'œil du cheval est l\'un des plus grands des mammifères terrestres.',
  'Un hérisson possède entre 5 000 et 7 000 piquants.',
  'Les pieuvres goûtent ce qu\'elles touchent.',
  'Les poulpes ont trois cœurs.',
  'Les loutres de mer dorment en se tenant la patte.',
  'Les abeilles disent où sont les fleurs par une danse en huit.',
  'Un manchot empereur peut plonger à plus de 500 mètres.',
  'Les chèvres ont des pupilles rectangulaires.',
];

/// Choisit la phrase du lancement et se souvient de la dernière montrée pour
/// ne jamais afficher deux fois la même d'affilée.
class PhraseLancement {
  static const _cle = 'derniere_phrase_lancement';
  static String texte = phrasesLancement.first;

  /// À appeler une fois au démarrage, avant d'afficher la page de lancement.
  static Future<void> preparer() async {
    final hasard = Random();
    var index = hasard.nextInt(phrasesLancement.length);
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final derniere = prefs.getInt(_cle);
      if (derniere == index) index = (index + 1 + hasard.nextInt(phrasesLancement.length - 1)) % phrasesLancement.length;
    } catch (_) {}
    texte = phrasesLancement[index];
    try {
      await prefs?.setInt(_cle, index);
    } catch (_) {}
  }

  /// Le temps pendant lequel la page reste affichée : de quoi lire sans
  /// courir. La phrase n'apparaît qu'après environ 1,1 s (délai + fondu), puis
  /// on compte une quinzaine de caractères par seconde. De 4,5 à 6,5 secondes.
  static Duration get duree {
    final ms = 1100 + texte.length * 62;
    return Duration(milliseconds: ms.clamp(4500, 6500));
  }
}
