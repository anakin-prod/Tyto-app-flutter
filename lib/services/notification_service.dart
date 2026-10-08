import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../data/seasonal.dart';
import '../models/health_event.dart';

/// Une notification de soin à programmer : la prise d'un traitement à
/// l'heure dite, ou la relance qui suit si elle n'a pas été cochée.
class RappelSoin {
  final DateTime moment;
  final String titre;
  final String texte;
  final bool relance;
  const RappelSoin({
    required this.moment,
    required this.titre,
    required this.texte,
    this.relance = false,
  });
}

/// Rappelle un vaccin ou un vermifuge directement sur le téléphone, le
/// jour même — même app fermée. Prévient aussi, au bon moment de l'année,
/// des risques de saison : épillets, chaleur, froid, feux d'artifice…
/// C'est ce qu'un site ne peut pas faire correctement, et l'un des vrais
/// arguments d'avoir l'app plutôt que seulement le site.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pret = false;

  /// Les rappels du carnet prennent les numéros 0, 1, 2… ; les alertes de
  /// saison commencent à 5000 pour ne jamais s'y mélanger.
  static const _idSaison = 5000;

  /// Les prises de traitements (« Soins en cours ») : de 10000 à 10999.
  static const _idSoins = 10000;
  static const _cleAnimaux = 'saison_animaux';

  static Future<void> initialiser() async {
    if (_pret) return;
    tzdata.initializeTimeZones();
    // Sans fuseau précisé, « 9 h » voulait dire 9 h UTC, soit 10 h ou 11 h en
    // France. Tyto s'adresse à un public francophone : on se cale sur Paris.
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    } catch (e) {
      // Si le fuseau est introuvable, on garde le comportement précédent.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Sur iPhone, on ne demande rien au tout premier lancement : la
    // permission est demandée plus tard, au bon moment (demanderPermission).
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);
    _pret = true;
  }

  /// Demande la permission — obligatoire à partir d'Android 13, et toujours
  /// sur iPhone. Ne fait rien là où c'est déjà accordé, ni sur l'autre
  /// plateforme (chaque ligne ne s'applique qu'à la sienne).
  static Future<void> demanderPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Annule tous les rappels programmés — utilisé quand on quitte un compte
  /// (déconnexion ou suppression) : sans ça, le téléphone continuerait à
  /// rappeler des vaccins pour des animaux qui ne sont plus là.
  static Future<void> annulerTout() async {
    if (!_pret) return;
    await _plugin.cancelAll();
    // On oublie aussi la liste des animaux gardée pour les alertes de saison.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleAnimaux);
  }

  /// Reprogramme tous les rappels d'un coup : on efface les anciens puis
  /// on recrée depuis les données actuelles — plus simple et plus sûr
  /// que d'essayer de ne mettre à jour que ce qui a changé.
  static Future<void> reprogrammer({
    required List<HealthEvent> rappels,
    required Map<String, String> nomsAnimaux,
    List<Map<String, String>> animaux = const [],
  }) async {
    if (!_pret) return;
    await _plugin.cancelAll();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tyto_rappels',
        'Rappels de santé',
        channelDescription: 'Vaccins, vermifuges et visites à ne pas manquer',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    var id = 0;
    final maintenant = tz.TZDateTime.now(tz.local);

    for (final ev in rappels) {
      if (ev.nextDue == null) continue;
      // On prévient à 9h le jour du rappel.
      final quand = tz.TZDateTime(tz.local, ev.nextDue!.year, ev.nextDue!.month, ev.nextDue!.day, 9);
      if (quand.isBefore(maintenant)) continue; // déjà passé, inutile

      final nom = nomsAnimaux[ev.petId];
      final titre = nom != null ? 'Tyto — $nom' : 'Tyto';
      final texte = nom != null
          ? "${ev.libelle} est prévu aujourd'hui pour $nom."
          : "${ev.libelle} est prévu aujourd'hui.";

      try {
        await _plugin.zonedSchedule(
          id++,
          titre,
          texte,
          quand,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        // Une programmation ratée ne doit jamais bloquer les autres.
      }
    }

    // Les alertes de saison, selon les espèces des animaux. On garde leur
    // liste en mémoire pour pouvoir les reprogrammer sans recharger les
    // données (quand on active ou désactive les alertes depuis le menu).
    await _memoriserAnimaux(animaux);
    await _programmerSaison(animaux);
  }

  // ---------- Soins en cours ----------

  /// Reprogramme uniquement les notifications de soins (prises de
  /// traitements et relances), sans toucher aux rappels du carnet ni aux
  /// alertes de saison. Appelé à l'ouverture de l'app et après chaque
  /// action dans « Soins en cours ».
  static Future<void> reprogrammerSoins(List<RappelSoin> rappels) async {
    if (!_pret) return;
    final attente = await _plugin.pendingNotificationRequests();
    for (final n in attente) {
      if (n.id >= _idSoins && n.id < _idSoins + 1000) await _plugin.cancel(n.id);
    }

    final maintenant = tz.TZDateTime.now(tz.local);
    var id = _idSoins;
    for (final r in rappels) {
      final quand = tz.TZDateTime(
        tz.local,
        r.moment.year,
        r.moment.month,
        r.moment.day,
        r.moment.hour,
        r.moment.minute,
      );
      if (!quand.isAfter(maintenant)) continue;

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'tyto_soins',
          'Soins et traitements',
          channelDescription: 'Les prises de médicaments et de soins à ne pas oublier',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(r.texte),
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id++,
          r.titre,
          r.texte,
          quand,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        // Une programmation ratée ne doit jamais bloquer les autres.
      }
    }
  }

  // ---------- Alertes de saison ----------

  static Future<void> _memoriserAnimaux(List<Map<String, String>> animaux) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleAnimaux, jsonEncode(animaux));
  }

  static Future<List<Map<String, String>>> _lireAnimaux() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cleAnimaux);
    if (brut == null) return [];
    try {
      return (jsonDecode(brut) as List)
          .map((e) => <String, String>{
                'nom': (e['nom'] ?? '').toString(),
                'espece': (e['espece'] ?? '').toString(),
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// « Max », « Max et Luna », « Max, Luna et 2 autres ».
  static String _noms(List<String> noms) {
    if (noms.length <= 2) return noms.join(' et ');
    final reste = noms.length - 2;
    return '${noms.take(2).join(', ')} et $reste autre${reste > 1 ? 's' : ''}';
  }

  /// La prochaine fois que la date de l'alerte arrive : cette année si elle
  /// n'est pas encore passée, sinon l'an prochain. Jamais dans le passé.
  static tz.TZDateTime _prochaine(AlerteSaison a, tz.TZDateTime maintenant, int decalageMinutes) {
    var quand = tz.TZDateTime(tz.local, maintenant.year, a.notifMois, a.notifJour, a.notifHeure, a.notifMinute)
        .add(Duration(minutes: decalageMinutes));
    if (!quand.isAfter(maintenant)) {
      quand = tz.TZDateTime(tz.local, maintenant.year + 1, a.notifMois, a.notifJour, a.notifHeure, a.notifMinute)
          .add(Duration(minutes: decalageMinutes));
    }
    return quand;
  }

  static Future<void> _programmerSaison(List<Map<String, String>> animaux) async {
    if (!await AlertesSaison.actives()) return;
    final maintenant = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < alertesSaison.length; i++) {
      final a = alertesSaison[i];
      final concernes = animaux.where((p) => a.especes.contains(p['espece'])).toList();
      if (concernes.isEmpty) continue;

      // Un texte général : une seule notification pour tous les animaux
      // concernés. Des textes par espèce : une notification par espèce,
      // décalées de 5 minutes pour ne pas arriver toutes d'un coup.
      final groupes = <String, List<Map<String, String>>>{};
      if (a.corpsParEspece.isEmpty) {
        groupes['*'] = concernes;
      } else {
        for (final p in concernes) {
          (groupes[p['espece']!] ??= []).add(p);
        }
      }

      var rang = 0;
      for (final entree in groupes.entries) {
        final espece = entree.key == '*' ? concernes.first['espece']! : entree.key;
        final noms = entree.value.map((p) => p['nom']!).where((n) => n.isNotEmpty).toList();
        final corps = a.corpsPour(espece);
        final texte = noms.isEmpty ? corps : 'Pour ${_noms(noms)} : $corps';

        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            'tyto_saison',
            'Conseils de saison',
            channelDescription: "Conseils de prévention selon la saison : épillets, chaleur, froid, feux d'artifice…",
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            // Le texte est long : on l'affiche en entier quand on déplie.
            styleInformation: BigTextStyleInformation(texte),
          ),
        );

        try {
          await _plugin.zonedSchedule(
            _idSaison + i * 20 + rang,
            a.titreNotif,
            texte,
            _prochaine(a, maintenant, rang * 5),
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          // Une programmation ratée ne doit jamais bloquer les autres.
        }
        rang++;
      }
    }
  }

  /// Reprogramme (ou efface) uniquement les alertes de saison, à partir de
  /// la liste d'animaux gardée en mémoire — appelé quand on active ou
  /// désactive les alertes depuis le menu.
  static Future<void> reprogrammerSaisonDepuisMemoire() async {
    if (!_pret) return;
    final attente = await _plugin.pendingNotificationRequests();
    for (final n in attente) {
      if (n.id >= _idSaison && n.id < _idSoins) await _plugin.cancel(n.id);
    }
    await _programmerSaison(await _lireAnimaux());
  }
}

/// Le réglage « Conseils de saison » du menu : activé par défaut.
class AlertesSaison {
  static const _cle = 'alertes_saison_actives';

  static Future<bool> actives() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cle) ?? true;
  }

  static Future<void> definir(bool actives) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cle, actives);
  }
}
