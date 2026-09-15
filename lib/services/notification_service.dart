import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/health_event.dart';

/// Rappelle un vaccin ou un vermifuge directement sur le téléphone, le
/// jour même — même app fermée. C'est ce qu'un site ne peut pas faire
/// correctement, et l'un des vrais arguments d'avoir l'app plutôt que
/// seulement le site.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pret = false;

  static Future<void> initialiser() async {
    if (_pret) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings);
    _pret = true;
  }

  /// Demande la permission — obligatoire à partir d'Android 13. Ne fait
  /// rien sur les versions plus anciennes, où c'est déjà accordé.
  static Future<void> demanderPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static String _libelle(String type) {
    switch (type) {
      case 'vaccin':
        return 'un rappel de vaccin';
      case 'vermifuge':
        return 'un vermifuge';
      case 'visite':
        return 'une visite vétérinaire';
      case 'traitement':
        return 'un traitement';
      default:
        return 'un rappel';
    }
  }

  /// Reprogramme tous les rappels d'un coup : on efface les anciens puis
  /// on recrée depuis les données actuelles — plus simple et plus sûr
  /// que d'essayer de ne mettre à jour que ce qui a changé.
  static Future<void> reprogrammer({
    required List<HealthEvent> rappels,
    required Map<String, String> nomsAnimaux,
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
      var quand = tz.TZDateTime(
        tz.local, ev.nextDue!.year, ev.nextDue!.month, ev.nextDue!.day, 9);
      if (quand.isBefore(maintenant)) continue; // déjà passé, inutile

      final nom = nomsAnimaux[ev.petId];
      final titre = nom != null ? 'Tyto — $nom' : 'Tyto';
      final texte = nom != null
          ? "N'oublie pas ${_libelle(ev.type)} pour $nom aujourd'hui."
          : "N'oublie pas ${_libelle(ev.type)} aujourd'hui.";

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
