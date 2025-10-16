/// Imports
/// ------------------------------------------------------------------------------------------------

import 'app_info.dart';
import 'store_info.dart';


/// Web Store
/// ------------------------------------------------------------------------------------------------

/// Web Store helper methods.
class WebStore extends StoreInfo {
  
  /// Creates an instance of [WebStore].
  const WebStore._(): super('web');

  /// An instance of [WebStore].
  static WebStore get instance => const WebStore._();
  
  @override
  List<AppInfo> get apps => const [ // The javascript window object keys.
    PhantomAppInfo(
      id: 'phantom.solana', 
      schemePath: 'phantom.solana',
    ),
    SolflareAppInfo(
      id: 'solflare', 
      schemePath: 'solflare',
    ),
  ];

  @override
  List<AppInfo> get options => apps;

  @override
  Uri uri(final AppInfo info) => Uri.https(info.host, 'download');
}