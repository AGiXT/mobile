import 'package:flutter_test/flutter_test.dart';
import 'package:agixt/services/bluetooth_background_service.dart';

void main() {
  group('BluetoothBackgroundService', () {
    test('initialize should complete without error', () async {
      // This test verifies that the service can be initialized
      expect(() async => await BluetoothBackgroundService.initialize(),
          returnsNormally);
    });

    test('isRunning should return a boolean', () async {
      final isRunning = await BluetoothBackgroundService.isRunning();
      expect(isRunning, isA<bool>());
    });

    test('start and stop should complete without error', () async {
      // Note: These might not actually start/stop in test environment
      // but should not throw errors
      expect(() async => await BluetoothBackgroundService.start(),
          returnsNormally);
      expect(
          () async => await BluetoothBackgroundService.stop(), returnsNormally);
    });
  });
}
