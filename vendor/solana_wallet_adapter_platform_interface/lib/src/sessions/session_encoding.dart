/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:convert' show Converter, json, utf8;
import 'dart:typed_data' show Endian, Uint8List;
import 'package:solana_buffer/buffer.dart';
import 'package:solana_common/validators.dart';
import 'package:solana_jsonrpc/jsonrpc.dart';
import 'session_state.dart';


/// Session Encoder
/// ------------------------------------------------------------------------------------------------

/// Converts a JSON RPC request to an encrypted byte array.
class SessionEncoder extends Converter<JsonRpcRequest, Future<List<int>>> {

  /// Creates a session encoder.
  const SessionEncoder(this.state);

  /// The encrypted session state.
  final SessionState state;

  /// Encrypts [message] with [SessionState.sharedSeckey].
  Future<Uint8List> convert(final JsonRpcRequest message) async {
    
    check(state.isEncrypted, 'Attempting to encode a message before encryting the session.');

    // Create a buffer containing the dApp's sequence number.
    final Buffer sequenceNumber = Buffer(SessionState.sequenceNumberByteLength)
      ..setUint32(state.nextDAppSequenceNumber(), 0, Endian.big);

    // Generate a 12-byte buffer with random values.
    final Buffer initialisationVector = Buffer.random(SessionState.aesIvByteLength);
    
    // Encrypt the [message] using the [sharedSecretKey].
    final Uint8List cipherText = await state.sharedSeckey.encryptBytes(
      json.encode(message).codeUnits, 
      initialisationVector.asUint8List(), 
      additionalData: sequenceNumber.asUint8List(), 
      tagLength: SessionState.aesTagBitLength,
    );

    return (sequenceNumber + initialisationVector + cipherText).asUint8List();
  }
}


/// Session Decoder
/// ------------------------------------------------------------------------------------------------

/// Converts an encrypted websocket response to an unencrypted JSON object.
class SessionDecoder extends Converter<List<int>, Future<Map<String, dynamic>>> {

  /// Creates a session decoder.
  const SessionDecoder(this.state);

  /// The encrypted session state.
  final SessionState state;

  /// Decrypts [message] with [SessionState.sharedSeckey].
  Future<Map<String, dynamic>> convert(final List<int> message) async {

    check(state.isEncrypted, 'Attempting to decode a message before encryting the session.');

    // Create a [BufferReader] over the [message].
    final BufferReader reader = BufferReader.fromList(message);

    // Get the message sequence number, a 4-byte big-endian unsigned integer.
    final Buffer sequenceNumberBuffer = reader.getBuffer(SessionState.sequenceNumberByteLength);
    final int sequenceNumber = sequenceNumberBuffer.getUint32(0, Endian.big);
    state.checkWalletSequenceNumber(sequenceNumber);

    // Get the initialisation vector, a randomly generated list of 12 8-bit unsigned integers 
    // (which should be created for each encrypted message).
    final Buffer initialisationVector = reader.getBuffer(SessionState.aesIvByteLength);

    // Get the AES-128-GCM message ciphertext (i.e. the remaining contents).
    final Buffer ciphertext = reader.getBuffer();

    // Decrypt the ciphertext using the [sharedSecretKey].
    final Uint8List plainText = await state.sharedSeckey.decryptBytes(
      ciphertext.asUint8List(), 
      initialisationVector.asUint8List(), 
      additionalData: sequenceNumberBuffer.asUint8List(), 
      tagLength: SessionState.aesTagBitLength,
    );

    return json.decode(utf8.decode(plainText));
  }
}