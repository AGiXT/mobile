import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solana_wallet_adapter/solana_wallet_adapter.dart';
import 'wallet_adapter_service.dart';

/// Service to bridge Phantom wallet authentication between native app and webview.
///
/// This service handles:
/// 1. Detecting when the user wants to login with Phantom in the webview
/// 2. Opening the native Phantom app to authorize the connection
/// 3. Getting the wallet address and passing it back to the webview
class PhantomWalletBridge {
  static final PhantomWalletBridge _instance = PhantomWalletBridge._internal();
  factory PhantomWalletBridge() => _instance;
  PhantomWalletBridge._internal();

  bool _isInitialized = false;
  Account? _connectedAccount;

  /// Initialize the wallet adapter using the existing WalletAdapterService
  /// Note: WalletAdapterService should already be initialized in main.dart
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // WalletAdapterService should already be initialized in main.dart
      // Just check if it's available
      if (!WalletAdapterService.isAvailable) {
        // If not available, try to initialize it (fallback)
        await WalletAdapterService.initialize(
          appUri: 'https://agixt.dev/',
          appName: 'AGiXT',
          cluster: Cluster.mainnet,
        );
      }
      _isInitialized = WalletAdapterService.isAvailable;
      debugPrint('PhantomWalletBridge: Initialized, WalletAdapterService available: $_isInitialized');
    } catch (e) {
      debugPrint('PhantomWalletBridge: Error initializing: $e');
      // Try to reinitialize on next attempt
      _isInitialized = false;
    }
  }

  /// Check if the wallet adapter is initialized and ready
  bool get isReady => WalletAdapterService.isAvailable;

  /// Get the currently connected account object (needed for signing)
  Account? get connectedAccount => _connectedAccount;

  /// Get the currently connected wallet address (base58 format)
  String? get connectedAddress {
    if (_connectedAccount != null) {
      return _connectedAccount!.toBase58();
    }
    return null;
  }

  /// Check if a wallet is already connected/authorized
  bool get isConnected => _connectedAccount != null;

  /// Connect to Phantom wallet and get the wallet address
  ///
  /// Returns the wallet address in base58 format, or null if the connection failed
  Future<String?> connectAndGetAddress() async {
    if (!_isInitialized) {
      debugPrint('PhantomWalletBridge: Not initialized, initializing now...');
      await initialize();
    }

    if (!WalletAdapterService.isAvailable) {
      debugPrint('PhantomWalletBridge: WalletAdapterService not available');
      return null;
    }

    try {
      debugPrint('PhantomWalletBridge: Checking if Phantom is installed...');
      
      // Check if Phantom is installed
      final isPhantomInstalled = WalletAdapterService.supportsProvider('phantom');
      debugPrint('PhantomWalletBridge: Phantom installed: $isPhantomInstalled');
      
      if (!isPhantomInstalled) {
        debugPrint('PhantomWalletBridge: Phantom wallet not installed');
        return null;
      }

      debugPrint('PhantomWalletBridge: Attempting to connect with Phantom via WalletAdapterService...');

      // Use the WalletAdapterService connect method which has all the fallback logic
      final account = await WalletAdapterService.connect(providerId: 'phantom');
      _connectedAccount = account;
      
      final address = account.toBase58();
      debugPrint('PhantomWalletBridge: Successfully connected, address: $address');
      return address;
    } catch (e, stackTrace) {
      debugPrint('PhantomWalletBridge: Error connecting to wallet: $e');
      debugPrint('PhantomWalletBridge: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Disconnect from the wallet
  Future<void> disconnect() async {
    try {
      await WalletAdapterService.disconnect();
      _connectedAccount = null;
      debugPrint('PhantomWalletBridge: Disconnected from wallet');
    } catch (e) {
      debugPrint('PhantomWalletBridge: Error disconnecting: $e');
    }
  }

  /// Sign a message with the connected wallet
  ///
  /// This can be used if the web app requires a signed nonce for verification
  Future<String?> signMessage(String message) async {
    if (!isReady || _connectedAccount == null) {
      debugPrint('PhantomWalletBridge: Not ready to sign message');
      return null;
    }

    try {
      final signature = await WalletAdapterService.signMessage(
        message,
        account: _connectedAccount!,
        providerId: 'phantom',
      );
      debugPrint('PhantomWalletBridge: Message signed successfully');
      return signature;
    } catch (e) {
      debugPrint('PhantomWalletBridge: Error signing message: $e');
      return null;
    }
  }

  /// Check if Phantom app is likely installed
  Future<bool> isPhantomLikelyInstalled() async {
    if (!_isInitialized) {
      await initialize();
    }
    return WalletAdapterService.supportsProvider('phantom');
  }

  /// Show a dialog asking the user if they want to use the Phantom app
  static Future<bool> showPhantomAppDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1625),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFFAB9FF2), // Phantom purple
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Use Phantom App?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Would you like to use your Phantom wallet app to sign in?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This will open the Phantom app to connect your wallet and automatically sign you in.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Continue in Browser',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFAB9FF2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Open Phantom'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await WalletAdapterService.disconnect();
    _connectedAccount = null;
    _isInitialized = false;
  }
}
