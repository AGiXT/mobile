import 'package:android_package_manager/src/entities/enums.dart';

abstract class ConfigurationInfo {

  ConfigurationInfo({
    required this.glEsVersion,
    this.reqGlEsVersion,
    this.reqInputFeatures,
    required this.reqKeyboardType,
    required this.reqNavigation,
    required this.reqTouchScreen,
  });

  final String glEsVersion;
  final int? reqGlEsVersion;
  final Set<ConfigInputFeatures>? reqInputFeatures;
  final PreferredKeyboardType reqKeyboardType;
  final NavigationAvailability reqNavigation;
  final ConfigTouchScreen reqTouchScreen;

}