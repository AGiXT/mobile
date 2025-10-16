/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_wallet_adapter_platform_interface/solana_wallet_adapter_platform.dart';
import 'package:solana_wallet_adapter_platform_interface/scenarios.dart';
import 'package:solana_wallet_adapter_platform_interface/stores.dart';


/// Solana Wallet Adapter Android
/// ------------------------------------------------------------------------------------------------

/// A Solana wallet adapter for Android.
class SolanaWalletAdapterAndroid extends SolanaWalletAdapterPlatform {
  
  /// Creates a [SolanaWalletAdapterAndroid] and sets it as the 
  /// [SolanaWalletAdapterPlatform.instance].
  static void registerWith() {
    SolanaWalletAdapterPlatform.instance = SolanaWalletAdapterAndroid();
  }

  @override
  StoreInfo get store => PlayStore.instance;

  @override
  Scenario scenario({ 
    final Duration? timeLimit, 
  }) => MobileAssociationScenario(
    timeLimit: timeLimit,
  );
}