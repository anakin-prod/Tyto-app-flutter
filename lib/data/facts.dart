// ============================================================
// « Le savais-tu ? » — les mêmes faits que sur le site (lib/facts.js).
//
// Écrits à l'avance, choisis au hasard : aucun appel à l'IA,
// aucun crédit consommé, affichage instantané.
//
// Contextuel : quand la conversation d'un animal est ouverte, on
// pioche dans les faits de SON espèce. Sur « Général », on pioche
// dans tous les animaux mélangés.
// ============================================================

import 'dart:math';

const Map<String, List<String>> factsBySpecies = {
  'chien': [
    'le Basenji est le seul chien qui n\'aboie pas : il produit une sorte de jodel.',
    'un chien perçoit le temps différemment : son odorat lui dit depuis combien de temps tu es parti.',
    'les chiens ont un « pouls olfactif » : ils reniflent jusqu\'à 300 fois par minute en pistage.',
    'un lévrier peut atteindre 70 km/h, plus vite qu\'un cheval au galop sur courte distance.',
    'les chiens transpirent principalement par les coussinets de leurs pattes.',
    'un chien incline la tête pour mieux localiser l\'origine d\'un son… et mieux te comprendre.',
    'le museau humide du chien l\'aide à capter les molécules odorantes de l\'air.',
    'certains chiens savent compter jusqu\'à 4 ou 5, selon des études comportementales.',
    'un chien peut sentir une odeur jusqu\'à 10 000 à 100 000 fois mieux qu\'un humain.',
    'les chiens rêvent, et les petites races rêvent plus souvent que les grandes.',
    'un chien qui tourne en rond avant de se coucher reproduit un réflexe ancestral pour aplatir l\'herbe.',
    'la truffe d\'un chien a une empreinte unique, comme une empreinte digitale.',
    'un chien peut détecter certaines maladies, comme des baisses de glycémie, avant même les symptômes.',
    'les chiens bâillent par contagion en voyant leur maître bâiller, un peu comme nous.',
    'un chiot naît sourd et aveugle, et n\'ouvre les yeux qu\'au bout d\'une dizaine de jours.',
    'remuer la queue vers la droite plutôt que la gauche signale une émotion positive chez le chien.',
  ],
  'chat': [
    'un chat peut sauter jusqu\'à 6 fois sa longueur, sans élan.',
    'les chats ne perçoivent pas le goût sucré : ils n\'ont pas le récepteur pour ça.',
    'un chat adulte a 30 dents ; un chaton en a 26 de lait avant.',
    'quand un chat te cligne lentement des yeux, c\'est un signe de confiance — tu peux lui répondre pareil.',
    'un chat retombe sur ses pattes grâce à son « réflexe de redressement », efficace dès 30 cm de hauteur.',
    'la langue râpeuse du chat est couverte de petites pointes qui démêlent son pelage.',
    'un chat marque son territoire en se frottant : il dépose des phéromones par ses joues.',
    'les chats roux sont majoritairement des mâles, pour des raisons génétiques.',
    'un chat passe environ 70 % de sa vie à dormir, soit 13 à 16 heures par jour.',
    'le ronronnement d\'un chat vibre entre 25 et 150 Hz, une fréquence qui favorise la cicatrisation osseuse.',
    'un chat ne miaule quasiment jamais entre chats adultes : c\'est un langage qu\'il réserve aux humains.',
    'les moustaches d\'un chat mesurent à peu près la largeur de son corps, pour jauger un passage.',
    'un chat peut effectuer une rotation de 180° de ses oreilles grâce à plus de 20 muscles.',
    'les chats ont une troisième paupière, semi-transparente, qui protège l\'œil.',
    'un chat qui pétrit avec ses pattes reproduit un réflexe hérité de la tétée, chez sa mère.',
    'les empreintes du nez d\'un chat sont uniques, comme nos empreintes digitales.',
  ],
  'lapin': [
    'un lapin peut atteindre 50 km/h en pointe et changer de direction instantanément.',
    'les lapins mangent surtout à l\'aube et au crépuscule : ce sont des crépusculaires.',
    'un lapin qui s\'allonge sur le flanc d\'un coup, c\'est un « flop » : signe de détente totale.',
    'les lapins ronronnent à leur façon : un léger claquement de dents quand ils sont bien.',
    'la vision du lapin a un seul angle mort : juste devant son nez.',
    'un lapin peut voir presque à 360° autour de lui sans bouger la tête.',
    'les dents d\'un lapin poussent en continu toute sa vie, d\'où le besoin constant de ronger.',
    'un lapin heureux peut sauter en l\'air en se tordant : ce saut s\'appelle un « binky ».',
    'les lapins communiquent en tapant du pied pour signaler un danger aux autres.',
    'un lapin peut faire une crise cardiaque de peur si le stress est trop soudain.',
    'les lapins digèrent leur nourriture deux fois, en réingérant certaines crottes riches en nutriments.',
    'un lapin ne peut pas vomir : son système digestif ne le permet physiquement pas.',
  ],
  'oiseau': [
    'les corbeaux fabriquent et utilisent des outils, et savent résoudre des énigmes complexes.',
    'un canari peut apprendre des mélodies et les transmettre à ses petits.',
    'les perruches se donnent des « noms » : un cri unique par individu.',
    'le hibou ne peut pas bouger ses yeux : il compense en tournant la tête jusqu\'à 270°.',
    'certains cacatoès vivent plus de 80 ans, parfois plus longtemps que leur maître.',
    'les pigeons reconnaissent leur reflet dans un miroir, un signe d\'intelligence rare.',
    'certains oiseaux, comme les frégates, peuvent dormir en plein vol, un hémisphère du cerveau à la fois.',
    'un perroquet gris du Gabon peut apprendre plusieurs centaines de mots et les utiliser à bon escient.',
    'les os des oiseaux sont creux, ce qui les allège pour le vol.',
    'certains oiseaux migrateurs parcourent plus de 15 000 km sans quasiment s\'arrêter.',
    'un colibri peut battre des ailes plus de 50 fois par seconde.',
    'les oiseaux voient des couleurs invisibles pour l\'œil humain, dans l\'ultraviolet.',
  ],
  'rongeur': [
    'les rats rient : ils émettent des ultrasons de joie quand on les chatouille.',
    'un chinchilla prend des bains de poussière volcanique pour entretenir sa fourrure, la plus dense au monde.',
    'les gerbilles communiquent en tambourinant des pattes arrière.',
    'une souris peut passer par un trou de la taille d\'un stylo.',
    'les cochons d\'Inde ne fabriquent pas leur vitamine C : il faut la leur apporter, comme nous.',
    'un hamster peut stocker de la nourriture dans ses joues, jusqu\'à un volume proche de sa propre tête.',
    'les rongeurs ont des dents qui poussent toute leur vie, tout comme les lapins.',
    'un cochon d\'Inde pousse un petit cri distinct pour chaque humain qu\'il reconnaît comme porteur de nourriture.',
    'les souris peuvent émettre des ultrasons, une forme de « chant », inaudible pour nous.',
    'un hamster peut parcourir plusieurs kilomètres par nuit dans sa roue, sans jamais quitter sa cage.',
  ],
  'reptile': [
    'les serpents n\'ont pas de paupières : une écaille transparente protège leurs yeux.',
    'un python peut rester plusieurs mois sans manger après un gros repas.',
    'la température d\'incubation des œufs détermine le sexe chez beaucoup de tortues.',
    'les serpents muent en une seule pièce, en se retournant comme une chaussette.',
    'le cœur d\'une tortue peut battre très lentement : quelques battements par minute en hibernation.',
    'un caméléon peut bouger ses deux yeux indépendamment, dans deux directions différentes.',
    'certains serpents « sentent » avec leur langue, qui capte des particules dans l\'air.',
    'une tortue peut respirer partiellement par la peau autour de son cloaque, sous l\'eau.',
    'les geckos peuvent courir sur un plafond grâce à des millions de poils microscopiques sous leurs pattes.',
    'un lézard peut se détacher volontairement la queue pour échapper à un prédateur, puis la régénérer.',
  ],
  'poisson': [
    'le combattant peut respirer l\'air de la surface grâce à un organe spécial, le labyrinthe.',
    'certains poissons dorment en s\'enveloppant dans un cocon de mucus, comme un pyjama.',
    'les carpes koï peuvent vivre plus de 50 ans ; la plus célèbre aurait dépassé 200 ans.',
    'un banc de poissons n\'a pas de chef : chacun réagit à ses voisins en une fraction de seconde.',
    'certains poissons, comme le poisson rouge, ont une mémoire de plusieurs mois, contrairement à l\'idée reçue.',
    'les poissons-clowns naissent tous mâles et peuvent changer de sexe en devenant femelle dominante.',
    'un poisson respire en captant l\'oxygène dissous dans l\'eau grâce à ses branchies.',
    'certains poissons communiquent entre eux par des sons, souvent inaudibles pour nous.',
    'les rayures d\'un poisson zèbre sont uniques à chaque individu.',
  ],
  'cheval': [
    'un cheval ne peut pas respirer par la bouche : uniquement par les naseaux.',
    'les chevaux dorment aussi couchés : c\'est le seul moment du sommeil paradoxal.',
    'un cheval boit entre 20 et 40 litres d\'eau par jour.',
    'les chevaux se reconnaissent entre eux à la voix, même après des années de séparation.',
    'le champ de vision du cheval a deux angles morts : juste devant son nez et juste derrière lui.',
    'un cheval peut dormir debout grâce à un système de verrouillage naturel dans ses articulations.',
    'les chevaux ont une vision quasi panoramique, à près de 350° autour d\'eux.',
    'un cheval peut reconnaître les expressions du visage humain, et s\'en souvenir.',
    'les chevaux communiquent beaucoup par les oreilles, dont la position trahit leur humeur.',
    'un cheval adulte a des dents qui continuent de pousser presque toute sa vie.',
  ],
  'autre': [
    'les fourmis ne dorment jamais vraiment : elles font des micro-siestes de quelques minutes.',
    'un hérisson possède entre 5 000 et 7 000 piquants, qu\'il renouvelle régulièrement.',
    'les pieuvres goûtent ce qu\'elles touchent : leurs ventouses ont des récepteurs gustatifs.',
    'le cœur d\'une baleine bleue est si grand qu\'un enfant pourrait ramper dans ses artères.',
    'les chèvres ont des pupilles rectangulaires, pour un champ de vision panoramique.',
    'un paresseux ne descend de son arbre qu\'une fois par semaine, pour ses besoins.',
    'les tortues marines peuvent vivre plus de 100 ans, certaines espèces bien au-delà.',
    'un escargot peut dormir jusqu\'à trois ans d\'affilée en période de sécheresse.',
    'les abeilles communiquent l\'emplacement des fleurs par une danse précise, en huit.',
    'certains axolotls peuvent régénérer un membre entier, y compris une partie du cerveau.',
    'les poulpes ont trois cœurs et un sang bleu, riche en cuivre plutôt qu\'en fer.',
  ],
};

/// Tous les faits mélangés — utilisé sur la conversation « Général ».
final List<String> factsGeneral =
    factsBySpecies.values.expand((l) => l).toList();

final _rnd = Random();

/// Pioche un fait, si possible différent du précédent.
/// [species] null ou inconnue -> on pioche dans tout.
String pickFact(String? species, String? lastFact) {
  final pool = (species != null && factsBySpecies.containsKey(species))
      ? factsBySpecies[species]!
      : factsGeneral;
  if (pool.isEmpty) return '';
  if (pool.length == 1) return pool.first;
  String next = lastFact ?? '';
  var garde = 0;
  while (next == lastFact && garde < 20) {
    next = pool[_rnd.nextInt(pool.length)];
    garde++;
  }
  return next;
}