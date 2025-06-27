import 'dart:io';
import 'dart:typed_data';

import 'package:android_package_manager/android_package_manager.dart';
import 'package:agixt/models/agixt/agixt_dashboard.dart';
import 'package:agixt/models/g1/bmp.dart';
import 'package:agixt/models/g1/commands.dart';
import 'package:agixt/models/g1/crc.dart';
import 'package:agixt/models/g1/dashboard.dart';
import 'package:agixt/models/g1/setup.dart';
import 'package:agixt/services/dashboard_controller.dart';
import 'package:agixt/models/g1/note.dart';
import 'package:agixt/models/g1/notification.dart';
import 'package:agixt/models/g1/text.dart';
import 'package:agixt/services/notifications_listener.dart';
import 'package:agixt/services/stops_manager.dart';
import 'package:agixt/services/open_meteo_weather_service.dart';
import 'package:agixt/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Add this import for MethodChannel
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agixt/models/agixt/auth/auth.dart';
import 'dart:async';
import '../utils/constants.dart';
import '../models/g1/glass.dart';
import 'time_sync.dart';

/* Bluetooth Magnager is the heart of the application
  * It is responsible for scanning for the glasses and connecting to them
  * It also handles the connection state of the glasses
  * It allows for sending commands to the glasses
  */

typedef OnUpdate = void Function(String message);

class BluetoothManager {
  static final BluetoothManager singleton = BluetoothManager._internal();

  factory BluetoothManager() {
    return singleton;
  }

