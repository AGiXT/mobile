import 'package:agixt/models/g1/commands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../../services/bluetooth_reciever.dart';
import '../../utils/constants.dart';
import '../../services/ai_service.dart';

enum GlassSide { left, right }

// Define type for side button press callback
typedef SideButtonCallback = void Function();

class Glass {
  final String name;
  final GlassSide side;

  final BluetoothDevice device;

  BluetoothCharacteristic? uartTx;
  BluetoothCharacteristic? uartRx;

  StreamSubscription<List<int>>? notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionStateSubscription;
  Timer? heartbeatTimer;
  int heartbeatSeq = 0;
  int _connectRetries = 0;
  static const int maxConnectRetries = 3;
  bool _externalHeartbeatManaged = false;

  // Callback function for when side button is pressed
  SideButtonCallback? onSideButtonPress;

  get isConnected => device.isConnected;

  BluetoothReciever reciever = BluetoothReciever.singleton;

  Glass({
    required this.name,
    required this.device,
    required this.side,
  }) {
    // Bind side button press to AGiXT chat completion
    onSideButtonPress = () async {
      await AIService.singleton.handleSideButtonPress();
    };
  }

  Future<void> connect() async {
    try {
      // Cancel any existing subscriptions first
      await disconnect();

      // Set up connection state monitoring first
      connectionStateSubscription =
          device.connectionState.listen((BluetoothConnectionState state) {
        debugPrint('[$side Glass] Connection state: $state');
        if (state == BluetoothConnectionState.disconnected &&
            _connectRetries < maxConnectRetries) {
          _connectRetries++;
          debugPrint(
              '[$side Glass] Auto-reconnect attempt $_connectRetries/$maxConnectRetries');
          _connectWithRetry();
        }
      });

      // Initial connection attempt
      await _connectWithRetry();
      _connectRetries = 0; // Reset counter after successful connection
    } catch (e) {
      debugPrint('[$side Glass] Connection error: $e');
      await disconnect();
      rethrow;
    }
  }

  Future<void> _connectWithRetry() async {
    try {
      if (!device.isConnected) {
        // Retry the connection up to maxConnectRetries times
        bool connected = false;
        while (!connected && _connectRetries < maxConnectRetries) {
          try {
            debugPrint(
                '[$side Glass] Trying to connect (attempt ${_connectRetries + 1})');
            await device.connect(timeout: const Duration(seconds: 15));
            connected = true;
          } catch (e) {
            _connectRetries++;
            debugPrint(
                '[$side Glass] Connection attempt $_connectRetries failed: $e');
            if (_connectRetries < maxConnectRetries) {
              await Future.delayed(const Duration(seconds: 1));
            } else {
              throw Exception(
                  'Failed to connect after $maxConnectRetries attempts');
            }
          }
        }
      }

      // Once connected, proceed with service discovery and setup
      debugPrint('[$side Glass] Connected, discovering services...');
      await discoverServices();
      debugPrint('[$side Glass] Services discovered, setting up MTU...');
      await device.requestMtu(251);
      debugPrint('[$side Glass] Setting connection priority...');
      await device.requestConnectionPriority(
          connectionPriorityRequest: ConnectionPriority.high);
      startHeartbeat();
      debugPrint(
          '[$side Glass] Setup complete - connection established successfully');
    } catch (e) {
      debugPrint('[$side Glass] Connection process failed: $e');
      rethrow; // Let the caller handle this error
    }
  }

