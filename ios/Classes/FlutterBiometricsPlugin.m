#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>

#import "FlutterBiometricsPlugin.h"

@implementation FlutterBiometricsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_biometrics"
            binaryMessenger:[registrar messenger]];
  FlutterBiometricsPlugin* instance = [[FlutterBiometricsPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"createKeys" isEqualToString:call.method]) {
    [self createKeys:call.arguments withFlutterResult:result];
  } else if ([@"sign" isEqualToString:call.method]) {
    [self sign:call.arguments withFlutterResult:result];
  } else if ([@"availableBiometricTypes" isEqualToString:call.method]) {
    [self availableBiometricTypes:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

// Creates public/private key pair under the biometric auth

- (void)createKeys:(NSDictionary *)arguments withFlutterResult:(FlutterResult)result {
  LAContext *context = [[LAContext alloc] init];
  NSError *authError = nil;
  context.localizedFallbackTitle = @"";

  if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                           error:&authError]) {
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:arguments[@"reason"]
                      reply:^(BOOL success, NSError *error) {
                        if (success) {
                          [self createAndStoreKeyPair:arguments withFlutterResult:result];
                        } else {
                          switch (error.code) {
                            case LAErrorPasscodeNotSet:
                            case LAErrorTouchIDNotAvailable:
                            case LAErrorTouchIDNotEnrolled:
                            case LAErrorTouchIDLockout:
                              [self handleErrors:error flutterArguments:arguments withFlutterResult:result];
                              return;
                          }
                          result(@NO);
                        }
                      }];
  } else {
    [self handleErrors:authError flutterArguments:arguments withFlutterResult:result];
  }
}

- (void)sign: (NSDictionary *)arguments withFlutterResult:(FlutterResult)result {
  NSData *biometricKeyTag = [self getBiometricKeyTag];
  NSDictionary *query = @{
                          (id)kSecClass: (id)kSecClassKey,
                          (id)kSecAttrApplicationTag: biometricKeyTag,
                          (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                          (id)kSecReturnRef: @YES,
                          (id)kSecUseOperationPrompt: arguments[@"reason"]
                          };
  SecKeyRef privateKey;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKey);

  if (status == errSecSuccess) {
    NSError *error;
    NSData *dataToSign = [arguments[@"payload"] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signature = CFBridgingRelease(SecKeyCreateSignature(privateKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, (CFDataRef)dataToSign, (void *)&error));

    if (signature != nil) {
      NSString *signatureString = [signature base64EncodedStringWithOptions:0];
      result(signatureString);
    } else {
      result(@NO);
    }
  }
  else {
    result(@NO);
  }
}

// Retrieves available types of biometric auth

- (void)availableBiometricTypes:(FlutterResult)result {
  LAContext *context = [[LAContext alloc] init];
  NSError *authError = nil;
  NSMutableArray<NSString *> *biometrics = [[NSMutableArray<NSString *> alloc] init];
  if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                           error:&authError]) {
    if (authError == nil) {
      if (@available(iOS 11.0.1, *)) {
        if (context.biometryType == LABiometryTypeFaceID) {
          [biometrics addObject:@"face"];
        } else if (context.biometryType == LABiometryTypeTouchID) {
          [biometrics addObject:@"fingerprint"];
        }
      } else {
        [biometrics addObject:@"fingerprint"];
      }
    }
  } else if (authError.code == LAErrorTouchIDNotEnrolled) {
    [biometrics addObject:@"undefined"];
  }
  result(biometrics);
}

#pragma mark Private Methods

- (void) createAndStoreKeyPair:(NSDictionary *)arguments withFlutterResult:(FlutterResult)result {
  CFErrorRef error = NULL;

  SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                  kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                  kSecAccessControlTouchIDAny, &error);
  if (sacObject == NULL || error != NULL) {
    result(@NO);
    return;
  }

  NSData *biometricKeyTag = [self getBiometricKeyTag];
  NSDictionary *keyAttributes = @{
                                  (id)kSecClass: (id)kSecClassKey,
                                  (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                  (id)kSecAttrKeySizeInBits: @2048,
                                  (id)kSecPrivateKeyAttrs: @{
                                      (id)kSecAttrIsPermanent: @YES,
                                      (id)kSecUseAuthenticationUI: (id)kSecUseAuthenticationUIAllow,
                                      (id)kSecAttrApplicationTag: biometricKeyTag,
                                      (id)kSecAttrAccessControl: (__bridge_transfer id)sacObject
                                      }
                                  };

  [self deleteBiometricKey];
  NSError *gen_error = nil;
  id privateKey = CFBridgingRelease(SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyAttributes, (void *)&gen_error));

  if(privateKey != nil) {
    id publicKey = CFBridgingRelease(SecKeyCopyPublicKey((SecKeyRef)privateKey));
    CFDataRef publicKeyDataRef = SecKeyCopyExternalRepresentation((SecKeyRef)publicKey, nil);
    NSData *publicKeyData = (__bridge NSData *)publicKeyDataRef;
    NSData *publicKeyDataWithHeader = [self addHeaderPublickey:publicKeyData];
    NSString *publicKeyString = [publicKeyDataWithHeader base64EncodedStringWithOptions:0];
    result(publicKeyString);
  } else {
    NSString *message = [NSString stringWithFormat:@"Key generation error: %@", gen_error];
    
    result([FlutterError errorWithCode:[NSString stringWithFormat:@"%ld", gen_error.code] message:message details:gen_error.domain]);
  }
}

