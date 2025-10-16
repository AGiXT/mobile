/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async' show FutureOr;
import '../models/account.dart';


/// Web Listener
/// ------------------------------------------------------------------------------------------------

abstract class WebListener {
  const WebListener();
  FutureOr<void> onConnect(final Account pubkey);
  FutureOr<void> onDisconnect();
  FutureOr<void> onAccountChanged(final Account? pubkey);
}