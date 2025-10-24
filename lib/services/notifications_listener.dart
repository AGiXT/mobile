import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

typedef OnNotification = void Function(ServiceNotificationEvent);

class AndroidNotificationsListener {
  final OnNotification onData;

  AndroidNotificationsListener({required this.onData});

  Future<void> startListening({bool requestIfDenied = false}) async {
    final bool hasPermission =
        await NotificationListenerService.isPermissionGranted();

    if (!hasPermission) {
      if (!requestIfDenied) {
        return;
      }

      await NotificationListenerService.requestPermission();

      final bool grantedNow =
          await NotificationListenerService.isPermissionGranted();
      if (!grantedNow) {
        return;
      }
    }

    NotificationListenerService.notificationsStream.listen((event) {
      if (event.hasRemoved == null || event.hasRemoved == false) {
        onData(event);
      }
    });
  }

  Future<void> requestPermission() async {
    await NotificationListenerService.requestPermission();
  }
}
