// ============================================================
// SOS animal perdu — les conseils de recherche par espèce.
// Repris à l'identique de lib/lostpet.js.
// ============================================================

const Map<String, List<String>> lostAdviceBySpecies = {
  'chat': [
    'Un chat perdu se cache le plus souvent à moins de 200 mètres de chez lui, terré et silencieux, même si tu l\'appelles. Cherche minutieusement AVANT d\'élargir.',
    'Inspecte les caves, garages, abris de jardin et dessous de voitures — demande aux voisins d\'ouvrir les leurs : les chats s\'y retrouvent souvent enfermés.',
    'Cherche la nuit, quand tout est calme : appelle doucement et écoute. Beaucoup de chats répondent la nuit alors qu\'ils restent muets le jour.',
    'Sors sa litière et sa gamelle devant chez toi : leurs odeurs familières l\'aident à retrouver le chemin.',
    'Secoue sa boîte de croquettes en l\'appelant, et regarde aussi EN HAUT : arbres, toits, rebords.',
  ],
  'chien': [
    'Agis vite : contrairement au chat, un chien peut couvrir plusieurs kilomètres en quelques heures. Préviens immédiatement le voisinage et les réseaux.',
    'S\'il est craintif et que tu l\'aperçois, ne lui cours JAMAIS après : accroupis-toi, ouvre les bras, appelle-le joyeusement. Le poursuivre le fait fuir plus loin.',
    'Laisse un vêtement imprégné de ton odeur (et sa gamelle) à l\'endroit où il a été vu pour la dernière fois — les chiens y reviennent souvent.',
    'Retourne à ses lieux de balade habituels aux heures calmes : les chiens perdus reprennent les itinéraires connus.',
  ],
  'lapin': [
    'Cherche TOUT près et au ras du sol : buissons, haies, dessous de terrasse ou de cabanon. Un lapin s\'éloigne rarement, il se terre.',
    'Il sortira plutôt à l\'aube et au crépuscule, ses heures naturelles d\'activité : c\'est là qu\'il faut guetter.',
    'Pose son enclos ouvert, son foin et ses légumes préférés dehors : l\'odeur du terrier connu attire.',
    'Attention aux chiens et chats du secteur : un lapin dehors est vulnérable, chaque heure compte.',
  ],
  'oiseau': [
    'Il est probablement tout près, perché en hauteur — souvent incapable de redescendre par manque d\'habitude. Scrute les arbres alentour.',
    'Place sa cage dehors, bien visible, porte ouverte avec sa nourriture préférée : beaucoup d\'oiseaux y reviennent d\'eux-mêmes.',
    'Diffuse ses vocalises enregistrées, ou place la cage de son congénère dehors : les appels entre oiseaux portent loin.',
    'Cherche tôt le matin : c\'est le moment où il répondra le plus aux chants et aux appels.',
  ],
  'rongeur': [
    'Bonne nouvelle : il est presque certainement encore DANS la maison. Ferme les portes pièce par pièce et bouche les sorties vers l\'extérieur.',
    'Saupoudre un peu de farine devant les passages suspects (plinthes, meubles) : les empreintes te diront où il circule la nuit.',
    'Le piège doux : un seau avec une serviette au fond, sa friandise préférée dedans, et une rampe de livres pour y monter. Vérifie chaque matin.',
    'Cherche la nuit, à la lampe, dans le silence : ils sortent quand tout dort.',
  ],
  'reptile': [
    'Cherche les points CHAUDS : derrière le réfrigérateur, près des radiateurs, sous les appareils électriques. Un reptile échappé va vers la chaleur.',
    'Il bouge peu et lentement : inspecte minutieusement pièce par pièce en fermant chaque porte derrière toi, plutôt que de survoler toute la maison.',
    'Pose au sol un point chaud (bouillotte, tapis chauffant) avec une cachette sombre à côté : il peut s\'y installer de lui-même.',
    'Regarde dans les plis : rideaux, linge, dessous de coussins, chaussures. Ils adorent les interstices étroits.',
  ],
  'poisson': [
    'Un poisson « disparu » a souvent sauté : vérifie immédiatement tout autour et derrière l\'aquarium, y compris sous les meubles proches.',
    'Retrouvé rapidement et remis en eau, un poisson peut survivre à plusieurs minutes hors de l\'eau : agis vite et manipule-le avec les mains mouillées.',
    'S\'il est bien dans l\'aquarium mais invisible : vérifie les décors creux et le filtre — et couvre l\'aquarium à l\'avenir.',
  ],
  'cheval': [
    'Préviens IMMÉDIATEMENT la gendarmerie (17) : un cheval sur la route est un danger vital, pour lui comme pour les automobilistes. C\'est la priorité absolue.',
    'Alerte les voisins, agriculteurs et centres équestres du secteur : un cheval échappé rejoint souvent d\'autres chevaux — vérifie les prés alentour.',
    'Approche-le calmement avec un seau de grain que tu fais sonner : le bruit familier attire et rassure.',
    'Inspecte ta clôture pour trouver et réparer le point de fuite avant son retour.',
  ],
  'autre': [
    'Commence par chercher tout près : la plupart des animaux perdus restent d\'abord cachés à proximité immédiate, terrés et silencieux.',
    'Place ses affaires familières dehors (couchage, nourriture) : les odeurs connues sont un repère puissant.',
    'Cherche aux heures calmes, tôt le matin ou la nuit, en appelant doucement et en écoutant les réponses.',
  ],
};

List<String> lostAdviceFor(String species) =>
    lostAdviceBySpecies[species] ?? lostAdviceBySpecies['autre'] ?? [];

const String lostScamWarning =
    'Prudence : des escrocs ciblent les annonces d\'animaux perdus. Ne paie JAMAIS de « frais de transport » ou « frais vétérinaires » à un inconnu qui prétend avoir ton animal. Exige toujours une photo précise comme preuve, et méfie-toi des numéros surtaxés.';