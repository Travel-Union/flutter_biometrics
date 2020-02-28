# flutter_biometrics

***Documentation is under contruction.***

Flutter plugin which lets you to generate key pair and do cryptographic signing using biometric authentication.

Heavily influenced by [local_auth](https://github.com/flutter/plugins/tree/master/packages/local_auth)

## Usage in Dart

Import the relevant file:

```dart
import 'package:flutter_biometrics/flutter_biometrics.dart';
```

Available methods:

```dart
bool authAvailable =
    await FlutterBiometrics().authAvailable();
```

```dart
List<BiometricType> getAvailableBiometricTypes =
    await FlutterBiometrics().getAvailableBiometricTypes();
```

```dart
String publicKeyAsBase64 =
    await FlutterBiometrics().createKeys(reason: 'Please authenticate to generate keys');
```

```dart
bool signedPayloadAsBase64 =
    await FlutterBiometrics().sign(payload: 'base64string', reason: 'Please authenticate to sign payload');
```

## Android Integration (taken from [local_auth](https://github.com/flutter/plugins/tree/master/packages/local_auth))

Note that local_auth plugin requires the use of a FragmentActivity as
opposed to Activity. This can be easily done by switching to use
`FlutterFragmentActivity` as opposed to `FlutterActivity` in your
manifest (or your own Activity class if you are extending the base class).

Update your project's `AndroidManifest.xml` file to include the
`USE_FINGERPRINT` permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          package="com.example.app">
  <uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<manifest>
```

## Getting Started

For help getting started with Flutter, view Flutter 
[online documentation](https://flutter.dev/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.
