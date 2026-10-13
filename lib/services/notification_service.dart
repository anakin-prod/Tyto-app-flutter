import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../data/seasonal.dart';
import '../models/health_event.dart';
import 'reglages_service.dart';

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

  /// La notification d'essai de « Sons et vibrations ».
  static const _idTest = 20000;

  /// Le dernier carnet connu : gardé en mémoire pour pouvoir reprogrammer les
  /// rappels quand on change un réglage, sans recharger les données.
  static List<HealthEvent> _derniersRappels = [];
  static Map<String, String> _derniersNoms = {};

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
    unawaited(_copierSonsIos());
  }

  /// Sur iPhone, un son de notification doit se trouver dans le dossier
  /// Library/Sounds de l'appli : on y copie nos sons au lancement (rien à
  /// faire dans Xcode). Sur Android, les sons sont dans les ressources.
  static Future<void> _copierSonsIos() async {
    if (!Platform.isIOS) return;
    try {
      final lib = await getLibraryDirectory();
      final dossier = Directory('${lib.path}/Sounds');
      if (!await dossier.exists()) await dossier.create(recursive: true);
      final noms = <String>[
        for (final son in sonsRappel)
          if (son.fichier != null) son.fichier!,
        ...sonsInterface,
      ];
      for (final nom in noms) {
        final data = await rootBundle.load('assets/sounds/$nom.wav');
        final cible = File('${dossier.path}/$nom.wav');
        if (await cible.exists() && await cible.length() == data.lengthInBytes) continue;
        await cible.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
    } catch (_) {
      // Sans les sons, l'iPhone joue simplement son son habituel.
    }
  }

  // ---------- Son et vibrations des notifications ----------

  /// L'identifiant du canal Android. Un canal ne peut plus changer de son
  /// une fois créé : il y a donc un canal par combinaison son + vibrations.
  /// Le réglage par défaut garde l'identifiant d'origine.
  static String _idCanal(bool soin, SonRappel son, bool vibrations) {
    final base = soin ? 'tyto_soins' : 'tyto_rappels';
    if (son.id == 'systeme' && vibrations) return base;
    return '${base}_${son.id}_${vibrations ? 'v' : 'n'}';
  }

  /// Les détails d'une notification de rappel ou de soin, selon le son et les
  /// vibrations choisis dans Paramètres.
  static NotificationDetails _details({required bool soin, String? texteLong}) {
    final son = Reglages.sonChoisi;
    final vib = Reglages.vibrations;
    final defaut = son.id == 'systeme' && vib;
    final nomBase = soin ? 'Soins et traitements' : 'Rappels de santé';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _idCanal(soin, son, vib),
        defaut ? nomBase : '$nomBase (${son.libelle.toLowerCase()}${vib ? '' : ', sans vibration'})',
        channelDescription: soin
            ? 'Les prises de médicaments et de soins à ne pas oublier'
            : 'Vaccins, vermifuges et visites à ne pas manquer',
        importance: soin ? Importance.max : Importance.high,
        priority: Priority.high,
        playSound: son.id != 'silence',
        sound: son.fichier != null ? RawResourceAndroidNotificationSound(son.fichier!) : null,
        enableVibration: vib,
        styleInformation: texteLong != null ? BigTextStyleInformation(texteLong) : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: son.id != 'silence',
        sound: son.fichier != null ? '${son.fichier}.wav' : null,
      ),
    );
  }

  /// Supprime les canaux Android qu'on n'utilise plus (anciens sons), pour ne
  /// pas encombrer les réglages du téléphone.
  static Future<void> _nettoyerCanaux() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    for (final soin in [false, true]) {
      final courant = _idCanal(soin, Reglages.sonChoisi, Reglages.vibrations);
      for (final son in sonsRappel) {
        for (final vib in [true, false]) {
          final id = _idCanal(soin, son, vib);
          if (id == courant) continue;
          try {
            await android.deleteNotificationChannel(id);
          } catch (_) {}
        }
      }
    }
    try {
      await android.deleteNotificationChannel(Reglages.vibrations ? 'tyto_saison_n' : 'tyto_saison');
    } catch (_) {}
  }

  /// Affiche tout de suite une notification d'essai avec le son et les
  /// vibrations choisis.
  static Future<void> tester() async {
    if (!_pret) return;
    await demanderPermission();
    await _plugin.show(
      _idTest,
      'Tyto',
      Reglages.son == 'silence'
          ? "Voici une notification sans son."
          : 'Voici le son de tes rappels.',
      _details(soin: false),
    );
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
    _derniersRappels = [];
    _derniersNoms = {};
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
    _derniersRappels = rappels;
    _derniersNoms = nomsAnimaux;
    await _plugin.cancelAll();
    await _programmerCarnet();

    // Les alertes de saison, selon les espèces des animaux. On garde leur
    // liste en mémoire pour pouvoir les reprogrammer sans recharger les
    // données (quand on active ou désactive les alertes depuis le menu).
    await _memoriserAnimaux(animaux);
    await _programmerSaison(animaux);
  }

  /// Programme les rappels du carnet selon les réglages : l'heure, les jours
  /// d'avance (7 jours avant, la veille, le jour même) et les types choisis.
  static Future<void> _programmerCarnet() async {
    if (!Reglages.actifs) return;
    final details = _details(soin: false);
    final maintenant = tz.TZDateTime.now(tz.local);
    // Du plus lointain au plus proche : 7 jours avant, la veille, le jour même.
    final jours = Reglages.jours.toList()..sort((a, b) => b.compareTo(a));
    var id = 0;

    for (final ev in _derniersRappels) {
      final echeance = ev.nextDue;
      if (echeance == null) continue;
      if (!Reglages.groupes.contains(Reglages.groupeDe(ev.type))) continue;

      final nom = _derniersNoms[ev.petId];
      final titre = nom != null ? 'Tyto — $nom' : 'Tyto';

      for (final j in jours) {
        if (id >= _idSaison) return; // on ne déborde jamais sur les alertes de saison
        final quand = tz.TZDateTime(tz.local, echeance.year, echeance.month, echeance.day - j, Reglages.heure, Reglages.minute);
        if (!quand.isAfter(maintenant)) continue; // déjà passé, inutile

        final quandTexte = j == 0 ? "aujourd'hui" : (j == 1 ? 'demain' : 'dans $j jours');
        final texte = nom != null
            ? '${ev.libelle} est prévu $quandTexte pour $nom.'
            : '${ev.libelle} est prévu $quandTexte.';

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
    }
  }

  /// Reprogramme les rappels du carnet (sans toucher aux soins ni aux alertes
  /// de saison) à partir du dernier carnet connu : appelé quand on change
  /// l'heure, les jours, les types ou le son.
  static Future<void> reprogrammerCarnetDepuisMemoire() async {
    if (!_pret) return;
    final attente = await _plugin.pendingNotificationRequests();
    for (final n in attente) {
      if (n.id < _idSaison) await _plugin.cancel(n.id);
    }
    await _programmerCarnet();
  }

  /// Applique un changement de réglage (son, vibrations, heure…) : nettoie les
  /// anciens canaux Android, puis reprogramme le carnet et les alertes de
  /// saison. Les soins sont reprogrammés à part (SoinsService).
  static Future<void> appliquerReglages() async {
    if (!_pret) return;
    await _nettoyerCanaux();
    await reprogrammerCarnetDepuisMemoire();
    await reprogrammerSaisonDepuisMemoire();
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

      final details = _details(soin: true, texteLong: r.texte);

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
            Reglages.vibrations ? 'tyto_saison' : 'tyto_saison_n',
            Reglages.vibrations ? 'Conseils de saison' : 'Conseils de saison (sans vibration)',
            channelDescription: "Conseils de prévention selon la saison : épillets, chaleur, froid, feux d'artifice…",
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            enableVibration: Reglages.vibrations,
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
