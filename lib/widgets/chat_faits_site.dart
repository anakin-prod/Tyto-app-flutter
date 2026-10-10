// ============================================================
// « Le savais-tu ? » et « Conseil de saison » de l'encart du chat :
// les MÊMES textes que le site (lib/facts.js : FACTS_BY_SPECIES et
// SEASONAL_TIPS), recopiés tels quels, avec la même façon de piocher
// (pickFact / pickSeasonalTip).
//
// Fichier généré à partir de lib/facts.js du site : ne pas retoucher
// les textes à la main, pour qu'ils restent mot pour mot identiques.
// ============================================================

import 'dart:math';

final Random _hasardChat = Random();

/// Les faits par espèce (FACTS_BY_SPECIES du site).
const Map<String, List<String>> chatFaitsParEspece = {
  "chien": [
    "le chow-chow et le shar-peï ont la langue bleue-noire, un trait unique chez les chiens.",
    "les dalmatiens naissent entièrement blancs : leurs taches apparaissent au fil des semaines.",
    "des chiens entraînés détectent certaines maladies à l'odeur, avec des taux de réussite impressionnants dans les études.",
    "un chien n'a qu'environ 1 700 papilles gustatives, contre 9 000 chez l'humain — il « goûte » surtout avec son nez.",
    "les épaules du chien ne sont pas rattachées au squelette par une clavicule rigide : c'est ce qui allonge sa foulée.",
    "un chien de traîneau entraîné peut parcourir plus de 100 km dans une journée.",
    "le Basenji est le seul chien qui n'aboie pas : il produit une sorte de jodel.",
    "un chien perçoit le temps différemment : son odorat lui dit depuis combien de temps tu es parti.",
    "les chiens ont un « pouls olfactif » : ils reniflent jusqu'à 300 fois par minute en pistage.",
    "un lévrier peut atteindre 70 km/h, plus vite qu'un cheval au galop sur courte distance.",
    "les chiens transpirent principalement par les coussinets de leurs pattes.",
    "un chien incline la tête pour mieux localiser l'origine d'un son… et mieux te comprendre.",
    "le museau humide du chien l'aide à capter les molécules odorantes de l'air.",
    "certains chiens savent compter jusqu'à 4 ou 5, selon des études comportementales.",
    "un chien peut sentir une odeur jusqu'à 10 000 à 100 000 fois mieux qu'un humain.",
    "les chiens rêvent, et les petites races rêvent plus souvent que les grandes.",
    "la truffe d'un chien a une empreinte unique, comme une empreinte digitale.",
    "un chien peut détecter certaines maladies, comme des baisses de glycémie, avant même les symptômes.",
    "les chiens bâillent par contagion en voyant leur maître bâiller, un peu comme nous.",
    "un chiot naît sourd et aveugle, et n'ouvre les yeux qu'au bout d'une dizaine de jours.",
    "remuer la queue vers la droite plutôt que la gauche signale une émotion positive chez le chien.",
  ],
  "chat": [
    "un chat possède environ 244 os, une trentaine de plus que l'humain — souplesse oblige.",
    "les chats ont aussi des moustaches au-dessus des yeux et à l'arrière des pattes avant.",
    "un chat voit très mal de près : en dessous de 25 cm, il se fie à ses moustaches et à son odorat.",
    "l'ouïe du chat monte jusqu'à environ 64 000 Hz, bien au-delà de celle du chien.",
    "un chat domestique peut sprinter à près de 48 km/h sur quelques mètres.",
    "le guépard ronronne comme un chat domestique, mais le lion, lui, ne sait pas ronronner.",
    "un chat peut sauter jusqu'à 6 fois sa longueur, sans élan.",
    "les chats ne perçoivent pas le goût sucré : ils n'ont pas le récepteur pour ça.",
    "un chat adulte a 30 dents ; un chaton en a 26 de lait avant.",
    "un chat retombe sur ses pattes grâce à son « réflexe de redressement », efficace dès 30 cm de hauteur.",
    "la langue râpeuse du chat est couverte de petites pointes qui démêlent son pelage.",
    "les chats roux sont majoritairement des mâles, pour des raisons génétiques.",
    "un chat passe environ 70 % de sa vie à dormir, soit 13 à 16 heures par jour.",
    "le ronronnement d'un chat vibre entre 25 et 150 Hz, une fréquence qui favorise la cicatrisation osseuse.",
    "un chat ne miaule quasiment jamais entre chats adultes : c'est un langage qu'il réserve aux humains.",
    "les moustaches d'un chat mesurent à peu près la largeur de son corps, pour jauger un passage.",
    "un chat peut effectuer une rotation de 180° de ses oreilles grâce à plus de 20 muscles.",
    "les chats ont une troisième paupière, semi-transparente, qui protège l'œil.",
    "les empreintes du nez d'un chat sont uniques, comme nos empreintes digitales.",
  ],
  "lapin": [
    "le lapin n'est pas un rongeur : c'est un lagomorphe, cousin du lièvre, avec deux paires d'incisives supérieures.",
    "les dents d'un lapin poussent d'environ 10 cm par an, d'où l'importance vitale du foin.",
    "beaucoup de lapins dorment les yeux ouverts ou mi-clos, un héritage de proie toujours sur ses gardes.",
    "bien soigné, un lapin de compagnie peut vivre 10 à 12 ans.",
    "un lapin peut atteindre 50 km/h en pointe et changer de direction instantanément.",
    "les lapins mangent surtout à l'aube et au crépuscule : ce sont des crépusculaires.",
    "les lapins ronronnent à leur façon : un léger claquement de dents quand ils sont bien.",
    "la vision du lapin a un seul angle mort : juste devant son nez.",
    "un lapin peut voir presque à 360° autour de lui sans bouger la tête.",
    "les dents d'un lapin poussent en continu toute sa vie, d'où le besoin constant de ronger.",
    "un lapin peut faire une crise cardiaque de peur si le stress est trop soudain.",
    "un lapin ne peut pas vomir : son système digestif ne le permet physiquement pas.",
  ],
  "oiseau": [
    "le colibri est le seul oiseau capable de voler en marche arrière.",
    "les oiseaux n'ont pas de dents : leur gésier musculeux broie les aliments, parfois aidé de petits graviers.",
    "un pigeon voyageur peut retrouver son pigeonnier à plus de 1 000 km de distance.",
    "chez le canari, les zones du cerveau dédiées au chant se régénèrent chaque année à la saison des amours.",
    "les corbeaux fabriquent et utilisent des outils, et savent résoudre des énigmes complexes.",
    "un canari peut apprendre des mélodies et les transmettre à ses petits.",
    "les perruches se donnent des « noms » : un cri unique par individu.",
    "le hibou ne peut pas bouger ses yeux : il compense en tournant la tête jusqu'à 270°.",
    "certains cacatoès vivent plus de 80 ans, parfois plus longtemps que leur maître.",
    "les pigeons reconnaissent leur reflet dans un miroir, un signe d'intelligence rare.",
    "certains oiseaux, comme les frégates, peuvent dormir en plein vol, un hémisphère du cerveau à la fois.",
    "un perroquet gris du Gabon peut apprendre plusieurs centaines de mots et les utiliser à bon escient.",
    "les os des oiseaux sont creux, ce qui les allège pour le vol.",
    "certains oiseaux migrateurs parcourent plus de 15 000 km sans quasiment s'arrêter.",
    "un colibri peut battre des ailes plus de 50 fois par seconde.",
    "les oiseaux voient des couleurs invisibles pour l'œil humain, dans l'ultraviolet.",
  ],
  "rongeur": [
    "les incisives des rongeurs sont orange car leur émail est renforcé de fer.",
    "le cochon d'Inde naît les yeux ouverts, couvert de poils, et court dans les heures qui suivent.",
    "comme le cheval et le lapin, le chinchilla est incapable de vomir.",
    "les souris mâles « chantent » en ultrasons pour séduire les femelles, un chant inaudible pour nous.",
    "les rats rient : ils émettent des ultrasons de joie quand on les chatouille.",
    "un chinchilla prend des bains de poussière volcanique pour entretenir sa fourrure, la plus dense au monde.",
    "les gerbilles communiquent en tambourinant des pattes arrière.",
    "une souris peut passer par un trou de la taille d'un stylo.",
    "les cochons d'Inde ne fabriquent pas leur vitamine C : il faut la leur apporter, comme nous.",
    "un hamster peut stocker de la nourriture dans ses joues, jusqu'à un volume proche de sa propre tête.",
    "les rongeurs ont des dents qui poussent toute leur vie, tout comme les lapins.",
    "un cochon d'Inde pousse un petit cri distinct pour chaque humain qu'il reconnaît comme porteur de nourriture.",
    "les souris peuvent émettre des ultrasons, une forme de « chant », inaudible pour nous.",
    "un hamster peut parcourir plusieurs kilomètres par nuit dans sa roue, sans jamais quitter sa cage.",
  ],
  "reptile": [
    "les tortues existaient déjà avant les dinosaures : leur lignée dépasse les 200 millions d'années.",
    "le gecko n'a pas de paupières mobiles : il nettoie ses yeux d'un coup de langue.",
    "le basilic, un lézard d'Amérique centrale, court littéralement sur l'eau sur quelques mètres.",
    "chez certains serpents, les organes sont disposés en file indienne, et le cœur peut se déplacer légèrement pour laisser passer une grosse proie.",
    "les serpents n'ont pas de paupières : une écaille transparente protège leurs yeux.",
    "un python peut rester plusieurs mois sans manger après un gros repas.",
    "la température d'incubation des œufs détermine le sexe chez beaucoup de tortues.",
    "les serpents muent en une seule pièce, en se retournant comme une chaussette.",
    "le cœur d'une tortue peut battre très lentement : quelques battements par minute en hibernation.",
    "un caméléon peut bouger ses deux yeux indépendamment, dans deux directions différentes.",
    "une tortue peut respirer partiellement par la peau autour de son cloaque, sous l'eau.",
    "les geckos peuvent courir sur un plafond grâce à des millions de poils microscopiques sous leurs pattes.",
    "un lézard peut se détacher volontairement la queue pour échapper à un prédateur, puis la régénérer.",
  ],
  "poisson": [
    "les poissons perçoivent les vibrations de l'eau grâce à la ligne latérale, un organe sensoriel qui court le long de leurs flancs.",
    "le poisson-lune peut pondre jusqu'à 300 millions d'œufs, un record chez les vertébrés.",
    "plusieurs espèces de poissons voient l'ultraviolet, invisible pour l'œil humain.",
    "le record de longévité d'un poisson rouge dépasse 40 ans — bien loin du mythe de l'animal éphémère.",
    "le combattant peut respirer l'air de la surface grâce à un organe spécial, le labyrinthe.",
    "certains poissons dorment en s'enveloppant dans un cocon de mucus, comme un pyjama.",
    "les carpes koï peuvent vivre plus de 50 ans ; la plus célèbre aurait dépassé 200 ans.",
    "un banc de poissons n'a pas de chef : chacun réagit à ses voisins en une fraction de seconde.",
    "certains poissons, comme le poisson rouge, ont une mémoire de plusieurs mois, contrairement à l'idée reçue.",
    "les poissons-clowns naissent tous mâles et peuvent changer de sexe en devenant femelle dominante.",
    "un poisson respire en captant l'oxygène dissous dans l'eau grâce à ses branchies.",
    "certains poissons communiquent entre eux par des sons, souvent inaudibles pour nous.",
    "les rayures d'un poisson zèbre sont uniques à chaque individu.",
  ],
  "cheval": [
    "l'œil du cheval est l'un des plus grands de tous les mammifères terrestres.",
    "un poulain se lève dans l'heure qui suit sa naissance, et galope le jour même.",
    "un sabot met environ un an à repousser entièrement, de la couronne jusqu'au sol.",
    "chaque oreille du cheval est orientée par plus d'une dizaine de muscles indépendants.",
    "un cheval ne peut pas respirer par la bouche : uniquement par les naseaux.",
    "les chevaux dorment aussi couchés : c'est le seul moment du sommeil paradoxal.",
    "un cheval boit entre 20 et 40 litres d'eau par jour.",
    "les chevaux se reconnaissent entre eux à la voix, même après des années de séparation.",
    "le champ de vision du cheval a deux angles morts : juste devant son nez et juste derrière lui.",
    "les chevaux ont une vision quasi panoramique, à près de 350° autour d'eux.",
    "un cheval peut reconnaître les expressions du visage humain, et s'en souvenir.",
    "un cheval adulte a des dents qui continuent de pousser presque toute sa vie.",
  ],
  "autre": [
    "l'éléphant est le seul mammifère incapable de sauter : ses quatre pattes ne quittent jamais le sol en même temps.",
    "les loutres de mer dorment en se tenant la patte pour ne pas dériver loin les unes des autres.",
    "la crevette-mante frappe si vite que l'eau bout localement autour de son coup.",
    "les vaches nouent de vraies amitiés et montrent des signes de stress quand on les sépare de leur meilleure amie.",
    "un manchot empereur peut plonger à plus de 500 mètres de profondeur.",
    "la girafe ne dort qu'environ deux heures par jour, souvent par micro-siestes debout.",
    "l'ornithorynque détecte les champs électriques de ses proies avec son bec, les yeux fermés sous l'eau.",
    "certains corbeaux apportent de petits « cadeaux » aux humains qui les nourrissent régulièrement.",
    "les fourmis ne dorment jamais vraiment : elles font des micro-siestes de quelques minutes.",
    "un hérisson possède entre 5 000 et 7 000 piquants, qu'il renouvelle régulièrement.",
    "les pieuvres goûtent ce qu'elles touchent : leurs ventouses ont des récepteurs gustatifs.",
    "le cœur d'une baleine bleue est si grand qu'un enfant pourrait ramper dans ses artères.",
    "les chèvres ont des pupilles rectangulaires, pour un champ de vision panoramique.",
    "un paresseux ne descend de son arbre qu'une fois par semaine, pour ses besoins.",
    "les tortues marines peuvent vivre plus de 100 ans, certaines espèces bien au-delà.",
    "un escargot peut dormir jusqu'à trois ans d'affilée en période de sécheresse.",
    "les abeilles communiquent l'emplacement des fleurs par une danse précise, en huit.",
    "certains axolotls peuvent régénérer un membre entier, y compris une partie du cerveau.",
    "les poulpes ont trois cœurs et un sang bleu, riche en cuivre plutôt qu'en fer.",
  ],
};

