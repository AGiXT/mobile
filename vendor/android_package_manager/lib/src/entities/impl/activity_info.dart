import 'package:android_package_manager/android_package_manager.dart';

import 'application_info.dart';

class ActivityInfoImpl extends ActivityInfo {
  ActivityInfoImpl(Map<String, dynamic> data,) : super(
    theme: data['theme'],
    launchMode: _parseLaunchMode(data['launchMode']),
    documentLaunchMode: _parseDocLaunchMode(data['documentLaunchMode'],),
    persistableMode: _parsePersistableMode(data['persistableMode'],),
    maxRecents: data['maxRecents'],
    permission: data['permission'],
    taskAffinity: data['taskAffinity'],
    targetActivity: data['targetActivity'],
    colorMode: _parseColorMode(data['colorMode'],),
    flags: data['flags'],
    screenOrientation: _parseScreenOrientation(data['screenOrientation'],),
    configChanges: data['configChanges'],
    softInputMode: _parseSoftInputMode(data['softInputMode'],),
    uiOptions: data['uiOptions'],
    parentActivityName: data['parentActivityName'],
    rotationAnimation: _parseRotationAnimation(data['rotationAnimation'],),
    windowLayout: data['windowLayout'] is Map<String, dynamic>
        ? WindowLayoutImpl(data['windowLayout'],)
        : null,
    themeResource: data['themeResource'],
    componentInfo: data.map(
      (key, value,) {
        if (key == 'applicationInfo') {
          return MapEntry(
            key,
            ApplicationInfoImpl(Map<String, dynamic>.from(value,),),
          );
        }
        return MapEntry(key, value,);
      }
    ),
  );

  static LaunchMode _parseLaunchMode(int data,) => LaunchMode.values.asMap()[data]!;

  static DocumentLaunchMode _parseDocLaunchMode(int data,) => DocumentLaunchMode.values.asMap()[data] ?? DocumentLaunchMode.none;

  static PersistableMode _parsePersistableMode(int data,) => PersistableMode.values.asMap()[data]!;

  static ColorMode _parseColorMode(int data,) => ColorMode.values.asMap()[data] ?? ColorMode.defaultColor;

  static ScreenOrientation _parseScreenOrientation(int data,) => ScreenOrientation.values.asMap()[data + 2] ?? ScreenOrientation.unspecified;

  static SoftInputState _parseSoftInputMode(int data,) => SoftInputState.values.asMap()[data] ?? SoftInputState.unspecified;

  static RotationAnimation _parseRotationAnimation(Object? data,) {
    if (data is int) {
      return RotationAnimation.values.asMap()[data + 1] ?? RotationAnimation.unspecified;
    }
    return RotationAnimation.unspecified;
  }
}

class WindowLayoutImpl extends WindowLayout {

  WindowLayoutImpl(Map<String, dynamic> data,): super(
    width: data['width'], widthFraction: data['widthFraction'],
    height: data['height'], heightFraction: data['heightFraction'],
    gravity: data['gravity'],
    minHeight: data['minHeight'], minWidth: data['minWidth'],
  );
}