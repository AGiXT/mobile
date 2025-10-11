import 'package:agixt/models/agixt/auth/auth.dart';
import 'package:agixt/models/g1/calendar.dart';
import 'package:agixt/models/g1/dashboard.dart';
import 'package:agixt/models/g1/note.dart';
import 'package:agixt/models/g1/notification.dart';
import 'package:agixt/models/g1/translate.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:agixt/utils/bitmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageSate();
}

class _DebugPageSate extends State<DebugPage> {
  final TextEditingController _textController = TextEditingController();
  final BluetoothManager bluetoothManager = BluetoothManager();

  void _showInfoSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _sendText() async {
    final String text = _textController.text;
    if (text.isEmpty) {
      _showInfoSnackBar('Please enter some text to send');
      return;
    }

    if (!bluetoothManager.isConnected) {
      _showInfoSnackBar('Glasses are not connected');
      return;
    }

    await bluetoothManager.sendText(text);
  }

  void _sendNotification() async {
    final String message = _textController.text;
    if (message.isEmpty) {
      _showInfoSnackBar('Please enter a message to send');
      return;
    }

    if (!bluetoothManager.isConnected) {
      _showInfoSnackBar('Glasses are not connected');
      return;
    }

    await bluetoothManager.sendNotification(
      NCSNotification(
        msgId: 1234567890,
        appIdentifier: "chat.fluffy.fluffychat",
        title: "Hello",
        subtitle: "subtitle",
        message: message,
        displayName: "DEV",
      ),
    );
  }

  void _sendImage() async {
    if (!bluetoothManager.isConnected) {
      _showInfoSnackBar('Glasses are not connected');
      return;
    }

    final image = await generateDemoBMP();
    await bluetoothManager.sendBitmap(image);
  }

  void _testCalendar() async {
    if (!bluetoothManager.isConnected) {
      _showInfoSnackBar('Glasses are not connected');
      return;
    }

    await bluetoothManager.setDashboardLayout(DashboardLayout.DASHBOARD_FULL);
    await bluetoothManager.sendCommandToGlasses(
      CalendarItem(
        location: "Test Place",
        name: "Test Event",
        time: "12:00",
      ).constructDashboardCalendarItem(),
    );
  }

  void _sendNoteDemo() async {
    if (!bluetoothManager.isConnected) {
      _showInfoSnackBar('Glasses are not connected');
      return;
    }

    final note1 = Note(
      noteNumber: 1,
      name: 'AGiXT',
      text:
          '☐ 09:00 Take medication\n☐ 09:18 Take bus 85\n☐ 09:58 take train to FN',
    );
    final note2 = Note(
      noteNumber: 2,
      name: 'Note 2',
      text: 'This is another note',
    );

    await bluetoothManager.sendNote(note1);
    await bluetoothManager.sendNote(note2);
    await bluetoothManager.setDashboardLayout(DashboardLayout.DASHBOARD_DUAL);
  }

  // Removed _debugTimeCommand as it relied on TimeAndWeather

  void _debugTranslateCommand() async {
    if (!bluetoothManager.isConnected) {
      _showInfoSnackBar('Glasses are not connected');
      return;
    }

    final tr = Translate(
      fromLanguage: TranslateLanguages.FRENCH,
      toLanguage: TranslateLanguages.ENGLISH,
    );
    await bluetoothManager.sendCommandToGlasses(tr.buildSetupCommand());
    await bluetoothManager.rightGlass!.sendData(
      tr.buildRightGlassStartCommand(),
    );
    for (final cmd in tr.buildInitalScreenLoad()) {
      await bluetoothManager.sendCommandToGlasses(cmd);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await bluetoothManager.setMicrophone(true);

    final demoText = [
      "Hello and welcome to AGiXT",
      "These glasses cured my autism!",
      "haha no just kidding but they are amazing",
      "you are watching a demo of translation",
      "but nobody is talking??",
      "that is why I said DEMO...",
      "anyway enjoy AGiXT",
      "and don't forget to like and subscribe",
    ];
    final demoTextFrench = [
      "Bonjour et bienvenue à AGiXT",
      "Ces lunettes ont guéri mon autisme!",
      "haha non je rigole mais elles sont incroyables",
      "vous regardez une démo de traduction",
      "mais personne ne parle??",
      "c'est pourquoi j'ai dit DEMO...",
      "de toute façon, profitez de AGiXT",
      "et n'oubliez pas de liker et de vous abonner",
    ];
    for (var i = 0; i < demoText.length; i++) {
      await bluetoothManager.sendCommandToGlasses(
        tr.buildTranslatedCommand(demoText[i]),
      );
      await bluetoothManager.sendCommandToGlasses(
        tr.buildOriginalCommand(demoTextFrench[i]),
      );
      await Future.delayed(const Duration(seconds: 4));
    }
    await bluetoothManager.setMicrophone(false);
  }

  void _showJWT() async {
    final jwt = await AuthService.getJwt();
    final isLoggedIn = await AuthService.isLoggedIn();
    final email = await AuthService.getEmail();

    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('JWT Information'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Logged in: ${isLoggedIn ? "Yes" : "No"}'),
                    if (email != null && email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Email: $email'),
                      ),
                    if (jwt != null && jwt.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text('JWT Token:'),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jwt,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (jwt == null || jwt.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text('No JWT token found. Not logged in.'),
                      ),
                  ],
                ),
              ),
              actions: [
                if (jwt != null && jwt.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jwt));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JWT copied to clipboard'),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Copy JWT'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Optionally initiate scan here or via button
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(labelText: 'Enter text to send'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _sendText,
                child: const Text('Send Text'),
              ),
              ElevatedButton(
                onPressed: _sendNotification,
                child: const Text('Send Notification'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendImage,
            child: const Text("Send Image"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendNoteDemo,
            child: const Text("Send Note Demo"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _testCalendar,
            child: const Text("Test Calendar"),
          ),
          const SizedBox(height: 20),
          // Removed button for Debug Time/Weather Command
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _debugTranslateCommand,
            child: const Text("Debug Translate"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _showJWT,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple, // Make it stand out
              foregroundColor: Colors.white,
            ),
            child: const Text("Show JWT"),
          ),
        ],
      ),
    );
  }
}
