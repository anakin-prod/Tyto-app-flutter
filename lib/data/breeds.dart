// ============================================================
// Les prédispositions de santé par race : ce que l'on sait des
// points à surveiller chez les races les plus courantes.
//
// Ce sont des TENDANCES connues, pas des diagnostics : la plupart des
// animaux d'une race n'ont aucun de ces soucis, et un croisement n'en
// hérite pas forcément. Toujours à confirmer avec un vétérinaire.
// ============================================================

class RaceInfo {
  final String id;
  final String nom;
  final String espece;
  final List<String> alias;
  final List<String> points;
  const RaceInfo({
    required this.id,
    required this.nom,
    required this.espece,
    required this.alias,
    required this.points,
  });
}

const titreRace = "À surveiller pour sa race";
const avertissementRace = "Ce sont des tendances connues de la race : la plupart des animaux n'ont aucun de ces soucis, et un croisement n'en hérite pas forcément. Parles-en à ton vétérinaire lors des visites.";

const List<RaceInfo> races = [
  RaceInfo(
    id: 'bouledogue-francais', nom: "Bouledogue français", espece: 'chien',
    alias: ["bouledogue francais", "bouledogue", "french bulldog", "bulldog francais"],
    points: [
      "Respiration : le nez court rend l'effort et la chaleur difficiles (ronflements, essoufflement).",
      "Dos : vertèbres parfois malformées, risque de hernie discale.",
      "Peau : les plis demandent un nettoyage régulier, et les allergies sont fréquentes.",
    ],
  ),
  RaceInfo(
    id: 'bulldog-anglais', nom: "Bulldog anglais", espece: 'chien',
    alias: ["bulldog anglais", "english bulldog", "bulldog"],
    points: [
      "Respiration : le nez court rend l'effort et la chaleur difficiles.",
      "Peau : les plis s'infectent facilement s'ils ne sont pas nettoyés.",
      "Articulations : dysplasie de la hanche fréquente.",
    ],
  ),
  RaceInfo(
    id: 'carlin', nom: "Carlin", espece: 'chien',
    alias: ["carlin", "pug"],
    points: [
      "Respiration : le nez court rend la chaleur et l'effort difficiles.",
      "Yeux : très exposés aux blessures et aux ulcères de la cornée.",
      "Poids : il prend vite du poids, ce qui aggrave la respiration.",
    ],
  ),
  RaceInfo(
    id: 'berger-allemand', nom: "Berger allemand", espece: 'chien',
    alias: ["berger allemand", "german shepherd"],
    points: [
      "Articulations : dysplasie de la hanche et du coude.",
      "Colonne : une dégénérescence nerveuse (myélopathie) peut apparaître avec l'âge.",
      "Digestion : torsion d'estomac possible, c'est une urgence.",
    ],
  ),
  RaceInfo(
    id: 'labrador', nom: "Labrador", espece: 'chien',
    alias: ["labrador", "labrador retriever"],
    points: [
      "Poids : il prend très facilement du poids, ce qui fatigue ses articulations.",
      "Articulations : dysplasie de la hanche et du coude.",
      "Oreilles : otites fréquentes, surtout après la baignade.",
    ],
  ),
  RaceInfo(
    id: 'golden-retriever', nom: "Golden retriever", espece: 'chien',
    alias: ["golden retriever", "golden"],
    points: [
      "Tumeurs : elles sont fréquentes dans la race, fais examiner toute nouvelle grosseur.",
      "Articulations : dysplasie de la hanche et du coude.",
      "Peau et oreilles : allergies et otites courantes.",
    ],
  ),
  RaceInfo(
    id: 'berger-australien', nom: "Berger australien", espece: 'chien',
    alias: ["berger australien", "australian shepherd", "aussie"],
    points: [
      "Médicaments : beaucoup ont une mutation (MDR1) qui les rend sensibles à certains traitements, comme l'ivermectine. Demande un test à ton vétérinaire.",
      "Yeux : plusieurs maladies héréditaires de l'œil existent dans la race.",
      "Épilepsie : possible, à signaler dès une première crise.",
    ],
  ),
  RaceInfo(
    id: 'border-collie', nom: "Border collie", espece: 'chien',
    alias: ["border collie"],
    points: [
      "Articulations : dysplasie de la hanche possible.",
      "Yeux : anomalies héréditaires de l'œil possibles.",
      "Épilepsie : possible, à signaler dès une première crise.",
    ],
  ),
  RaceInfo(
    id: 'colley-shetland', nom: "Colley / Berger des Shetland", espece: 'chien',
    alias: ["colley", "collie", "rough collie", "berger des shetland", "shetland", "sheltie", "berger shetland"],
    points: [
      "Médicaments : une mutation fréquente (MDR1) les rend sensibles à certains traitements, comme l'ivermectine. Demande un test à ton vétérinaire.",
      "Yeux : l'anomalie de l'œil du colley est courante.",
    ],
  ),
  RaceInfo(
    id: 'cavalier-king-charles', nom: "Cavalier King Charles", espece: 'chien',
    alias: ["cavalier king charles", "cavalier king charles spaniel", "king charles"],
    points: [
      "Cœur : maladie de la valve mitrale précoce, un contrôle cardiaque régulier est conseillé.",
      "Cerveau : syringomyélie possible (douleur du cou, grattage dans le vide).",
      "Oreilles : otites fréquentes.",
    ],
  ),
  RaceInfo(
    id: 'caniche', nom: "Caniche", espece: 'chien',
    alias: ["caniche", "poodle", "caniche nain", "caniche toy"],
    points: [
      "Dents : le tartre s'installe vite, brossage et détartrage à prévoir.",
      "Rotule : luxation fréquente chez les petits formats.",
      "Yeux : atrophie progressive de la rétine possible.",
    ],
  ),
  RaceInfo(
    id: 'chihuahua', nom: "Chihuahua", espece: 'chien',
    alias: ["chihuahua"],
    points: [
      "Rotule : luxation fréquente (boiterie par intermittence).",
      "Trachée : elle peut s'affaisser, un harnais vaut mieux qu'un collier.",
      "Dents : tartre et déchaussement précoces.",
    ],
  ),
  RaceInfo(
    id: 'yorkshire', nom: "Yorkshire", espece: 'chien',
    alias: ["yorkshire", "yorkshire terrier", "yorkie"],
    points: [
      "Trachée : elle peut s'affaisser (toux sèche), un harnais vaut mieux qu'un collier.",
      "Rotule : luxation fréquente.",
      "Dents : tartre et déchaussement précoces.",
    ],
  ),
  RaceInfo(
    id: 'teckel', nom: "Teckel", espece: 'chien',
    alias: ["teckel", "dachshund"],
    points: [
      "Dos : hernie discale fréquente, évite les sauts et les escaliers répétés.",
      "Poids : le surpoids charge beaucoup son dos, garde-le mince.",
      "Dents : le tartre s'installe souvent, un brossage régulier aide.",
    ],
  ),
  RaceInfo(
    id: 'husky', nom: "Husky", espece: 'chien',
    alias: ["husky", "siberian husky", "husky siberien"],
    points: [
      "Yeux : cataracte et autres maladies héréditaires de l'œil.",
      "Chaleur : son double pelage le fait vite souffrir en été.",
      "Peau : une carence en zinc peut provoquer des croûtes autour des yeux et de la gueule.",
    ],
  ),
  RaceInfo(
    id: 'beagle', nom: "Beagle", espece: 'chien',
    alias: ["beagle"],
    points: [
      "Poids : très gourmand, il grossit vite.",
      "Oreilles : otites fréquentes.",
      "Épilepsie : possible dans la race.",
    ],
  ),
  RaceInfo(
    id: 'boxer', nom: "Boxer", espece: 'chien',
    alias: ["boxer"],
    points: [
      "Cœur : certaines formes de cardiomyopathie, un contrôle cardiaque est conseillé.",
      "Tumeurs : fréquentes, fais examiner toute nouvelle grosseur.",
      "Chaleur : le nez court le rend sensible aux fortes températures.",
    ],
  ),
  RaceInfo(
    id: 'rottweiler', nom: "Rottweiler", espece: 'chien',
    alias: ["rottweiler", "rottweil"],
    points: [
      "Articulations : dysplasie de la hanche et du coude.",
      "Genou : rupture du ligament croisé fréquente.",
      "Os : une boiterie qui dure doit être examinée sans attendre.",
    ],
  ),
  RaceInfo(
    id: 'dobermann', nom: "Dobermann", espece: 'chien',
    alias: ["dobermann", "doberman"],
    points: [
      "Cœur : cardiomyopathie dilatée, un dépistage régulier est recommandé.",
      "Sang : la maladie de von Willebrand existe, signale-le avant toute opération.",
      "Digestion : torsion d'estomac possible, c'est une urgence.",
    ],
  ),
  RaceInfo(
    id: 'cocker', nom: "Cocker", espece: 'chien',
    alias: ["cocker", "cocker spaniel", "cocker anglais", "cocker americain"],
    points: [
      "Oreilles : otites très fréquentes.",
      "Yeux : glaucome et atrophie de la rétine possibles.",
      "Peau : allergies courantes.",
    ],
  ),
  RaceInfo(
    id: 'shih-tzu', nom: "Shih tzu", espece: 'chien',
    alias: ["shih tzu", "shihtzu", "shih-tzu"],
    points: [
      "Yeux : sécheresse et ulcères fréquents (grands yeux saillants).",
      "Respiration : le nez court rend la chaleur difficile.",
      "Dents : tartre et déchaussement précoces.",
    ],
  ),
  RaceInfo(
    id: 'bouvier-bernois', nom: "Bouvier bernois", espece: 'chien',
    alias: ["bouvier bernois", "bernese mountain dog"],
    points: [
      "Tumeurs : fréquentes dans la race, consulte vite pour toute grosseur.",
      "Articulations : dysplasie de la hanche et du coude.",
      "Digestion : torsion d'estomac possible, c'est une urgence.",
    ],
  ),
  RaceInfo(
    id: 'dogue-allemand', nom: "Dogue allemand", espece: 'chien',
    alias: ["dogue allemand", "great dane"],
    points: [
      "Digestion : torsion d'estomac, c'est une urgence (ventre gonflé, agitation).",
      "Cœur : cardiomyopathie possible.",
      "Croissance : les articulations sont fragiles pendant la croissance.",
    ],
  ),
  RaceInfo(
    id: 'jack-russell', nom: "Jack Russell", espece: 'chien',
    alias: ["jack russell", "jack russel", "parson russell"],
    points: [
      "Yeux : luxation du cristallin possible.",
      "Rotule : luxation fréquente.",
      "Dents : le tartre s'installe souvent, un brossage régulier aide.",
    ],
  ),
  RaceInfo(
    id: 'maine-coon', nom: "Maine Coon", espece: 'chat',
    alias: ["maine coon", "mainecoon"],
    points: [
      "Cœur : cardiomyopathie hypertrophique, un dépistage par échographie est conseillé.",
      "Articulations : dysplasie de la hanche possible.",
      "Taille : un grand chat qui demande une alimentation adaptée.",
    ],
  ),
  RaceInfo(
    id: 'persan', nom: "Persan / Exotique", espece: 'chat',
    alias: ["persan", "chat persan", "exotic shorthair", "exotique", "exotic"],
    points: [
      "Reins : maladie polykystique, un dépistage est possible.",
      "Yeux : larmoiement fréquent, à nettoyer chaque jour.",
      "Respiration : le nez court peut gêner la respiration.",
    ],
  ),
  RaceInfo(
    id: 'siamois', nom: "Siamois / Oriental", espece: 'chat',
    alias: ["siamois", "siamese", "oriental", "thai"],
    points: [
      "Respiration : asthme félin possible (toux, respiration sifflante).",
      "Dents : gencives et dents à surveiller.",
    ],
  ),
  RaceInfo(
    id: 'british-shorthair', nom: "British Shorthair", espece: 'chat',
    alias: ["british shorthair", "british"],
    points: [
      "Cœur : cardiomyopathie hypertrophique possible, un dépistage est conseillé.",
      "Poids : tendance à grossir, surtout après la stérilisation.",
      "Dents : gencives et dents à surveiller (tartre, gingivite).",
    ],
  ),
  RaceInfo(
    id: 'ragdoll', nom: "Ragdoll", espece: 'chat',
    alias: ["ragdoll"],
    points: [
      "Cœur : cardiomyopathie hypertrophique possible, un dépistage est conseillé.",
      "Poids : tendance à grossir.",
    ],
  ),
  RaceInfo(
    id: 'bengal', nom: "Bengal", espece: 'chat',
    alias: ["bengal"],
    points: [
      "Cœur : cardiomyopathie hypertrophique possible.",
      "Yeux : atrophie progressive de la rétine dans certaines lignées.",
      "Sang : une anémie héréditaire existe (gencives pâles, fatigue).",
    ],
  ),
  RaceInfo(
    id: 'sphynx', nom: "Sphynx", espece: 'chat',
    alias: ["sphynx", "sphinx"],
    points: [
      "Cœur : cardiomyopathie hypertrophique possible.",
      "Peau : sans poils, elle se salit et brûle au soleil, un nettoyage régulier aide.",
      "Froid : il supporte mal les températures fraîches.",
    ],
  ),
  RaceInfo(
    id: 'scottish-fold', nom: "Scottish Fold", espece: 'chat',
    alias: ["scottish fold"],
    points: [
      "Articulations : les oreilles pliées sont liées à une maladie du cartilage, surveille raideur, boiterie et douleur.",
      "Cœur : cardiomyopathie possible.",
    ],
  ),
  RaceInfo(
    id: 'abyssin', nom: "Abyssin / Somali", espece: 'chat',
    alias: ["abyssin", "abyssinian", "somali"],
    points: [
      "Reins : une maladie rénale héréditaire (amyloïdose) existe.",
      "Yeux : atrophie progressive de la rétine dans certaines lignées.",
    ],
  ),
  RaceInfo(
    id: 'lapin-nain', nom: "Lapin nain", espece: 'lapin',
    alias: ["lapin nain", "nain", "tete de lion", "tête de lion"],
    points: [
      "Dents : elles poussent toute la vie, du foin à volonté les use naturellement.",
      "Yeux : le larmoiement signale souvent un canal obstrué ou un problème dentaire.",
      "Digestion : un transit qui s'arrête est une urgence.",
    ],
  ),
  RaceInfo(
    id: 'lapin-belier', nom: "Lapin bélier", espece: 'lapin',
    alias: ["belier", "lapin belier", "bélier"],
    points: [
      "Oreilles : tombantes, elles s'aèrent mal et s'infectent plus facilement.",
      "Dents : elles poussent toute la vie, du foin à volonté les use naturellement.",
      "Digestion : un transit qui s'arrête est une urgence.",
    ],
  ),
];

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ç': 'c', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
};

