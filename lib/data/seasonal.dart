// ============================================================
// Les conseils de saison : ce qu'il faut savoir, mois par mois,
// selon l'espèce — épillets, chaleur, froid, feux d'artifice…
//
// Écrit à l'avance, zéro appel à l'IA. Deux usages :
//  - une NOTIFICATION à la date prévue (notifMois/notifJour), pour
//    prévenir avant que la saison à risque commence ;
//  - un « Conseil de saison » dans l'encart « Le savais-tu ? »,
//    tant que la période (debut…fin) est en cours.
//
// Ce sont des conseils de prévention généraux : ils ne remplacent
// jamais l'avis d'un vétérinaire.
// ============================================================

import 'dart:math';

class AlerteSaison {
  final String id;
  final String titre;
  final String titreNotif;
  final String corps;
  final Set<String> especes;

  /// Un texte adapté à une espèce précise, quand le conseil général ne
  /// suffit pas (la chaleur n'est pas la même pour un lapin et un cheval).
  final Map<String, String> corpsParEspece;

  /// La période pendant laquelle l'alerte est « en cours » (peut enjamber
  /// le Nouvel An : du 1er décembre au 28 février).
  final int debutMois, debutJour, finMois, finJour;

  /// Le jour et l'heure de la notification.
  final int notifMois, notifJour, notifHeure, notifMinute;

  const AlerteSaison({
    required this.id,
    required this.titre,
    required this.titreNotif,
    required this.corps,
    required this.especes,
    this.corpsParEspece = const {},
    required this.debutMois,
    required this.debutJour,
    required this.finMois,
    required this.finJour,
    required this.notifMois,
    required this.notifJour,
    required this.notifHeure,
    required this.notifMinute,
  });

  String corpsPour(String espece) => corpsParEspece[espece] ?? corps;

  bool concerne(Set<String> mesEspeces) => especes.any(mesEspeces.contains);

  /// La période est-elle en cours ce jour-là ?
  bool actif(DateTime jour) {
    final j = jour.month * 100 + jour.day;
    final debut = debutMois * 100 + debutJour;
    final fin = finMois * 100 + finJour;
    // Si le début est après la fin, la période enjambe le Nouvel An.
    return debut <= fin ? (j >= debut && j <= fin) : (j >= debut || j <= fin);
  }
}

