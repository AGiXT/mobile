/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:webcrypto/webcrypto.dart';


/// Types
/// ------------------------------------------------------------------------------------------------

/// An ephemeral EC keypair on the P-256 curve.
typedef AssociationKeypair = KeyPair<EcdsaPrivateKey, EcdsaPublicKey>;

/// A base-64 URL encoding of an ECDSA public keypoint on the P-256 curve. 
/// 
/// The public keypoint is encoded using the `X9.62` public key format (0x04 || x || y), which is 
/// then base-64 URL encoded to create the association token.
typedef AssociationToken = String;

/// An EC keypair on the P-256 curve used to begin a Diffie-Hellman-Merkle key exchange.
typedef SessionKeypair = KeyPair<EcdhPrivateKey, EcdhPublicKey>;

/// A shared secret key calculated by the dApp and wallet endpoints.
typedef SharedSeckey = AesGcmSecretKey;

/// An opaque string representing a unique identifying token issued by the wallet endpoint to the 
/// dApp endpoint. The format and contents are an implementation detail of the wallet endpoint. The 
/// dApp endpoint can use this on future connections to reauthorize access to privileged methods.
typedef AuthToken = String;

// /// A base-64 encoded `account address`.
// typedef Base64EncodedAddress = String;

// /// A base-64 encoded `transaction signature`.
// typedef Base64EncodedSignature = String;

// /// A base-64 encoded `message payload`.
// typedef Base64EncodedMessage = String;

// /// A base-64 encoded `signed message`.
// typedef Base64EncodedSignedMessage = String;

// /// A base-64 encoded `signed transaction`.
// typedef Base64EncodedSignedTransaction = String;

// /// A base-64 encoded `transaction payload`.
// typedef Base64EncodedTransaction = String;

// /// Wallet connection callback function.
// typedef AssociationCallback<T> = Future<T> Function(SolanaWalletAdapterConnection connection);