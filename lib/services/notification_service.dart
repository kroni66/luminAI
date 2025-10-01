import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
          appName: 'Lumin',
          appUserModelId: 'com.kroni66.lumin',
          guid: '{4b964ed0-9bd0-11f0-844f-0f3f099eb649}',
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _notificationsPlugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showUpdateAvailableNotification(String version) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'updates',
          'Updates',
          channelDescription: 'App update notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
      windows: windowsDetails,
    );

    await _notificationsPlugin.show(
      1,
      'Update Available',
      'Version $version is now available for Lumin',
      details,
    );
  }

  static Future<void> showUpdateDownloadedNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'updates',
          'Updates',
          channelDescription: 'App update notifications',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
      windows: windowsDetails,
    );

    await _notificationsPlugin.show(
      2,
      'Update Downloaded',
      'Restart Lumin to apply the update',
      details,
    );
  }
}
