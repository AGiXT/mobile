// class AppInfo {

//   /// Phantom.
//   phantom(
//     name: 'Phantom', 
//     androidId: 'app.phantom', 
//     iosId: '1598432977',
//     webKey: 'phantom.solana',
//     host: 'phantom.app',
//     scheme: 'phantom',
//     path: 'ul/solana-wallet',
//   ),

//   /// Solflare.
//   solflare(
//     name: 'Solflare', 
//     androidId: 'com.solflare.mobile', 
//     iosId: '1580902717',
//     webKey: 'solflare',
//     host: 'solflare.com',
//     scheme: 'solflare',
//     path: 'mobilewalletadapter',
//   ),
//   ;

//   /// Wallet application information.
//   const AppInfo({
//     required this.name,
//     required this.androidId,
//     required this.iosId,
//     required this.webKey,
//     required this.host,
//     required this.scheme,
//     required this.path,
//   });

//   /// The display name.
//   final String name;

//   /// The play store id.
//   final String androidId;

//   /// The app store id.
//   final String iosId;

//   /// The browser window key.
//   final String webKey;

//   /// The app's website host name.
//   final String host;

//   /// The app's custom protocol.
//   final String scheme;

//   /// The app's URL scheme path.
//   final String path;

//   /// The HTTPS uri of [host].
//   Uri get hostUri => Uri.https(host);

//   /// The wallet adapter uri base of the application.
//   Uri get walletUriBase => Uri.https(host, path);

//   /// The icon asset image.
//   AssetImage get icon => AppInfo.logo(host);

//   /// Creates an asset image from [host].
//   static AssetImage logo(final String host) 
//     => AssetImage('icons/$host.png', package: packageName);

//   /// Creates an asset image from [host] or `null` if host is omitted.
//   static AssetImage? tryLogo(final String? host) 
//     => host != null ? logo(host) : null;
// }


/// Imports
/// ------------------------------------------------------------------------------------------------


import 'package:flutter/widgets.dart';
import '../../constants.dart';
import 'app.dart';


/// App Information
/// ------------------------------------------------------------------------------------------------

/// App information for known wallet applications.
abstract class AppInfo {

  /// Creates an app information object.
  const AppInfo(
    this.app, {
    required this.id, 
    required this.name,
    required this.host,
    required this.schemePath,
  });

  /// The app type.
  final App app;

  /// The application store identifier.
  final String id;

  /// The display name.
  final String name;

  /// The app's website host name.
  final String host;

  /// The application's custom url scheme path.
  final String schemePath;

  /// The app's icon image.
  AssetImage get icon => AssetImage(
    'logos/$host.png', 
    package: packageName, 
  );

  /// The application's custom url scheme.
  Uri? get walletUriBase => Uri.https(host, schemePath);
}


/// Phantom App Info
/// ------------------------------------------------------------------------------------------------

class PhantomAppInfo extends AppInfo {

  /// `Phantom` wallet application information.
  const PhantomAppInfo({
    required super.id, 
    super.schemePath = 'ul/solana-wallet',
  }): super(
      App.phantom,
      name: 'Phantom',
      host: 'phantom.app',
    );
}


/// Solflare App Info
/// ------------------------------------------------------------------------------------------------

class SolflareAppInfo extends AppInfo {

  /// `Solflare` wallet application information.
  const SolflareAppInfo({
    required super.id, 
    super.schemePath = 'mobilewalletadapter',
  }): super(
      App.solflare,
      name: 'Solflare',
      host: 'solflare.com',
    );
}