- (void)handleErrors:(NSError *)authError
     flutterArguments:(NSDictionary *)arguments
    withFlutterResult:(FlutterResult)result {
  NSString *errorCode = @"NotAvailable";
  switch (authError.code) {
    case LAErrorPasscodeNotSet:
    case LAErrorTouchIDNotEnrolled:
      if ([arguments[@"useErrorDialogs"] boolValue]) {
        [self alertMessage:arguments[@"goToSettingDescriptionIOS"]
                 firstButton:arguments[@"okButton"]
               flutterResult:result
            additionalButton:arguments[@"goToSetting"]];
        return;
      }
      errorCode = authError.code == LAErrorPasscodeNotSet ? @"PasscodeNotSet" : @"NotEnrolled";
      break;
    case LAErrorTouchIDLockout:
      [self alertMessage:arguments[@"lockOut"]
               firstButton:arguments[@"okButton"]
             flutterResult:result
          additionalButton:nil];
      return;
  }
  result([FlutterError errorWithCode:errorCode
                             message:authError.localizedDescription
                             details:authError.domain]);
}

- (void)alertMessage:(NSString *)message
         firstButton:(NSString *)firstButton
       flutterResult:(FlutterResult)result
    additionalButton:(NSString *)secondButton {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@""
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:firstButton
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                          result(@NO);
                                                        }];

  [alert addAction:defaultAction];
  if (secondButton != nil) {
    UIAlertAction *additionalAction = [UIAlertAction
        actionWithTitle:secondButton
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                  if (UIApplicationOpenSettingsURLString != NULL) {
                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    [[UIApplication sharedApplication] openURL:url];
                    result(@NO);
                  }
                }];
    [alert addAction:additionalAction];
  }
  [[UIApplication sharedApplication].delegate.window.rootViewController presentViewController:alert
                                                                                     animated:YES
                                                                                   completion:nil];
}

- (BOOL) biometricKeyExists {
  NSData *keyTag = [self getBiometricKeyTag];
  NSDictionary *searchQuery = @{
                                (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: keyTag,
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA
                                };

  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)searchQuery, nil);
  return status == errSecSuccess;
}

-(OSStatus) deleteBiometricKey {
  NSData *keyTag = [self getBiometricKeyTag];
  NSDictionary *deleteQuery = @{
                                (id)kSecClass: (id)kSecClassKey,
                                (id)kSecAttrApplicationTag: keyTag,
                                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA
                                };

  OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
  return status;
}

- (NSData *) getBiometricKeyTag {
  NSString *keyAlias = @"com.flutterbiometrics.biometricKey";
  NSData *keyTag = [keyAlias dataUsingEncoding:NSUTF8StringEncoding];
  return keyTag;
}

- (NSData *)addHeaderPublickey:(NSData *)publicKeyData {
    unsigned char builder[15];
    NSMutableData * encKey = [[NSMutableData alloc] init];
    unsigned long bitstringEncLength;

    static const unsigned char _encodedRSAEncryptionOID[15] = {

        /* Sequence of length 0xd made up of OID followed by NULL */
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00

    };
    // When we get to the bitstring - how will we encode it?
    if  ([publicKeyData length ] + 1  < 128 )
        bitstringEncLength = 1 ;
    else
        bitstringEncLength = (([publicKeyData length ] +1 ) / 256 ) + 2 ;
    //
    //        // Overall we have a sequence of a certain length
    builder[0] = 0x30;    // ASN.1 encoding representing a SEQUENCE
    //        // Build up overall size made up of -
    //        // size of OID + size of bitstring encoding + size of actual key
    size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength + [publicKeyData length];
    size_t j = encodeLength(&builder[1], i);
    [encKey appendBytes:builder length:j +1];

    // First part of the sequence is the OID
    [encKey appendBytes:_encodedRSAEncryptionOID
                 length:sizeof(_encodedRSAEncryptionOID)];

    // Now add the bitstring
    builder[0] = 0x03;
    j = encodeLength(&builder[1], [publicKeyData length] + 1);
    builder[j+1] = 0x00;
    [encKey appendBytes:builder length:j + 2];

    // Now the actual key
    [encKey appendData:publicKeyData];

    return encKey;
}

size_t encodeLength(unsigned char * buf, size_t length) {
    // encode length in ASN.1 DER format
    if (length < 128) {
        buf[0] = length;
        return 1;
    }

    size_t i = (length / 256) + 1;
    buf[0] = i + 0x80;
    for (size_t j = 0 ; j < i; ++j) {
        buf[i - j] = length & 0xFF;
        length = length >> 8;
    }

    return i + 1;
}

@end