  BluetoothManager._internal() {
    notificationListener = AndroidNotificationsListener(
      onData: _handleAndroidNotification,
    );

    notificationListener!.startListening();

    // Set up method channel handler for displayTranscription
    const MethodChannel channel = MethodChannel('dev.agixt.agixt/bluetooth');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'displayTranscription') {
        final String transcription =
            call.arguments['display_transcription'] as String;
        await _displayTranscriptionOnGlasses(transcription);
        return true;
      }
      return null;
    });
  }

  AGiXTDashboard agixtDashboard = AGiXTDashboard();
  DashboardController dashboardController = DashboardController();
  StopsManager stopsManager = StopsManager();

  Timer? _syncTimer;

  Glass? leftGlass;
  Glass? rightGlass;

  AndroidNotificationsListener? notificationListener;

  get isConnected =>
      leftGlass?.isConnected == true && rightGlass?.isConnected == true;
  get isScanning => _isScanning;

  Timer? _scanTimer;
  bool _isScanning = false;
  int _retryCount = 0;
  static const int maxRetries = 3;

  Future<String?> _getLastG1UsedUid(GlassSide side) async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(side == GlassSide.left ? 'left' : 'right');
  }

  Future<String?> _getLastG1UsedName(GlassSide side) async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(side == GlassSide.left ? 'leftName' : 'rightName');
  }

  Future<void> _saveLastG1Used(GlassSide side, String name, String uid) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(side == GlassSide.left ? 'left' : 'right', uid);
    await pref.setString(
        side == GlassSide.left ? 'leftName' : 'rightName', name);
  }

  Future<void> initialize() async {
    FlutterBluePlus.setLogLevel(LogLevel.none);
    await agixtDashboard.initialize();
    stopsManager.reload();
    _syncTimer ??= Timer.periodic(const Duration(minutes: 1), (timer) {
      _sync();
    });
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    Map<Permission, PermissionStatus> statuses = await [
      //Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((status) => status.isDenied)) {
      throw Exception(
          'All permissions are required to use Bluetooth. Please enable them in the app settings.');
    }

    if (statuses.values.any((status) => status.isPermanentlyDenied)) {
      await openAppSettings();
      throw Exception(
          'All permissions are required to use Bluetooth. Please enable them in the app settings.');
    }
  }

  Future<void> attemptReconnectFromStorage() async {
    await initialize();

    final leftUid = await _getLastG1UsedUid(GlassSide.left);
    final rightUid = await _getLastG1UsedUid(GlassSide.right);

    if (leftUid != null) {
      leftGlass = Glass(
        name: await _getLastG1UsedName(GlassSide.left) ?? 'Left Glass',
        device: BluetoothDevice(remoteId: DeviceIdentifier(leftUid)),
        side: GlassSide.left,
      );
      await leftGlass!.connect();
      _setReconnect(leftGlass!);
    }

    if (rightUid != null) {
      rightGlass = Glass(
        name: await _getLastG1UsedName(GlassSide.right) ?? 'Right Glass',
        device: BluetoothDevice(remoteId: DeviceIdentifier(rightUid)),
        side: GlassSide.right,
      );
      await rightGlass!.connect();
      _setReconnect(rightGlass!);
    }

    // Sync settings if both glasses are connected
    if (leftGlass?.isConnected == true && rightGlass?.isConnected == true) {
      await _sync();
    }
  }

  Future<void> startScanAndConnect({
    required OnUpdate onUpdate,
  }) async {
    try {
      // this will fail in backround mode
      await _requestPermissions();
    } catch (e) {
      onUpdate(e.toString());
    }

    if (!await FlutterBluePlus.isAvailable) {
      onUpdate('Bluetooth is not available');
      throw Exception('Bluetooth is not available');
    }

    if (!await FlutterBluePlus.isOn) {
      onUpdate('Bluetooth is turned off');
      throw Exception('Bluetooth is turned off');
    }

    // Stop any existing scan
    await FlutterBluePlus.stopScan();

    // Make sure old connections are properly cleaned up
    await disconnectFromGlasses();

    // Reset state
    _isScanning = true;
    _retryCount = 0;
    leftGlass = null;
    rightGlass = null;

    await Future.delayed(
        const Duration(milliseconds: 500)); // Give BT stack time to clean up
    await _startScan(onUpdate);
  }

  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanningSubscription;

  Future<void> _startScan(OnUpdate onUpdate) async {
    await FlutterBluePlus.stopScan();
    debugPrint('Starting new scan attempt ${_retryCount + 1}/$maxRetries');

    // Cancel any existing subscriptions
    _scanSubscription?.cancel();
    _scanningSubscription?.cancel();

    // Set scan timeout
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 30), () {
      if (_isScanning) {
        _handleScanTimeout(onUpdate);
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      androidUsesFineLocation: true,
    );

    // Listen for scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult result in results) {
          String deviceName = result.device.name;
          String deviceId = result.device.id.id;
          debugPrint('Found device: $deviceName ($deviceId)');

          if (deviceName.isNotEmpty) {
            _handleDeviceFound(result, onUpdate);
          }
        }
      },
      onError: (error) {
        debugPrint('Scan results error: $error');
        onUpdate(error.toString());
      },
    );

    // Monitor scanning state
    _scanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
      debugPrint('Scanning state changed: $isScanning');
      if (!isScanning && _isScanning) {
        _handleScanComplete(onUpdate);
      }
    });
  }

  void _handleDeviceFound(ScanResult result, OnUpdate onUpdate) async {
    String deviceName = result.device.name;
    Glass? glass;
    if (deviceName.contains('_L_') && leftGlass == null) {
      debugPrint('Found left glass: $deviceName');
      glass = Glass(
        name: deviceName,
        device: result.device,
        side: GlassSide.left,
      );
      leftGlass = glass;
      onUpdate("Left glass found: ${glass.name}");
      await _saveLastG1Used(GlassSide.left, glass.name, glass.device.id.id);
    } else if (deviceName.contains('_R_') && rightGlass == null) {
      debugPrint('Found right glass: $deviceName');
      glass = Glass(
        name: deviceName,
        device: result.device,
        side: GlassSide.right,
      );
      rightGlass = glass;
      onUpdate("Right glass found: ${glass.name}");
      await _saveLastG1Used(GlassSide.right, glass.name, glass.device.id.id);
    }
    if (glass != null) {
      try {
        // Attempt connection up to 3 times
        int retries = 0;
        bool connected = false;
        while (!connected && retries < 3) {
          try {
            await glass.connect();
            connected = true;
          } catch (e) {
            retries++;
            debugPrint('Connection attempt $retries failed: $e');
            if (retries < 3) {
              await Future.delayed(Duration(seconds: 1));
            }
          }
        }

        if (!connected) {
          throw Exception('Failed to connect after 3 attempts');
        }

        _setReconnect(glass);

        // Verify both glasses are connected before stopping scan
        if (leftGlass != null && rightGlass != null) {
          if (leftGlass!.isConnected && rightGlass!.isConnected) {
            _isScanning = false;
            stopScanning();
            await Future.delayed(
                const Duration(seconds: 2)); // Increased delay for stability
            await _sync();
          }
        }
      } catch (e) {
        debugPrint('Error connecting to ${glass.side} glass: $e');
        if (glass.side == GlassSide.left) {
          leftGlass = null;
        } else {
          rightGlass = null;
        }
        // Don't rethrow - let the scan continue to retry
      }
    }
  }

  void _setReconnect(Glass glass) {
    // The Glass class now handles its own reconnection logic via its connectionStateSubscription
    debugPrint('[${glass.side} Glass] Reconnection handler configured');
  }

  void _handleScanTimeout(OnUpdate onUpdate) async {
    debugPrint('Scan timeout occurred');

    if (_retryCount < maxRetries && (leftGlass == null || rightGlass == null)) {
      _retryCount++;
      debugPrint('Retrying scan (Attempt $_retryCount/$maxRetries)');
      await _startScan(onUpdate);
    } else {
      _isScanning = false;
      stopScanning();
      onUpdate(leftGlass == null && rightGlass == null
          ? 'No glasses found'
          : 'Scan completed');
    }
  }

  void _handleScanComplete(OnUpdate onUpdate) {
    if (_isScanning && (leftGlass == null || rightGlass == null)) {
      _handleScanTimeout(onUpdate);
    }
  }

  Future<void> connectToDevice(BluetoothDevice device,
      {required String side}) async {
    try {
      debugPrint('Attempting to connect to $side glass: ${device.name}');
      await device.connect(timeout: const Duration(seconds: 15));
      debugPrint('Connected to $side glass: ${device.name}');

      List<BluetoothService> services = await device.discoverServices();
      debugPrint('Discovered ${services.length} services for $side glass');

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() ==
            BluetoothConstants.UART_SERVICE_UUID) {
          debugPrint('Found UART service for $side glass');
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() ==
                BluetoothConstants.UART_TX_CHAR_UUID) {
              debugPrint('Found TX characteristic for $side glass');
            } else if (characteristic.uuid.toString().toUpperCase() ==
                BluetoothConstants.UART_RX_CHAR_UUID) {
              debugPrint('Found RX characteristic for $side glass');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error connecting to $side glass: $e');
      await device.disconnect();
      rethrow;
    }
  }

  void stopScanning() {
    _scanTimer?.cancel();
    FlutterBluePlus.stopScan().then((_) {
      debugPrint('Stopped scanning');
      _isScanning = false;
    }).catchError((error) {
      debugPrint('Error stopping scan: $error');
    });
  }

  Future<void> sendCommandToGlasses(List<int> command) async {
    if (leftGlass != null) {
      await leftGlass!.sendData(command);
      await Future.delayed(Duration(milliseconds: 100));
    }
    if (rightGlass != null) {
      await rightGlass!.sendData(command);
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  Future<void> sendText(String text,
      {Duration delay = const Duration(seconds: 5)}) async {
    // Check if display is enabled in settings
    bool isDisplayEnabled = await _isGlassesDisplayEnabled();
    if (!isDisplayEnabled) {
      debugPrint(
          'Glasses display is disabled in settings. Text not displayed: $text');
      return;
    }

    final textMsg = TextMessage(text);
    List<List<int>> packets = textMsg.constructSendText();

    for (int i = 0; i < packets.length; i++) {
      await sendCommandToGlasses(packets[i]);
      if (i < 2) {
        // init packet
        await Future.delayed(Duration(milliseconds: 300));
      } else {
        await Future.delayed(delay);
      }
    }
  }

  Future<void> setDashboardLayout(List<int> option) async {
    // Check if display is enabled in settings
    bool isDisplayEnabled = await _isGlassesDisplayEnabled();
    if (!isDisplayEnabled) {
      debugPrint(
          'Glasses display is disabled in settings. Dashboard layout not changed.');
      return;
    }

    // concat the command with the option
    List<int> command = DashboardLayout.DASHBOARD_CHANGE_COMMAND.toList();
    command.addAll(option);

    await sendCommandToGlasses(command);
  }

  Future<void> sendNote(Note note) async {
    // Check if display is enabled in settings
    bool isDisplayEnabled = await _isGlassesDisplayEnabled();
    if (!isDisplayEnabled) {
      debugPrint('Glasses display is disabled in settings. Note not sent.');
      return;
    }

    List<int> noteBytes = note.buildAddCommand();
    await sendCommandToGlasses(noteBytes);
  }

  Future<void> sendBitmap(Uint8List bitmap) async {
    // Check if display is enabled in settings
    bool isDisplayEnabled = await _isGlassesDisplayEnabled();
    if (!isDisplayEnabled) {
      debugPrint('Glasses display is disabled in settings. Bitmap not sent.');
      return;
    }

    List<Uint8List> textBytes = Utils.divideUint8List(bitmap, 194);

    List<List<int>?> sentPackets = [];

    debugPrint("Transmitting BMP");
    for (int i = 0; i < textBytes.length; i++) {
      sentPackets.add(await _sendBmpPacket(dataChunk: textBytes[i], seq: i));
      await Future.delayed(Duration(milliseconds: 100));
    }

    debugPrint("Send end packet");
    await _sendPacketEndPacket();
    await Future.delayed(Duration(milliseconds: 500));

    List<int> concatenatedList = [];
    for (var packet in sentPackets) {
      if (packet != null) {
        concatenatedList.addAll(packet);
      }
    }
    Uint8List concatenatedPackets = Uint8List.fromList(concatenatedList);

    debugPrint("Sending CRC for mitmap");
    // Send CRC
    await _sendCRCPacket(packets: concatenatedPackets);
  }

  // Send a notification to the glasses
  Future<void> sendNotification(NCSNotification notification) async {
    // Check if display is enabled in settings
    bool isDisplayEnabled = await _isGlassesDisplayEnabled();
    if (!isDisplayEnabled) {
      debugPrint(
          'Glasses display is disabled in settings. Notification not sent: ${notification.title}');
      return;
    }

    G1Notification notif = G1Notification(ncsNotification: notification);
    List<Uint8List> notificationChunks = await notif.constructNotification();

    for (Uint8List chunk in notificationChunks) {
      await sendCommandToGlasses(chunk);
      await Future.delayed(
          Duration(milliseconds: 50)); // Small delay between chunks
    }
  }

  Future<String> _getAppDisplayName(String packageName) async {
    final pm = AndroidPackageManager();
    final name = await pm.getApplicationLabel(packageName: packageName);

    return name ?? packageName;
  }

  void _handleAndroidNotification(ServiceNotificationEvent notification) async {
    debugPrint(
        'Received notification: ${notification.toString()} from ${notification.packageName}');
    if (isConnected) {
      NCSNotification ncsNotification = NCSNotification(
        msgId: (notification.id ?? 1) + DateTime.now().millisecondsSinceEpoch,
        action: 0,
        type: 0,
        appIdentifier: notification.packageName ?? 'dev.agixt.agixt',
        title: notification.title ?? '',
        subtitle: '',
        message: notification.content ?? '',
        displayName: await _getAppDisplayName(notification.packageName ?? ''),
      );

      sendNotification(ncsNotification);
    }
  }

  Future<List<int>?> _sendBmpPacket({
    required Uint8List dataChunk,
    int seq = 0,
  }) async {
    BmpPacket result = BmpPacket(
      seq: seq,
      data: dataChunk,
    );

    List<int> bmpCommand = result.build();

    if (seq == 0) {
      // Insert the 4 required bytes
      bmpCommand.insertAll(2, [0x00, 0x1c, 0x00, 0x00]);
    }

    try {
      sendCommandToGlasses(bmpCommand);
      return bmpCommand;
    } catch (e) {
      return null;
    }
  }

  int _crc32(Uint8List data) {
    var crc = Crc32();
    crc.add(data);
    return crc.close();
  }

  Future<List<int>?> _sendCRCPacket({
    required Uint8List packets,
  }) async {
    Uint8List crcData = Uint8List.fromList([...packets]);

    int crc32Checksum = _crc32(crcData) & 0xFFFFFFFF;
    Uint8List crc32Bytes = Uint8List(4);
    crc32Bytes[0] = (crc32Checksum >> 24) & 0xFF;
    crc32Bytes[1] = (crc32Checksum >> 16) & 0xFF;
    crc32Bytes[2] = (crc32Checksum >> 8) & 0xFF;
    crc32Bytes[3] = crc32Checksum & 0xFF;

    CrcPacket result = CrcPacket(
      data: crc32Bytes,
    );

    List<int> crcCommand = result.build();

    try {
      await leftGlass!.sendData(crcCommand);
      // wait for a reply to be sent over the crcReplies stream
      //await leftGlass!.replies.stream.firstWhere((d) => d[0] == Commands.CRC);
      debugPrint('CRC reply received from left glass');

      await rightGlass!.sendData(crcCommand);
      //await rightGlass!.replies.stream.firstWhere((d) => d[0] == Commands.CRC);
      debugPrint('CRC reply received from right glass');

      return crcCommand;
    } catch (e) {
      return null;
    }
  }

  Future<bool?> _sendPacketEndPacket() async {
    try {
      await leftGlass!.sendData([0x20, 0x0d, 0x0e]);
      //await leftGlass!.replies.stream.firstWhere((d) => d[0] == 0x20);
      await rightGlass!.sendData([0x20, 0x0d, 0x0e]);
      //await rightGlass!.replies.stream.firstWhere((d) => d[0] == 0x20);
    } catch (e) {
      debugPrint('Error in sendTextPacket: $e');
      return false;
    }
    return null;
  }

  Future<void> sync() async {
    await _sync();
  }

  Future<void> _sync() async {
    if (!isConnected) {
      return;
    }

    // Synchronize time and weather with glasses
    try {
      await TimeSync.updateTimeAndWeather();
    } catch (e) {
      debugPrint('Error synchronizing time with glasses: $e');
    }

    final notes = await agixtDashboard.generateDashboardItems();
    for (var note in notes) {
      await sendNote(note);
    }

    // remove other notes if there are less than 4
    // so old notes are not shown
    if (notes.length < 4) {
      for (int i = notes.length; i < 4; i++) {
        final note = Note(
          noteNumber: i + 1,
          name: 'Empty',
          text: '',
        );
        await sendCommandToGlasses(note.buildDeleteCommand());
      }
    }

    final dash = await dashboardController.updateDashboardCommand();
    for (var command in dash) {
      await sendCommandToGlasses(command);
    }

    // every 10 minutes sync G1Setup
    if (DateTime.now().minute % 10 == 0) {
      final setup = await G1Setup.generateSetup().constructSetup();
      for (var command in setup) {
        await sendCommandToGlasses(command);
      }
    }

    // Sync silent mode setting with glasses
    bool isDisplayEnabled = await _isGlassesDisplayEnabled();
    await setSilentMode(!isDisplayEnabled);
  }

  Future<void> setMicrophone(bool open) async {
    final subCommand = open ? 0x01 : 0x00;

    // for an unknown issue the microphone will not close when sent to the left side
    // to work around this we send the command to the right side only
    await rightGlass!.sendData([Commands.OPEN_MIC, subCommand]);
  }

  /// Updates the time and weather on the glasses
  // Missing methods - adding basic implementations
  Future<void> _displayTranscriptionOnGlasses(String transcription) async {
    debugPrint('Displaying transcription: $transcription');
    await sendText(transcription);
  }

  Future<void> disconnectFromGlasses() async {
    debugPrint('Disconnecting from glasses');
    leftGlass?.disconnect();
    rightGlass?.disconnect();
    leftGlass = null;
    rightGlass = null;
  }

  Future<bool> _isGlassesDisplayEnabled() async {
    try {
      return await AuthService.getGlassesDisplayPreference();
    } catch (e) {
      debugPrint('Error checking glasses display preference: $e');
      return true; // Default to enabled if there's an error
    }
  }

  Future<void> setSilentMode(bool enabled) async {
    if (!isConnected) {
      debugPrint('Cannot set silent mode: glasses not connected');
      return;
    }
    debugPrint('Setting silent mode: $enabled');
    // Send silent mode command to glasses
    List<int> command = [0x03, enabled ? 0x0C : 0x0A];
    await sendCommandToGlasses(command);
  }

  Future<void> clearGlassesDisplay() async {
    if (!isConnected) {
      debugPrint('Cannot clear display: glasses not connected');
      return;
    }
    debugPrint('Clearing glasses display');
    await sendText(' '); // Send empty space to clear display
  }

  /// Updates weather data on the glasses
  Future<void> updateWeather() async {
    if (!isConnected) {
      debugPrint('Cannot update weather: glasses not connected');
      return;
    }

    try {
      await TimeSync.updateTimeAndWeather();
      debugPrint('Weather updated successfully');
    } catch (e) {
      debugPrint('Error updating weather: $e');
    }
  }

  /// Gets current weather information
  Future<String> getCurrentWeatherInfo() async {
    try {
      final weatherService = OpenMeteoWeatherService();
      final weatherData = await weatherService.getCurrentWeather();
      
      if (weatherData != null) {
        return '${weatherData.latitude.toStringAsFixed(2)}, ${weatherData.longitude.toStringAsFixed(2)}: ${weatherData.description}, ${weatherData.temperature.round()}°C';
      } else {
        return 'No weather data available';
      }
    } catch (e) {
      debugPrint('Error getting weather info: $e');
      return 'Error fetching weather data';
    }
  }
}