/// « Bouledogue Français ! » → « bouledogue francais » : sans accents, sans
/// majuscules, sans ponctuation, pour comparer des textes saisis à la main.
String _normaliser(String texte) {
  final tampon = StringBuffer();
  for (final rune in texte.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    final remplacement = _accents[c];
    if (remplacement != null) {
      tampon.write(remplacement);
    } else if ((rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57)) {
      tampon.write(c);
    } else {
      tampon.write(' ');
    }
  }
  return tampon.toString().split(' ').where((m) => m.isNotEmpty).join(' ');
}

/// La race reconnue dans le texte saisi, ou null. Les mots doivent
/// correspondre en entier (« carlin » ne se trouve pas dans « carlingue »),
/// et le nom le plus long l'emporte (« bulldog français » avant « bulldog »).
RaceInfo? racePourAnimal(String espece, String? race) {
  if (race == null) return null;
  final texte = _normaliser(race);
  if (texte.isEmpty) return null;
  final cherche = ' $texte ';
  RaceInfo? meilleure;
  var longueur = 0;
  for (final r in races) {
    if (r.espece != espece) continue;
    for (final a in r.alias) {
      final n = _normaliser(a);
      if (n.isEmpty) continue;
      if (cherche.contains(' $n ') && n.length > longueur) {
        meilleure = r;
        longueur = n.length;
      }
    }
  }
  return meilleure;
}