  Future<void> discoverServices() async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString().toUpperCase() ==
          BluetoothConstants.UART_SERVICE_UUID) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString().toUpperCase() ==
              BluetoothConstants.UART_TX_CHAR_UUID) {
            if (c.properties.write) {
              uartTx = c;
              debugPrint('[$side Glass] UART TX Characteristic is writable.');
            } else {
              debugPrint(
                  '[$side Glass] UART TX Characteristic is not writable.');
            }
          } else if (c.uuid.toString().toUpperCase() ==
              BluetoothConstants.UART_RX_CHAR_UUID) {
            uartRx = c;
          }
        }
      }
    }
    if (uartRx != null) {
      await uartRx!.setNotifyValue(true);
      notificationSubscription = uartRx!.value.listen((data) {
        handleNotification(data);
      });
      debugPrint('[$side Glass] UART RX set to notify.');
    } else {
      debugPrint('[$side Glass] UART RX Characteristic not found.');
    }

    if (uartTx != null) {
      debugPrint('[$side Glass] UART TX Characteristic found.');
    } else {
      debugPrint('[$side Glass] UART TX Characteristic not found.');
    }
  }

  void handleNotification(List<int> data) async {
    //String hexData =
    //    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    //debugPrint('[$side Glass] Received data: $hexData');

    // Check for side button press event
    if (data.length >= 2 && data[0] == Commands.BUTTON_PRESS) {
      debugPrint('[$side Glass] Side button pressed');
      // Call the callback if it's defined
      if (onSideButtonPress != null) {
        onSideButtonPress!();
      }
    }

    // Call the receive handler function
    await reciever.receiveHandler(side, data);
  }

  Future<void> sendData(List<int> data) async {
    if (uartTx != null) {
      try {
        if (device.isConnected) {
          await uartTx!.write(data, withoutResponse: false);
          //debugPrint(
          //    'Sent data to $side glass: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        } else {
          debugPrint('Device not connected, cannot send data to $side glass.');
        }
      } catch (e) {
        debugPrint('Error sending data to $side glass: $e');
      }
    } else {
      debugPrint('UART TX not available for $side glass.');
    }
  }

  List<int> _constructHeartbeat(int seq) {
    int length = 6;
    return [
      Commands.HEARTBEAT,
      length & 0xFF,
      (length >> 8) & 0xFF,
      seq % 0xFF,
      0x04,
      seq % 0xFF,
    ];
  }

  /// Send a single heartbeat message to keep the connection alive
  Future<void> sendHeartbeat() async {
    if (device.isConnected) {
      List<int> heartbeatData = _constructHeartbeat(heartbeatSeq++);
      await sendData(heartbeatData);
      debugPrint('[$side Glass] Heartbeat sent (seq: ${heartbeatSeq - 1})');
    }
  }

  /// Set whether heartbeat is managed externally (by background service)
  void setExternalHeartbeatManaged(bool managed) {
    _externalHeartbeatManaged = managed;
    if (managed) {
      heartbeatTimer?.cancel();
      heartbeatTimer = null;
    } else if (device.isConnected) {
      startHeartbeat();
    }
  }

  void startHeartbeat() {
    if (_externalHeartbeatManaged) {
      return; // Don't start internal heartbeat if managed externally
    }

    // Cancel existing timer first to prevent duplicates
    heartbeatTimer?.cancel();
    heartbeatTimer = null;

    const heartbeatInterval = Duration(seconds: 5);
    heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) async {
      if (device.isConnected) {
        try {
          List<int> heartbeatData = _constructHeartbeat(heartbeatSeq++);
          await sendData(heartbeatData);
        } catch (e) {
          debugPrint('[$side Glass] Heartbeat failed: $e');
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> disconnect() async {
    // Cancel all subscriptions and timers first
    await notificationSubscription?.cancel();
    notificationSubscription = null;

    await connectionStateSubscription?.cancel();
    connectionStateSubscription = null;

    heartbeatTimer?.cancel();
    heartbeatTimer = null;

    // Reset state
    _connectRetries = 0;
    uartTx = null;
    uartRx = null;

    // Then disconnect the device
    try {
      if (device.isConnected) {
        await device.disconnect();
      }
    } catch (e) {
      debugPrint('[$side Glass] Error during disconnect: $e');
    }
    debugPrint('[$side Glass] Disconnected and cleaned up');
  }
}
