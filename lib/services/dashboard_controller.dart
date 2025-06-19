import 'dart:typed_data';

import 'package:agixt/models/g1/dashboard.dart';

class DashboardController {
  static final DashboardController _singleton = DashboardController._internal();

  List<int> dashboardLayout = DashboardLayout.DASHBOARD_DUAL;

  factory DashboardController() {
    return _singleton;
  }

  DashboardController._internal();

  // Removed _getTimeFormatFromPreferences
  // Removed _getTemperatureUnitFromPreferences

  Future<List<Uint8List>> updateDashboardCommand() async {
    List<Uint8List> commands = [];
    // Removed weather fetching and TimeAndWeather command

    List<int> dashlayoutCommand =
        DashboardLayout.DASHBOARD_CHANGE_COMMAND.toList();
    dashlayoutCommand.addAll(dashboardLayout);

    commands.add(Uint8List.fromList(dashlayoutCommand));

    return commands;
  }
}