const List<AlerteSaison> alertesSaison = [
  AlerteSaison(
    id: 'processionnaire',
    titre: "Chenilles processionnaires",
    titreNotif: "Chenilles processionnaires",
    corps: "Les chenilles descendent des pins jusqu'en mai. Si ton compagnon en renifle ou en lèche une (langue gonflée, bave), file chez le vétérinaire sans attendre.",
    especes: {'chien', 'chat'},
    debutMois: 2, debutJour: 15, finMois: 5, finJour: 15,
    notifMois: 2, notifJour: 15, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'tiques',
    titre: "Tiques et puces",
    titreNotif: "Tiques et puces",
    corps: "Les tiques et les puces sont actives jusqu'à l'automne. Vérifie son pelage après chaque balade et demande à ton vétérinaire quelle protection antiparasitaire convient.",
    especes: {'chien', 'chat'},
    debutMois: 3, debutJour: 15, finMois: 11, finJour: 15,
    notifMois: 3, notifJour: 15, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'epillets',
    titre: "Épillets",
    titreNotif: "Épillets",
    corps: "Les épillets (graines d'herbes sèches) s'infiltrent dans les oreilles, le nez et entre les coussinets. Inspecte-le après chaque balade ; éternuements ou patte léchée : consulte.",
    especes: {'chien', 'chat'},
    debutMois: 5, debutJour: 15, finMois: 9, finJour: 15,
    notifMois: 5, notifJour: 15, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'chaleur',
    titre: "Coup de chaleur",
    titreNotif: "Coup de chaleur",
    corps: "Ne le laisse jamais dans une voiture, même vitres ouvertes. Prévois de l'ombre et de l'eau fraîche en permanence, et évite les efforts aux heures chaudes.",
    especes: {'chien', 'chat', 'lapin', 'rongeur', 'oiseau', 'reptile', 'poisson', 'cheval', 'autre'},
    corpsParEspece: {
      'chien': "Jamais dans une voiture, même vitres ouvertes. Balades tôt ou tard, eau fraîche à volonté. Halètement intense, gencives rouges, vomissements : urgence vétérinaire.",
      'chat': "Laisse-lui un coin frais et de l'eau à volonté ; sécurise les fenêtres ouvertes (risque de chute). Halètement ou prostration : vétérinaire.",
      'lapin': "Le lapin supporte très mal la chaleur, dès 25 °C environ. Cage à l'ombre et ventilée, carrelage frais, bouteille d'eau congelée à côté de lui. Prostration : urgence.",
      'rongeur': "Garde la cage loin du soleil et des fenêtres, jamais dans une pièce surchauffée. Respiration rapide ou prostration : vétérinaire.",
      'oiseau': "Cage à l'ombre, jamais en plein soleil ni dans une pièce surchauffée, eau fraîche renouvelée. Bec ouvert et ailes écartées : il a trop chaud, appelle le vétérinaire.",
      'reptile': "Surveille la température du terrarium : une lampe qui chauffe trop en été peut être dangereuse. Garde une zone fraîche et vérifie le thermomètre chaque jour.",
      'poisson': "En été, l'eau de l'aquarium chauffe vite : surveille le thermomètre et évite le soleil direct, pour que la température reste celle que supporte ton espèce.",
      'cheval': "Eau et ombre en permanence, travail aux heures fraîches, et surveille la transpiration et la respiration. Au moindre doute : vétérinaire.",
    },
    debutMois: 6, debutJour: 15, finMois: 9, finJour: 15,
    notifMois: 6, notifJour: 15, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'algues',
    titre: "Algues bleues",
    titreNotif: "Algues bleues",
    corps: "Évite que ton chien se baigne ou boive dans une eau stagnante ou verdâtre : les cyanobactéries peuvent être mortelles. Au moindre malaise après un bain, vétérinaire en urgence.",
    especes: {'chien'},
    debutMois: 7, debutJour: 1, finMois: 9, finJour: 30,
    notifMois: 7, notifJour: 1, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'feux14',
    titre: "Feux d'artifice",
    titreNotif: "Feux d'artifice demain soir",
    corps: "Les feux d'artifice affolent beaucoup d'animaux. Garde-le à l'intérieur, volets fermés, avec un coin tranquille et un peu de musique ; vérifie qu'il est identifié (puce) en cas de fugue.",
    especes: {'chien', 'chat', 'cheval', 'oiseau', 'lapin', 'rongeur'},
    debutMois: 7, debutJour: 12, finMois: 7, finJour: 15,
    notifMois: 7, notifJour: 13, notifHeure: 17, notifMinute: 0,
  ),
  AlerteSaison(
    id: 'champignons',
    titre: "Champignons",
    titreNotif: "Champignons",
    corps: "Certains champignons des sous-bois sont mortels pour un chien. Empêche-le d'en ronger ; vomissements, bave ou apathie après une balade : vétérinaire, avec un échantillon si possible.",
    especes: {'chien'},
    debutMois: 9, debutJour: 15, finMois: 11, finJour: 30,
    notifMois: 10, notifJour: 1, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'antigel',
    titre: "Antigel et sel de déneigement",
    titreNotif: "Antigel et sel de déneigement",
    corps: "L'antigel a un goût sucré et il est très toxique : range-le hors de portée et essuie toute flaque. Après une route salée, rince et sèche ses pattes. Ingestion suspectée : urgence.",
    especes: {'chien', 'chat'},
    debutMois: 11, debutJour: 1, finMois: 3, finJour: 15,
    notifMois: 11, notifJour: 15, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'froid',
    titre: "Froid et chauffage",
    titreNotif: "Froid et chauffage",
    corps: "Le froid demande de l'attention : abri sec, pas de courants d'air, et eau qui ne gèle pas.",
    especes: {'lapin', 'rongeur', 'oiseau', 'reptile', 'poisson', 'cheval'},
    corpsParEspece: {
      'lapin': "Un lapin d'extérieur supporte le froid sec s'il est à l'abri du vent et de l'humidité : litière épaisse et sèche, eau qui ne gèle pas.",
      'rongeur': "Garde la cage dans une pièce tempérée, à l'abri des courants d'air, avec de quoi se faire un nid chaud.",
      'oiseau': "Pas de courants d'air ni de grands écarts de température près de la cage. Un oiseau frileux gonfle ses plumes : garde la pièce tempérée.",
      'reptile': "Vérifie chaque jour la chaleur du terrarium (thermomètre, chauffage, lampe) : une panne en hiver peut vite être grave.",
      'poisson': "Vérifie que le chauffage de l'aquarium fonctionne et que la température reste stable : une panne en hiver peut vite devenir un problème.",
      'cheval': "Eau non gelée, abri contre le vent et la pluie, foin en quantité : il se réchauffe en mangeant. Couverture si besoin selon son poil et son âge.",
    },
    debutMois: 12, debutJour: 1, finMois: 2, finJour: 28,
    notifMois: 12, notifJour: 1, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'fetes',
    titre: "Fêtes de fin d'année",
    titreNotif: "Fêtes de fin d'année",
    corps: "Chocolat, raisins, houx, gui, poinsettia, guirlandes à avaler : plusieurs mets et décorations de fête sont toxiques. Garde-les hors de portée ; ingestion suspectée : vétérinaire.",
    especes: {'chien', 'chat'},
    debutMois: 12, debutJour: 15, finMois: 1, finJour: 2,
    notifMois: 12, notifJour: 15, notifHeure: 9, notifMinute: 30,
  ),
  AlerteSaison(
    id: 'feux31',
    titre: "Feux d'artifice",
    titreNotif: "Feux d'artifice demain soir",
    corps: "Les feux d'artifice affolent beaucoup d'animaux. Garde-le à l'intérieur, volets fermés, avec un coin tranquille et un peu de musique ; vérifie qu'il est identifié (puce) en cas de fugue.",
    especes: {'chien', 'chat', 'cheval', 'oiseau', 'lapin', 'rongeur'},
    debutMois: 12, debutJour: 30, finMois: 1, finJour: 1,
    notifMois: 12, notifJour: 30, notifHeure: 17, notifMinute: 0,
  ),
];

final _hasard = Random();

/// Un conseil de saison pour l'encart « Le savais-tu ? », ou null s'il n'y
/// en a aucun en ce moment pour ces espèces.
String? conseilDeSaison({required Set<String> especes, required DateTime maintenant}) {
  final actifs =
      alertesSaison.where((a) => a.actif(maintenant) && a.concerne(especes)).toList();
  if (actifs.isEmpty) return null;
  final a = actifs[_hasard.nextInt(actifs.length)];
  final espece = a.especes.firstWhere(especes.contains);
  return '${a.titre} — ${a.corpsPour(espece)}';
}
