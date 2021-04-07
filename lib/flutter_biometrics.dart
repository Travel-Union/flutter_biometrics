import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_biometrics/constants/method_names.dart';
import 'package:flutter_biometrics/helpers/biometrics_type_mapper.dart';
import 'package:flutter_biometrics/models/biometrics_type.dart';
import 'package:meta/meta.dart';

import 'dialog_messages.dart';

const String CHANNEL_NANME = 'flutter_biometrics';

/// Heavily influenced by [local_auth]
///
/// Let's you to create public/private key pair which is stored in native keystore and protected using biometric authentication
///
/// You can use generated key pair to create a cryptographic signature
class FlutterBiometrics {
  static const MethodChannel _channel = const MethodChannel(CHANNEL_NANME);

  /// Creates SHA256 RSA key pair for signing using biometrics
  ///
  /// Will create a new keypair each time method is called
  ///
  /// Returns Base-64 encoded public key as a [String] if successful
  ///
  /// [reason] is the message to show when user will be prompted to authenticate using biometrics
  ///
  /// [showIOSErrorDialog] is used on iOS side to decide if error dialog should be displayed
  ///
  /// Provide [dialogMessages] if you want to customize messages for the auth dialog
  Future<dynamic> createKeys({
    required String reason,
    showIOSErrorDialog = true,
    DialogMessages dialogMessages = const DialogMessages(),
  }) async {
    assert(reason != null);
    final Map<String, Object> args = <String, Object>{
      'reason': reason,
      'useErrorDialogs': showIOSErrorDialog,
    };

    args.addAll(dialogMessages.messages);

    return await _channel.invokeMethod<dynamic>(MethodNames.createKeys, args);
  }

  /// Signs [payload] using generated private key. [createKeys()] should be called once before using this method.
  ///
  /// Returns Base-64 encoded signature as a [String] if successful
  ///
  /// [payload] is Base 64 encoded string you want to sign using SHA256
  ///
  /// [reason] is the message to show when user will be prompted to authenticate using biometrics
  ///
  /// [showIOSErrorDialog] is used on iOS side to decide if error dialog should be displayed
  ///
  /// Provide [dialogMessages] if you want to customize messages for the auth dialog
  Future<dynamic> sign({
    required String payload,
    required String reason,
    showIOSErrorDialog = true,
    DialogMessages dialogMessages = const DialogMessages(),
  }) async {
    assert(payload != null);
    assert(reason != null);
    final Map<String, Object> args = <String, Object>{
      'payload': payload,
      'reason': reason,
      'useErrorDialogs': showIOSErrorDialog,
    };

    args.addAll(dialogMessages.messages);

    return await _channel.invokeMethod<dynamic>(MethodNames.sign, args);
  }

  /// Returns if device supports any of the available biometric authorisation types
  ///
  /// Returns a [Future] boolean
  Future<bool> get authAvailable async => (await getAvailableBiometricTypes()).isNotEmpty;

  /// Returns a list of enrolled biometrics
  ///
  /// Returns a [Future] List<BiometricType> with the following possibilities:
  /// - BiometricType.face
  /// - BiometricType.fingerprint
  /// - BiometricType.iris (not yet implemented)
  Future<List<BiometricsType>> getAvailableBiometricTypes() async {
    final List<String>? result = (await _channel.invokeListMethod<String>(MethodNames.availableBiometricTypes));

    return BiometricsTypeMapper.mapFrom(list: result);
  }
}