/// Le pool « Général » : toutes les espèces mélangées (FACTS_GENERAL).
final List<String> chatFaitsGeneral = [
  for (final liste in chatFaitsParEspece.values) ...liste,
];

/// Un conseil de saison (SEASONAL_TIPS du site) : un texte, et les
/// espèces concernées (null = toutes les espèces).
class ChatConseilSaison {
  final String texte;
  final List<String>? especes;
  const ChatConseilSaison(this.texte, [this.especes]);
}

/// Les conseils de saison, mois par mois (1 = janvier).
const Map<int, List<ChatConseilSaison>> chatConseilsSaison = {
  1: [
    ChatConseilSaison(
      "l'antigel qui fuit des voitures a un goût sucré qui attire chiens et chats — quelques gouttes suffisent à être mortelles. Surveille les flaques colorées sur les parkings.",
    ),
    ChatConseilSaison(
      "le sel de déneigement irrite et crevasse les coussinets : rince les pattes de ton chien après chaque balade hivernale.",
      ["chien"],
    ),
    ChatConseilSaison(
      "en hiver, un animal qui vit dehors a besoin de plus de calories et d'une eau non gelée, vérifiée deux fois par jour.",
    ),
  ],
  2: [
    ChatConseilSaison(
      "la mue de fin d'hiver commence : un brossage régulier évite à ton chat d'avaler trop de poils (boules de poils, vomissements).",
      ["chat", "lapin"],
    ),
    ChatConseilSaison(
      "les journées rallongent : c'est la saison des premières chaleurs chez les chattes non stérilisées — fugues et miaulements nocturnes en vue.",
      ["chat"],
    ),
    ChatConseilSaison(
      "l'antigel reste un danger tout l'hiver : goût sucré, toxicité foudroyante. Un léchage de flaque suspecte = vétérinaire immédiatement.",
    ),
  ],
  3: [
    ChatConseilSaison(
      "les chenilles processionnaires descendent des pins de mars à mai : leur contact peut nécroser la langue d'un chien en quelques heures. Zone à pins = laisse courte et vigilance maximale.",
      ["chien", "chat"],
    ),
    ChatConseilSaison(
      "les tiques se réveillent avec les beaux jours : vérifie le traitement antiparasitaire et inspecte le pelage après chaque sortie.",
      ["chien", "chat"],
    ),
    ChatConseilSaison(
      "la grande mue de printemps arrive : brossages plus fréquents pour tout le monde, surtout les poils longs.",
    ),
  ],
  4: [
    ChatConseilSaison(
      "chocolat de Pâques = poison pour les chiens : le chocolat noir surtout. Les œufs cachés dans le jardin doivent être TOUS retrouvés avant de lâcher le chien.",
      ["chien"],
    ),
    ChatConseilSaison(
      "les chenilles processionnaires sont encore actives : un chien qui bave brutalement et se frotte la gueule après une balade = urgence vétérinaire.",
      ["chien"],
    ),
    ChatConseilSaison(
      "l'herbe de printemps très riche expose les chevaux à la fourbure : la mise à l'herbe doit être très progressive.",
      ["cheval"],
    ),
  ],
  5: [
    ChatConseilSaison(
      "le muguet du 1er mai est toxique pour chiens et chats (feuilles, fleurs, et même l'eau du vase). À tenir hors de portée.",
      ["chien", "chat"],
    ),
    ChatConseilSaison(
      "la saison des épillets commence : ces herbes sèches se glissent dans les oreilles, les narines et entre les coussinets, et migrent dans le corps. Inspection complète après chaque balade dans les herbes hautes.",
      ["chien"],
    ),
    ChatConseilSaison(
      "les tiques atteignent leur pic de printemps : traitement à jour et inspection minutieuse (oreilles, cou, aisselles) après chaque sortie.",
      ["chien", "chat", "cheval"],
    ),
  ],
  6: [
    ChatConseilSaison(
      "les premières chaleurs arrivent : un lapin souffre dès 28 °C — bouteille d'eau congelée enroulée dans un linge, pièce ventilée, jamais en plein soleil.",
      ["lapin", "rongeur"],
    ),
    ChatConseilSaison(
      "après chaque baignade, sèche bien les oreilles de ton chien : l'eau stagnante dans le conduit fait le lit des otites.",
      ["chien"],
    ),
    ChatConseilSaison(
      "dans le sud, les moustiques transmettent la leishmaniose aux chiens : protection antiparasitaire adaptée et éviter les sorties au crépuscule.",
      ["chien"],
    ),
  ],
  7: [
    ChatConseilSaison(
      "JAMAIS d'animal dans une voiture en été, même 10 minutes, même à l'ombre, même fenêtres entrouvertes : l'habitacle atteint 50 °C en un quart d'heure.",
    ),
    ChatConseilSaison(
      "le bitume brûlant abîme les coussinets : pose ta main dessus 5 secondes — si c'est trop chaud pour toi, c'est trop chaud pour lui. Balades tôt le matin ou tard le soir.",
      ["chien"],
    ),
    ChatConseilSaison(
      "les feux d'artifice du 14 juillet terrorisent beaucoup d'animaux : pièce calme, volets fermés, musique douce, et surtout ne pas les laisser dehors ce soir-là.",
    ),
  ],
  8: [
    ChatConseilSaison(
      "canicule : halètement extrême, léthargie, gencives rouge vif = coup de chaleur, urgence absolue. Rafraîchir progressivement (jamais d'eau glacée) et filer chez le vétérinaire.",
    ),
    ChatConseilSaison(
      "les eaux stagnantes d'été peuvent contenir des cyanobactéries mortelles pour les chiens : évite les baignades dans les plans d'eau troubles ou verdâtres.",
      ["chien"],
    ),
    ChatConseilSaison(
      "départ en vacances : vérifie que l'identification (puce) et le carnet de ton compagnon sont à jour, et repère un vétérinaire près de ton lieu de séjour.",
    ),
  ],
  9: [
    ChatConseilSaison(
      "la rentrée peut déclencher une anxiété de séparation : reprise en douceur, départs courts d'abord, et un jouet d'occupation pour les absences.",
      ["chien", "chat"],
    ),
    ChatConseilSaison(
      "les champignons d'automne poussent : certains sont mortels pour les chiens qui les gobent en balade. Interdit de ramasser en gueule !",
      ["chien"],
    ),
    ChatConseilSaison(
      "deuxième pic de tiques de l'année : on ne relâche pas le traitement antiparasitaire en automne.",
      ["chien", "chat"],
    ),
  ],
  10: [
    ChatConseilSaison(
      "marrons et glands sont toxiques pour les chiens (troubles digestifs, occlusion). En balade d'automne, on ne laisse pas mâchouiller.",
      ["chien"],
    ),
    ChatConseilSaison(
      "bonbons d'Halloween : le xylitol (édulcorant) est violemment toxique pour les chiens, et le chocolat aussi. Le sac de bonbons se range en hauteur.",
      ["chien"],
    ),
    ChatConseilSaison(
      "le froid qui revient réveille l'arthrose des seniors : un couchage épais, loin des courants d'air, change leur confort.",
      ["chien", "chat"],
    ),
  ],
  11: [
    ChatConseilSaison(
      "c'est la saison des fuites d'antigel : goût sucré, toxicité mortelle en quelques heures. Aucune flaque suspecte ne doit être léchée.",
    ),
    ChatConseilSaison(
      "cheminées et poêles fascinent les chats : pare-feu obligatoire, et attention aux coussinets sur les surfaces brûlantes.",
      ["chat"],
    ),
    ChatConseilSaison(
      "les changements d'alimentation d'automne (herbe, foin nouveau) favorisent les coliques : toute transition alimentaire doit être très progressive.",
      ["cheval"],
    ),
  ],
  12: [
    ChatConseilSaison(
      "le chocolat de Noël est la première cause d'intoxication canine de décembre : les boîtes se rangent en hauteur, pas sous le sapin.",
      ["chien"],
    ),
    ChatConseilSaison(
      "le sapin est un aimant à chats : boules cassées, guirlandes avalées (occlusion !), aiguilles irritantes. Fixe-le au mur et évite les guirlandes fines.",
      ["chat"],
    ),
    ChatConseilSaison(
      "poinsettia, houx et gui des décorations de fêtes sont toxiques pour chiens et chats. Raisins secs (bûches, pains d'épices) aussi.",
      ["chien", "chat"],
    ),
  ],
};

