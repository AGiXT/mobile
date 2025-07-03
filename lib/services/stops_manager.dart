import 'dart:async';
import 'dart:math';

import 'package:agixt/models/agixt/stop.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

class StopsManager {
  static final StopsManager _singleton = StopsManager._internal();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory StopsManager() {
    return _singleton;
  }

  StopsManager._internal();

  List<Timer> timers = [];

  void reload() async {
    cancelTimers();
    await loadStops();
  }

  Future<bool> _isStopStillInDatabase(AGiXTStopItem stop) async {
    final box = Hive.lazyBox<AGiXTStopItem>('agixtStopBox');
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null && item.uuid == stop.uuid) {
        return true;
      }
    }
    return false;
  }

  Future<void> loadStops() async {
    // Load stops from Hive
    final box = Hive.lazyBox<AGiXTStopItem>('agixtStopBox');
    final stops = <AGiXTStopItem>[];
    for (int i = 0; i < box.length; i++) {
      final item = await box.getAt(i);
      if (item != null) {
        stops.add(item);
      }
    }

    // set a timer for each stop
    for (final stop in stops) {
      final timer = Timer(stop.time.difference(DateTime.now()), () {
        _triggerTimer(stop);
      });
      timers.add(timer);
    }
  }

  void _triggerTimer(AGiXTStopItem item) async {
    if (!await _isStopStillInDatabase(item)) {
      return;
    }
    final bl = BluetoothManager();
    if (bl.isConnected) {
      bl.sendText(item.title, delay: const Duration(seconds: 10));
    }
    // retrigger myself in 10 seconds
    final timer = Timer(const Duration(seconds: 20), () {
      _triggerTimer(item);
    });
    timers.add(timer);

    // show notification
    flutterLocalNotificationsPlugin.show(
      Random().nextInt(1000),
      'AGiXT',
      'Time to: ${item.title}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'agixt',
          'AGiXT',
          icon: 'branding',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('delete_${item.uuid}', 'Delete',
                cancelNotification: true, showsUserInterface: true),
          ],
        ),
      ),
    );
  }

  void cancelTimers() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }

  /// Dispose of all resources
  void dispose() {
    cancelTimers();
  }
}
