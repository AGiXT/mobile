/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:flutter/material.dart' show AssetImage, Brightness;
import '../../constants.dart';
import '../../solana_wallet_adapter_platform.dart';
import '../channels/window_target.dart';
import 'app_info.dart';


/// Store Info
/// ------------------------------------------------------------------------------------------------

/// An interface for application store information.
abstract class StoreInfo {

  /// Creates an application store information instance.
  const StoreInfo(
    this.platform,
  ): assert(platform == 'android' || platform == 'ios' || platform == 'web');

  /// The platform name.
  final String platform;

  /// The applications supported by the current platform.
  List<AppInfo> get apps;

  /// The application options presented to the user when connecting. Returns an empty list on 
  /// platforms that support app disambiguation natively.
  /// 
  /// The [options] are a subset of [apps].
  List<AppInfo> get options => const [];

  /// Returns the application store uri for app [info].
  Uri uri(final AppInfo info);

  /// Launches the application store for app [info] and returns true if successful.
  /// 
  /// If [info] is omitted the store is launched for the first application found in [apps].
  Future<bool> open([final AppInfo? info]) {
    final AppInfo app = info ?? apps.first;
    return SolanaWalletAdapterPlatform.instance.openUri(uri(app), WindowTarget.blank);
  }

  /// Returns the application information by [host] name.
  /// 
  /// Returns `null` if [host] cannot be matched to an entry in [apps].
  /// 
  /// ```
  /// final AppInfo? info = StoreInfo.info('phantom.app');
  /// ```
  AppInfo? info(final String host) {
    for (final AppInfo info in apps) {
      if (info.host == host) {
        return info;
      }
    }
    return null;
  }

  /// Returns the store badge for [brightness].
  AssetImage badge(final Brightness brightness) => AssetImage(
    'badges/${platform}_badge_${brightness.name}.png', 
    package: packageName, 
  );
}