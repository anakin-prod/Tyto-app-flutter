import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un son proposé pour les rappels. `fichier` est le nom du fichier sans
/// extension (le même dans assets/sounds, dans les ressources Android et
/// dans le dossier de sons de l'iPhone) ; il est vide pour « Son du
/// téléphone » et « Silencieux ».
class SonRappel {
  final String id;
  final String libelle;
  final String description;
  final String? fichier;
  const SonRappel(this.id, this.libelle, this.description, [this.fichier]);
}

const List<SonRappel> sonsRappel = [
  SonRappel('systeme', 'Son du téléphone', 'Le son de notification habituel de ton téléphone'),
  SonRappel('houhou', 'Chouette', "Le hululement d'une vraie chouette", 'tyto_houhou'),
  SonRappel('hibou', 'Hibou', 'Le même hululement, plus grave, comme un hibou', 'tyto_hibou'),
  SonRappel('carillon', 'Carillon', 'Deux notes de cloche, douces et claires', 'tyto_carillon'),
  SonRappel('goutte', 'Goutte', "Une goutte d'eau, discrète", 'tyto_goutte'),
  SonRappel('silence', 'Silencieux', "Pas de son : la notification s'affiche seulement"),
];

/// Les petits sons de l'appli (un seul « hou » court), joués à l'envoi d'un
/// message. Même principe que ci-dessus : le même nom de fichier partout.
const List<String> sonsInterface = ['tyto_hou_chouette', 'tyto_hou_hibou'];

/// Les groupes de rappels qu'on peut activer ou couper un par un.
const Map<String, String> groupesRappels = {
  'vaccin': 'Vaccins',
  'parasites': 'Vermifuges et antiparasitaires',
  'veto': 'Visites chez le véto',
  'autre': 'Autres rappels',
};

/// Les réglages des rappels et des sons, mémorisés sur l'appareil. Chargés
/// une fois au démarrage : ensuite, on les lit simplement ici.
class Reglages {
  static const _cActifs = 'rappels_actifs';
  static const _cHeure = 'rappels_heure';
  static const _cMinute = 'rappels_minute';
  static const _cJours = 'rappels_jours';
  static const _cGroupes = 'rappels_groupes';
  static const _cSon = 'rappels_son';
  static const _cVibrations = 'vibrations_actives';
  static const _cSonMessage = 'son_a_l_envoi';

  /// Les rappels du carnet (vaccins, vermifuges, visites…) sont-ils activés ?
  static bool actifs = true;

  /// L'heure du rappel (0 à 23) et les minutes (0 à 59). 9 h 00, comme avant.
  static int heure = 9;
  static int minute = 0;

  /// Combien de jours avant l'échéance on prévient : 7, 1 et/ou 0 (le jour même).
  static Set<int> jours = {0};

  /// Les groupes de rappels activés (voir `groupesRappels`).
  static Set<String> groupes = groupesRappels.keys.toSet();

  /// Le son des rappels et des soins (voir `sonsRappel`).
  static String son = 'systeme';

  /// Vibrations : celles des notifications (Android) et les petits retours
  /// tactiles dans l'appli.
  static bool vibrations = true;

  /// Le « hou » de la chouette à chaque message envoyé : activé par défaut.
  static bool sonMessage = true;

  /// Le petit son joué à l'envoi : le hibou si c'est lui qu'on a choisi pour
  /// les rappels, la chouette sinon.
  static String get fichierSonMessage => son == 'hibou' ? 'tyto_hou_hibou' : 'tyto_hou_chouette';

  /// L'heure du rappel écrite à la française : « 9 h » ou « 9 h 30 ».
  static String get heureTexte => minute == 0 ? '$heure h' : '$heure h ${minute.toString().padLeft(2, '0')}';

  static SonRappel get sonChoisi =>
      sonsRappel.firstWhere((s) => s.id == son, orElse: () => sonsRappel.first);

  /// Le groupe auquel appartient un type d'événement du carnet.
  static String groupeDe(String type) {
    switch (type) {
      case 'vaccin':
        return 'vaccin';
      case 'vermifuge':
      case 'antiparasitaire':
        return 'parasites';
      case 'veto':
      case 'visite':
        return 'veto';
      default:
        return 'autre';
    }
  }

  static Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      actifs = prefs.getBool(_cActifs) ?? true;
      heure = (prefs.getInt(_cHeure) ?? 9).clamp(0, 23);
      minute = (prefs.getInt(_cMinute) ?? 0).clamp(0, 59);
      final j = prefs.getStringList(_cJours);
      if (j != null) {
        final lus = j.map(int.tryParse).whereType<int>().where((x) => x == 0 || x == 1 || x == 7).toSet();
        if (lus.isNotEmpty) jours = lus;
      }
      final g = prefs.getStringList(_cGroupes);
      if (g != null) groupes = g.where(groupesRappels.containsKey).toSet();
      final s = prefs.getString(_cSon);
      if (s != null && sonsRappel.any((x) => x.id == s)) son = s;
      vibrations = prefs.getBool(_cVibrations) ?? true;
      sonMessage = prefs.getBool(_cSonMessage) ?? true;
    } catch (_) {
      // On garde les valeurs par défaut.
    }
  }

  static Future<void> enregistrer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cActifs, actifs);
      await prefs.setInt(_cHeure, heure);
      await prefs.setInt(_cMinute, minute);
      await prefs.setStringList(_cJours, (jours.toList()..sort()).map((x) => '$x').toList());
      await prefs.setStringList(_cGroupes, groupes.toList());
      await prefs.setString(_cSon, son);
      await prefs.setBool(_cVibrations, vibrations);
      await prefs.setBool(_cSonMessage, sonMessage);
    } catch (_) {}
  }

  /// Un petit retour tactile léger (envoi d'un message, case cochée…), sauf
  /// si les vibrations sont coupées dans Paramètres.
  static void toucher() {
    if (vibrations) HapticFeedback.lightImpact();
  }
}
