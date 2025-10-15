/// Imports
/// ------------------------------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sessions/session.dart';


/// Scenario
/// ------------------------------------------------------------------------------------------------

/// The interface of a mobile wallet adapter scenario.
/// 
/// A scenario creates an encrypted session in which the dApp can invoke wallet methods.
abstract class Scenario {

  /// Creates a mobile wallet adapter scenario.
  const Scenario({
    required this.timeLimit,
  });

  /// The default timeout duration applied to a `connect` call.
  final Duration? timeLimit;

  /// Releases all acquired resources.
  @mustCallSuper
  Future<void> dispose();
  
  /// Establishes an encrypted session between the dApp and wallet endpoints.
  /// 
  /// `This method should run in a synchronized block and can only be called once.`
  Future<Session> connect({
    final Duration? timeLimit,
    final Uri? walletUriBase,
  });
}