/// pickFact du site : un fait au hasard, de l'espèce si elle a sa liste,
/// sinon dans le pool général, en évitant de répéter le dernier.
String chatPiocherFait(String? espece, String? dernier) {
  final pool = (espece != null && chatFaitsParEspece.containsKey(espece))
      ? chatFaitsParEspece[espece]!
      : chatFaitsGeneral;
  if (pool.isEmpty) return '';
  if (pool.length == 1) return pool.first;
  var suivant = dernier;
  var garde = 0;
  while ((suivant == null || suivant == dernier) && garde < 50) {
    suivant = pool[_hasardChat.nextInt(pool.length)];
    garde++;
  }
  return suivant ?? pool.first;
}

/// pickSeasonalTip du site : un conseil du mois, pour l'espèce ouverte
/// (ou pour toutes si aucune), en évitant de répéter le dernier.
String? chatPiocherConseilSaison(int mois, String? espece, String? dernier) {
  final pool = (chatConseilsSaison[mois] ?? const <ChatConseilSaison>[])
      .where((t) => t.especes == null || espece == null || t.especes!.contains(espece))
      .toList();
  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.texte;
  var suivant = dernier;
  var garde = 0;
  while (suivant == dernier && garde < 10) {
    suivant = pool[_hasardChat.nextInt(pool.length)].texte;
    garde++;
  }
  return suivant;
}
