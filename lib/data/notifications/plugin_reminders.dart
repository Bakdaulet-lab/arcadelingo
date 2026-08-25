/// Адаптер порта [Reminders] на `flutter_local_notifications`.
///
/// Тонкий по устройству и по замыслу: «когда напоминать» решает
/// `domain/reminders/reminder_policy.dart`, «какими словами» —
/// `ui/reminder_labels.dart`, а здесь только перевод момента в то, что
/// понимает платформа. Ни одного решения о ритуале в этом файле нет.
///
/// ## Почему расписание неточное
///
/// [AndroidScheduleMode.inexactAllowWhileIdle], а не `exactAllowWhileIdle`.
/// Точные будильники на Android 14 требуют `SCHEDULE_EXACT_ALARM` — отдельного
/// разрешения, которое система выдаёт неохотно и которое положено просить
/// только тем, кто без него не работает: часам и календарю. Напоминание
/// «около восьми вечера» к таким не относится, и сдвиг на несколько минут ему
/// безразличен.
///
/// ## Почему зона берётся у устройства
///
/// `zonedSchedule` принимает `TZDateTime`, то есть момент в **именованной**
/// зоне. Смещения мало: в зонах с переводом стрелок напоминание, поставленное
/// на 20:00, сработало бы в 19:00 после перевода. Имя зоны отдаёт
/// `flutter_timezone`, базу — `timezone`.
///
/// ## Чего здесь нет
///
/// Тестов на настоящий плагин: он ходит в платформенные каналы, которых в
/// `flutter test` нет. Проверяется адаптер тем же способом, что вся
/// платформенная часть проекта, — руками на телефоне в `--release`, и это
/// записано в DoD этапа. Всё, что можно проверить без телефона, вынесено в
/// политику и в слова, и там оно покрыто целиком.
library;

import 'package:arcadelingo/domain/ports/reminders.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Единственный идентификатор уведомления.
///
/// Единственный намеренно: напоминание перепланируется на каждом открытии
/// приложения и после каждой партии, и очередь накопленных уведомлений
/// быстро разошлась бы с тем, что человек видит на экране. Один и тот же id
/// означает «заменить», а не «добавить».
const int reminderNotificationId = 1;

/// Канал уведомлений Android. Имя видно человеку в системных настройках, и
/// менять его — значит завести второй канал у тех, кто уже обновился.
const String reminderChannelId = 'arcadelingo.daily';

class PluginReminders implements Reminders {
  PluginReminders(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Готовый адаптер: база зон загружена, местная зона выставлена, плагин
  /// проинициализирован.
  ///
  /// Всё это делается один раз при старте приложения — база IANA весит
  /// сотни килобайт, и грузить её на каждое планирование незачем.
  static Future<PluginReminders> start() async {
    tz_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        // Иконка приложения: своей у уведомления нет, и заводить её ради
        // одного канала — лишний ассет в бандле.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Разрешение спрашивается не здесь, а в момент включения
          // напоминаний: приложение, спрашивающее его на первом запуске, —
          // приложение, которому отказывают.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return PluginReminders(plugin);
  }

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    // Сначала снять прежнее: id один, но `zonedSchedule` с тем же id заменяет
    // не на всех платформах одинаково, а лишнее уведомление в шторке — это
    // ровно та мелочь, из-за которой напоминания выключают.
    await _plugin.cancelAll();
    await _plugin.zonedSchedule(
      reminderNotificationId,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          reminderChannelId,
          'Ежедневное напоминание',
          channelDescription: 'Напоминание сыграть партию и не потерять серию',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  /// Спрашивает разрешение показывать уведомления.
  ///
  /// Зовётся ровно в момент, когда человек включает напоминания, и нигде
  /// больше. Возвращает то, что ответила система: `false` значит «включить
  /// не вышло», и экран настроек обязан это показать, а не притвориться, что
  /// всё в порядке.
  ///
  /// Не входит в порт [Reminders]: разрешение — понятие платформы, а не
  /// домена. Хост зовёт его напрямую, потому что и так знает про `data/`.
  Future<bool> requestPermission() async {
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    // Платформа без спроса — считаем, что можно.
    return true;
  }
}
