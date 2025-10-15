import 'package:android_package_manager/src/entities/base/configuration_info.dart';
import 'package:android_package_manager/src/entities/enums.dart';
import 'package:android_package_manager/src/utils/parser_utils.dart';

class ConfigurationInfoImpl extends ConfigurationInfo {

  ConfigurationInfoImpl(Map<String, dynamic> data,): super(
    glEsVersion: data['glEsVersion'],
    reqGlEsVersion: data['reqGlEsVersion'],
    reqInputFeatures: _parseInputFeatures(data['reqInputFeatures'],),
    reqKeyboardType: _parseKeyboardType(data['reqKeyboardType'],),
    reqNavigation: _parseReqNavigation(data['reqNavigation'],),
    reqTouchScreen: _parseReqTouchScreen(data['reqTouchScreen'],),
  );

  static Set<ConfigInputFeatures>? _parseInputFeatures(dynamic data,) {
    if (data is int) {
      return {
        if (containsBit(data, 0x00000001,))
          ConfigInputFeatures.hardKeyboard,
        if (containsBit(data, 0x00000002))
          ConfigInputFeatures.fiveWayNav,
      };
    }
    return null;
  }

  static PreferredKeyboardType _parseKeyboardType(dynamic data,) {
    if (data is int) {
      return PreferredKeyboardType.values.asMap()[data] ?? PreferredKeyboardType.undefined;
    }
    return PreferredKeyboardType.undefined;
  }

  static NavigationAvailability _parseReqNavigation(dynamic data,) {
    if (data is int) {
      return <int, NavigationAvailability>{
        0: NavigationAvailability.undefined,
        2: NavigationAvailability.dPad,
        3: NavigationAvailability.trackball,
        4: NavigationAvailability.wheel,
      }[data] ?? NavigationAvailability.undefined;
    }
    return NavigationAvailability.undefined;
  }

  static ConfigTouchScreen _parseReqTouchScreen(dynamic data,) {
    if (data is int) {
      return ConfigTouchScreen.values.asMap()[data + 1] ?? ConfigTouchScreen.noTouch;
    }
    return ConfigTouchScreen.noTouch;
  }
}