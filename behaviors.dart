// ============================================================
// « Pourquoi il fait ça ? » — le décodeur de comportements.
//
// Les gestes mystérieux de chaque espèce, expliqués simplement.
// Pré-écrit, zéro appel IA : la fenêtre s'ouvre instantanément
// et ne coûte rien. Repris à l'identique de lib/behaviors.js.
// ============================================================

class BehaviorQA {
  final String question;
  final String reponse;
  const BehaviorQA(this.question, this.reponse);
}

const Map<String, List<BehaviorQA>> behaviorsBySpecies = {
  'chien': [
    BehaviorQA('Il tourne en rond avant de se coucher', 'Un réflexe hérité de ses ancêtres sauvages : ils aplatissaient l\'herbe et vérifiaient l\'absence de serpents ou d\'insectes avant de dormir. Ton canapé est sûr, mais le rituel reste.'),
    BehaviorQA('Il penche la tête quand tu lui parles', 'Il ajuste la position de ses oreilles pour mieux localiser d\'où vient le son, et certains chercheurs pensent qu\'il dégage aussi son champ de vision pour mieux lire ton visage. C\'est un signe d\'attention, pas de confusion.'),
    BehaviorQA('Il mange de l\'herbe', 'Comportement normal et très répandu : parfois pour se purger quand l\'estomac gêne, parfois juste parce que le goût lui plaît. Ça devient un signal à surveiller seulement si c\'est frénétique ou accompagné de vomissements répétés.'),
    BehaviorQA('Il se roule dans des odeurs fortes (et désagréables)', 'Un héritage de camouflage : masquer sa propre odeur sous celle de l\'environnement pour approcher ses proies sans être repéré. Insupportable pour toi, instinct de chasseur pour lui.'),
    BehaviorQA('Il te lèche le visage ou les mains', 'Chez le chiot, lécher la gueule de la mère déclenchait la régurgitation de nourriture. Devenu adulte, c\'est resté un geste d\'apaisement et d\'affection — sa façon de dire que tu es son point de repère.'),
    BehaviorQA('Il remue la queue... mais grogne en même temps', 'La queue qui remue signale une excitation, pas forcément de la joie ! Un chien tendu peut remuer la queue. Regarde l\'ensemble : oreilles, babines, posture. Le corps entier parle, pas juste la queue.'),
    BehaviorQA('Il gratte le sol après avoir fait ses besoins', 'Il ne cherche pas à enterrer : ses coussinets contiennent des glandes odorantes, et gratter dépose son odeur en plus du marquage visuel. C\'est une signature, pas du ménage.'),
    BehaviorQA('Il dort collé contre toi', 'Dans une meute, dormir ensemble c\'est la sécurité et la confiance absolue. Il te considère comme son groupe — et il surveille aussi ta chaleur, la meilleure place du lit.'),
  ],
  'chat': [
    BehaviorQA('Il pétrit avec ses pattes (le « patounage »)', 'Un réflexe de chaton : pétrir le ventre de sa mère stimulait la montée de lait. À l\'âge adulte, il le refait sur les surfaces douces — et sur toi — quand il se sent parfaitement bien. C\'est l\'un des plus grands compliments félins.'),
    BehaviorQA('Il te cligne des yeux lentement', 'Le « baiser félin » : fermer les yeux devant quelqu\'un, c\'est se rendre volontairement vulnérable, donc une preuve de confiance totale. Tu peux lui répondre en clignant lentement à ton tour — beaucoup de chats répondent.'),
    BehaviorQA('Il te rapporte des proies (vraies ou jouets)', 'Plusieurs lectures possibles : instinct de rapporter la nourriture en lieu sûr, ou comportement maternel — certaines chattes « apprennent à chasser » à leur famille. Dans tous les cas, tu fais partie de son cercle.'),
    BehaviorQA('Il pousse les objets du bord de la table', 'Un mélange d\'instinct de chasse (tester si « ça » réagit) et d\'expérimentation — et si tu réagis à chaque fois, il apprend vite que c\'est un excellent moyen d\'attirer ton attention.'),
    BehaviorQA('Il fait ses griffes sur le canapé', 'Ce n\'est pas de la destruction gratuite : il entretient ses griffes, s\'étire, et surtout marque son territoire (visuellement et par les glandes de ses coussinets). Un griffoir placé PRÈS du canapé détourne souvent le geste.'),
    BehaviorQA('Il se frotte contre tes jambes', 'Ses joues et ses flancs déposent des phéromones : il te « marque » comme faisant partie de son territoire rassurant. C\'est un mélange de bonjour, d\'affection et d\'appropriation totale.'),
    BehaviorQA('Il fait la « fusée » à 23h (le quart d\'heure de folie)', 'Le chat est crépusculaire : programmé pour chasser à l\'aube et au crépuscule. Ces sprints soudains évacuent l\'énergie de chasse accumulée dans la journée. Une session de jeu avant le coucher aide beaucoup.'),
    BehaviorQA('Il te fixe sans bouger', 'Contrairement aux humains, le regard fixe n\'est pas impoli chez le chat qui te connaît : il t\'observe, tout simplement. Accompagné de clignements lents, c\'est même affectueux. Le regard fixe hostile, lui, vient avec un corps tendu et des oreilles plaquées.'),
  ],
  'lapin': [
    BehaviorQA('Il fait un bond avec une torsion en l\'air (le « binky »)', 'L\'expression de joie pure du lapin ! Ce saut tordu, parfois avec un coup de tête, signifie qu\'il se sent en sécurité et heureux. Un lapin qui binky est un lapin épanoui.'),
    BehaviorQA('Il tape du pied par terre', 'Un signal d\'alarme hérité de la vie sauvage : le tambourinage avertit les autres lapins d\'un danger. Chez toi, ça peut aussi exprimer un mécontentement franc — le lapin sait bouder.'),
    BehaviorQA('Il s\'allonge brusquement sur le flanc (le « flop »)', 'Impressionnant la première fois — on dirait qu\'il s\'effondre ! C\'est en réalité le summum de la détente : un lapin ne s\'expose ainsi que s\'il se sent totalement en sécurité.'),
    BehaviorQA('Il pousse ta main avec son museau', 'Selon le contexte : soit une demande de caresses, soit au contraire « pousse-toi de mon chemin ». Le lapin est direct — s\'il revient se placer sous ta main, le message est clair.'),
    BehaviorQA('Il mange ses propres crottes', 'Parfaitement normal et même vital : les cæcotrophes (crottes molles, différentes des crottes rondes) sont réingérées pour une seconde digestion, riche en vitamines. Ne l\'en empêche jamais.'),
    BehaviorQA('Il frotte son menton partout', 'Sous son menton se trouvent des glandes odorantes : il marque son territoire, invisible pour toi, très clair pour lui. Tout ce qui est « mentonné » lui appartient — y compris toi.'),
    BehaviorQA('Il court autour de tes pieds en cercles', 'Chez un lapin non stérilisé, c\'est souvent une parade amoureuse (parfois avec de petits couinements). Sinon, c\'est de l\'excitation joyeuse — souvent à l\'heure du repas.'),
  ],
  'oiseau': [
    BehaviorQA('Il gonfle ses plumes', 'Brièvement : il réajuste son plumage ou évacue une tension, c\'est normal. Gonflé en permanence, en boule, c\'est différent : il lutte peut-être contre le froid ou couve quelque chose — à surveiller.'),
    BehaviorQA('Il se balance d\'avant en arrière ou danse', 'Souvent de l\'excitation ou une invitation au jeu, surtout en musique — beaucoup de perroquets ont un vrai sens du rythme. Un balancement répétitif et monotone, en revanche, peut signaler de l\'ennui.'),
    BehaviorQA('Il régurgite de la nourriture devant toi', 'Aussi étrange que ça paraisse, c\'est un cadeau d\'amour : les oiseaux nourrissent leur partenaire par régurgitation. Il te considère comme son compagnon privilégié.'),
    BehaviorQA('Il frotte son bec contre les barreaux ou le perchoir', 'L\'entretien normal du bec : il le nettoie et l\'use après le repas. Le bec pousse en continu, comme nos ongles.'),
    BehaviorQA('Il ne tient que sur une patte pour dormir', 'Position normale et même bon signe : elle réduit la perte de chaleur et signale un oiseau détendu. Un oiseau qui dort toujours sur deux pattes, plumes gonflées, est parfois un oiseau qui ne se sent pas bien.'),
    BehaviorQA('Il crie au lever et au coucher du soleil', 'Un instinct profond : dans la nature, le groupe se signale et se compte à l\'aube et au crépuscule. Ton salon est sa forêt — difficile de lutter contre des millions d\'années d\'évolution.'),
  ],
  'rongeur': [
    BehaviorQA('Il remplit ses joues à ras bord (hamster)', 'Ses abajoues sont de vrais sacs de transport extensibles : dans la nature, il fait des réserves dans son terrier. Vérifie juste qu\'il vide bien ses cachettes — la nourriture fraîche cachée peut moisir.'),
    BehaviorQA('Il « popcorne » (cochon d\'Inde)', 'Ces petits bonds verticaux soudains, comme du pop-corn qui éclate, sont l\'expression de joie typique du cochon d\'Inde, surtout jeune. C\'est bon signe !'),
    BehaviorQA('Il siffle quand tu ouvres le frigo (cochon d\'Inde)', 'Il a associé le bruit à la nourriture et te réclame franchement. Le cochon d\'Inde est l\'un des rares animaux qui « appelle » son humain avec un cri dédié à la nourriture.'),
    BehaviorQA('Il court dans sa roue la nuit', 'La plupart des rongeurs sont nocturnes ou crépusculaires : leur pic d\'activité tombe quand tu dors. Un hamster peut parcourir l\'équivalent de plusieurs kilomètres par nuit — c\'est son marathon naturel.'),
    BehaviorQA('Il ronge les barreaux de sa cage', 'Ses dents poussent en continu et il DOIT ronger — mais les barreaux peuvent signaler aussi de l\'ennui ou une cage trop petite. Propose plus de bois à ronger et d\'occupation ; si ça persiste, la cage mérite d\'être agrandie.'),
    BehaviorQA('Il fait sa toilette juste après que tu l\'as touché', 'Rien de personnel ! Il remet de l\'ordre dans son odeur corporelle, essentielle à son identité. Certains apprécient ton odeur, d\'autres préfèrent la leur.'),
  ],
  'reptile': [
    BehaviorQA('Il tire la langue sans arrêt (serpent, lézard)', 'C\'est sa façon de « sentir » : la langue capte les particules odorantes de l\'air et les analyse via l\'organe de Jacobson, au palais. Une langue active, c\'est un reptile curieux et en bonne forme.'),
    BehaviorQA('Il devient terne et ses yeux blanchissent', 'La mue approche : la vieille peau se détache, y compris l\'écaille qui couvre les yeux. Il peut être irritable et voir flou pendant quelques jours — évite de le manipuler, augmente l\'humidité.'),
    BehaviorQA('Il reste immobile sous sa lampe pendant des heures', 'Comportement vital : les reptiles ne produisent pas leur chaleur corporelle et doivent « recharger » au point chaud pour digérer et fonctionner. Ce n\'est pas de la paresse, c\'est de la thermorégulation.'),
    BehaviorQA('Il refuse de manger depuis des semaines (serpent)', 'Souvent normal : mue en approche, saison de reproduction, ou température d\'ambiance à revoir. Un serpent adulte en bonne santé peut jeûner longtemps sans danger — mais si l\'état général se dégrade, direction le vétérinaire.'),
    BehaviorQA('Il creuse frénétiquement le substrat', 'Selon l\'espèce et la saison : recherche de fraîcheur, préparation de ponte chez la femelle, ou exploration. Vérifie les températures du terrarium — creuser peut signaler un point chaud trop intense.'),
  ],
  'poisson': [
    BehaviorQA('Il fait des allers-retours le long de la vitre', 'Le « glass surfing » signale souvent du stress ou de l\'ennui : bac trop petit, manque de cachettes, paramètres d\'eau à vérifier. Un poisson serein explore calmement, il ne patrouille pas.'),
    BehaviorQA('Il reste près de la surface et « pipe » l\'air', 'Signal d\'alerte : l\'eau manque probablement d\'oxygène. Vérifie le brassage, la température (l\'eau chaude contient moins d\'oxygène) et la propreté du filtre rapidement.'),
    BehaviorQA('Il se frotte contre le décor', 'Occasionnellement, rien d\'inquiétant. Répété, c\'est le signe classique d\'un parasite ou d\'une irritation de la peau — observe s\'il apparaît des points blancs ou des zones abîmées.'),
    BehaviorQA('Il construit un nid de bulles (combattant)', 'Excellent signe ! Le mâle combattant construit un radeau de bulles collantes en surface quand il se sent bien et prêt à se reproduire. Un combattant qui bulle est un combattant heureux.'),
    BehaviorQA('Il change de couleur', 'Les poissons communiquent et réagissent par la couleur : stress (couleurs ternes), dominance ou parade (couleurs vives), nuit (teintes éteintes). Un changement brutal et durable mérite un contrôle de l\'eau.'),
  ],
  'cheval': [
    BehaviorQA('Il retrousse sa lèvre supérieure vers le ciel (le flehmen)', 'Cette grimace amusante lui sert à analyser finement une odeur : il aspire les molécules vers un organe olfactif spécial situé au palais. Fréquent face à une odeur nouvelle ou une jument.'),
    BehaviorQA('Il couche ses oreilles en arrière', 'Le baromètre de l\'humeur : oreilles plaquées = agacement, menace ou douleur. Oreilles souples et mobiles = détente et attention. Apprendre à lire les oreilles, c\'est apprendre à lire le cheval.'),
    BehaviorQA('Il gratte le sol avec son antérieur', 'Impatience, frustration ou anticipation (souvent avant le repas). Certains creusent aussi avant de se rouler. Si c\'est accompagné de regards vers le ventre, attention : ça peut signaler des coliques.'),
    BehaviorQA('Il se roule par terre juste après la douche', 'Frustrant mais parfaitement normal : la poussière protège sa peau des insectes et absorbe l\'excès d\'humidité. Pour lui, tu viens de retirer sa couche de protection — il la remet.'),
    BehaviorQA('Il « mordille » l\'encolure d\'un autre cheval', 'Le toilettage mutuel (grooming) : un rituel social très fort, réservé aux membres appréciés du groupe. Certains chevaux le proposent à leur humain — doucement sur l\'épaule.'),
    BehaviorQA('Il dort debout', 'Grâce à un système de verrouillage des articulations, il somnole debout, prêt à fuir — l\'instinct de proie. Mais pour le vrai sommeil profond (paradoxal), il DOIT se coucher : un cheval qui ne se couche jamais manque de sommeil.'),
  ],
  'autre': [
    BehaviorQA('Il est plus actif à l\'aube et au crépuscule', 'Beaucoup d\'espèces sont « crépusculaires » : ces heures offraient le meilleur compromis entre visibilité et discrétion face aux prédateurs. Ton animal vit encore à l\'heure de ses ancêtres.'),
    BehaviorQA('Il cache sa nourriture', 'L\'instinct de réserve : dans la nature, un repas trouvé n\'est jamais garanti le lendemain. Faire des stocks est un comportement de survie profondément ancré, même la gamelle pleine.'),
    BehaviorQA('Il fait sa toilette après un moment de stress', 'Le « comportement de substitution » : se toiletter apaise et fait redescendre la tension, un peu comme nous nous passons la main dans les cheveux. C\'est un mécanisme d\'auto-régulation sain.'),
  ],
};

List<BehaviorQA> behaviorsFor(String species) =>
    behaviorsBySpecies[species] ?? behaviorsBySpecies['autre'] ?? [];