import Flutter
import UIKit
import LocalAuthentication
import Security

public class SwiftFlutterBiometricsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: BiometricsConstants.channel, binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterBiometricsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case BiometricsConstants.MethodNames.createKeys:
            guard let args = call.arguments else {
                result("no arguments found for method: (" + call.method + ")")
                return
            }
            
            if let myArgs = args as? [String: Any],
               let reason = myArgs["reason"] as? String {
                self.createKeys(reason: reason, result: result)
            } else {
                result("'reason' is required for method: (" + call.method + ")")
            }
            break
        case BiometricsConstants.MethodNames.sign:
            guard let args = call.arguments else {
                result("no arguments found for method: (" + call.method + ")")
                return
            }
            
            if let myArgs = args as? [String: Any],
               let reason = myArgs["reason"] as? String,
               let payload = myArgs["payload"] as? String {
                self.sign(reason: reason, payload: payload, result: result)
            } else {
                result("'reason' and 'payload' are required for method: (" + call.method + ")")
            }
            break
        case BiometricsConstants.MethodNames.availableBiometricTypes:
            self.availableBiometricTypes(result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func createKeys(reason: String, result: @escaping FlutterResult) -> Void {
        let context = LAContext()
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason, reply: {(success, error) in
                if (success) {
                    if let domainState = context.evaluatedPolicyDomainState {
                        _ = KeyChain.save(key: "domainState", data: domainState.base64EncodedData())
                    }
                    
                    self.createAndStoreKeyPair(result:result)
                } else {
                    result(nil)
                }
            })
        }
    }
    
    private func sign(reason: String, payload: String, result: @escaping FlutterResult) -> Void {
        let context = LAContext()
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            if let domainState = context.evaluatedPolicyDomainState {
                let domainStateData = domainState.base64EncodedData()
                
                if let oldDomainState = KeyChain.load(key: "domainState") {
                    if let decodedString = String(data: domainStateData, encoding: .utf8),
                       let oldDecodedString = String(data: oldDomainState, encoding: .utf8) {
                        if(decodedString != oldDecodedString) {
                            result(FlutterError.init(code: "biometrics_invalidated", message: "Biometric keys are invalidated due to differences stored in KeyChain", details: nil))
                            return
                        }
                    }
                } else {
                    _ = KeyChain.save(key: "domainState", data: domainStateData)
                }
            }
        }
        
        let keyTag = self.getBiometricKeyTag()
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true,
            kSecUseOperationPrompt as String: reason
        ] as [String : Any]
        
        var item: CFTypeRef?
        
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if (status == errSecSuccess) {
            let privateKey = item as! SecKey
            
            let decodedData = NSData.init(base64Encoded: payload, options: [])
            let signature = SecKeyCreateSignature(privateKey, SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256, decodedData!, nil)
            
            if (signature != nil) {
                let signatureString = NSData(data: signature! as Data).base64EncodedString(options: [])
                result(signatureString);
            } else {
                result(nil)
            }
        }
        else {
            result(nil)
        }
    }
    
    private func availableBiometricTypes(result: @escaping FlutterResult) -> Void {
        let context = LAContext()
        
        var biometrics : [String] = []
        
        var authError: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            if (authError == nil) {
                if #available(iOS 11, *) {
                    if (context.biometryType == .faceID) {
                        biometrics.append(BiometricsConstants.BiometricsType.faceId)
                    } else if (context.biometryType == .touchID) {
                        biometrics.append(BiometricsConstants.BiometricsType.fingerprint)
                    } else if (context.biometryType == .LABiometryNone) {
                        biometrics.append(BiometricsConstants.BiometricsType.none)
                    }
                } else {
                    biometrics.append(BiometricsConstants.BiometricsType.fingerprint)
                }
            }
        } else if (authError!.code == kLAErrorTouchIDNotEnrolled) {
            biometrics.append(BiometricsConstants.BiometricsType.undefined)
        }
        
        result(biometrics)
    }
    
    private func createAndStoreKeyPair(result: @escaping FlutterResult) -> Void {
        var sec: SecAccessControl?
        
        if #available(iOS 11.3, *) {
            sec = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryAny, nil)
        } else {
            sec = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .touchIDAny, nil)
        }
        
        if(sec == nil) {
            result(nil)
            return
        }
        
        let keyTag = self.getBiometricKeyTag()
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessControl as String: sec!
            ]
        ] as [String : Any]
        
        self.deleteBiometricKey()
        
        let privateKey = SecKeyCreateRandomKey(query as CFDictionary, nil)
        
        if(privateKey != nil) {
            let publicKey = SecKeyCopyPublicKey(privateKey!)
            let publicKeyData = SecKeyCopyExternalRepresentation(publicKey!, nil)
            let publicKeyDataWithHeader = self.dataByPrependingX509Header(publicKey: publicKeyData! as Data)
            let publicKeyString = publicKeyDataWithHeader.base64EncodedString(options: [])
            result(publicKeyString);
        } else {
            result(nil)
        }
    }
    
    private func deleteBiometricKey() -> OSStatus {
        let keyTag = self.getBiometricKeyTag()
        
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ] as [String : Any]
        
        return SecItemDelete(query as CFDictionary)
    }
    
    private func getBiometricKeyTag() -> Data {
        let keyAlias = "com.flutterbiometrics.biometricKey"
        return keyAlias.data(using: .utf8)!
    }
    
    func dataByPrependingX509Header(publicKey: Data) -> Data {
        let result = NSMutableData()
        
        let encodingLength: Int = (publicKey.count + 1).encodedOctets().count
        let OID: [CUnsignedChar] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
                                    0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]
        
        var builder: [CUnsignedChar] = []
        
        // ASN.1 SEQUENCE
        builder.append(0x30)
        
        // Overall size, made of OID + bitstring encoding + actual key
        let size = OID.count + 2 + encodingLength + publicKey.count
        let encodedSize = size.encodedOctets()
        builder.append(contentsOf: encodedSize)
        result.append(builder, length: builder.count)
        result.append(OID, length: OID.count)
        builder.removeAll(keepingCapacity: false)
        
        builder.append(0x03)
        builder.append(contentsOf: (publicKey.count + 1).encodedOctets())
        builder.append(0x00)
        result.append(builder, length: builder.count)
        
        // Actual key bytes
        result.append(publicKey)
        
        return result as Data
    }
    
    func biometricKeyExists() -> Bool {
        let keyTag = self.getBiometricKeyTag()
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ] as [String : Any]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

///
/// Encoding/Decoding lengths as octets
///
private extension NSInteger {
    func encodedOctets() -> [CUnsignedChar] {
        // Short form
        if self < 128 {
            return [CUnsignedChar(self)];
        }
        
        // Long form
        let i = Int(log2(Double(self)) / 8 + 1)
        var len = self
        var result: [CUnsignedChar] = [CUnsignedChar(i + 0x80)]
        
        for _ in 0..<i {
            result.insert(CUnsignedChar(len & 0xFF), at: 1)
            len = len >> 8
        }
        
        return result
    }
    
    init?(octetBytes: [CUnsignedChar], startIdx: inout NSInteger) {
        if octetBytes[startIdx] < 128 {
            // Short form
            self.init(octetBytes[startIdx])
            startIdx += 1
        } else {
            // Long form
            let octets = NSInteger(octetBytes[startIdx] as UInt8 - 128)
            
            if octets > octetBytes.count - startIdx {
                self.init(0)
                return nil
            }
            
            var result = UInt64(0)
            
            for j in 1...octets {
                result = (result << 8)
                result = result + UInt64(octetBytes[startIdx + j])
            }
            
            startIdx += 1 + octets
            self.init(result)
        }
    }
}
