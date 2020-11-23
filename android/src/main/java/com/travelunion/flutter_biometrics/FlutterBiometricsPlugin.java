package com.travelunion.flutter_biometrics;

import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyPermanentlyInvalidatedException;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import androidx.fragment.app.FragmentActivity;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.RSAKeyGenParameterSpec;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicBoolean;

import androidx.biometric.BiometricPrompt.CryptoObject;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class FlutterBiometricsPlugin implements MethodCallHandler {
  protected static String KEY_ALIAS = "biometric_key";
  protected static String KEYSTORE = "AndroidKeyStore";
  private final Registrar registrar;
  private final AtomicBoolean authInProgress = new AtomicBoolean(false);

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_biometrics");
    channel.setMethodCallHandler(new FlutterBiometricsPlugin(registrar));
  }

  private FlutterBiometricsPlugin(Registrar registrar) {
    this.registrar = registrar;
  }

  @Override
  public void onMethodCall(MethodCall call, final Result result) {
    if (call.method.equals("createKeys")) {
      createKeys(call, result);
    } else if (call.method.equals("sign")) {
      sign(call, result);
    } else if (call.method.equals("availableBiometricTypes")) {
      availableBiometricTypes(result);
    } else {
      result.notImplemented();
    }
  }

  protected void createKeys(MethodCall call, final Result result) {
    if (!authInProgress.compareAndSet(false, true)) {
      result.error("auth_in_progress", "Authentication in progress", null);
      return;
    }

    Activity activity = registrar.activity();
    if (activity == null || activity.isFinishing()) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("no_activity", "local_auth plugin requires a foreground activity", null);
      }
      return;
    }

    if (!(activity instanceof FragmentActivity)) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("no_fragment_activity", "local_auth plugin requires activity to be a FragmentActivity.", null);
      }
      return;
    }

    AuthenticationHelper authenticationHelper = new AuthenticationHelper((FragmentActivity) activity, call,
        new AuthenticationHelper.AuthCompletionHandler() {
          @Override
          public void onSuccess(CryptoObject cryptoObject) {
            if (authInProgress.compareAndSet(true, false)) {
              try {
                deleteBiometricKey();

                KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA,
                    KEYSTORE);

                KeyGenParameterSpec keyGenParameterSpec = new KeyGenParameterSpec.Builder(KEY_ALIAS,
                    KeyProperties.PURPOSE_SIGN).setDigests(KeyProperties.DIGEST_SHA256)
                        .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
                        .setAlgorithmParameterSpec(new RSAKeyGenParameterSpec(2048, RSAKeyGenParameterSpec.F4))
                        .setUserAuthenticationRequired(true).build();

                keyPairGenerator.initialize(keyGenParameterSpec);

                KeyPair keyPair = keyPairGenerator.generateKeyPair();

                result.success(getEncodedPublicKey(keyPair));
              } catch (Exception e) {
                result.error("create_keys_error", "Error generating public private keys: " + e.getMessage(), null);
              }
            }
          }

          @Override
          public void onFailure() {
            if (authInProgress.compareAndSet(true, false)) {
              result.success(false);
            }
          }

          @Override
          public void onError(String code, String error) {
            if (authInProgress.compareAndSet(true, false)) {
              result.error(code, error, null);
            }
          }
        });
    authenticationHelper.authenticate();
  }

  protected void sign(final MethodCall call, final Result result) {
    if (!authInProgress.compareAndSet(false, true)) {
      result.error("auth_in_progress", "Authentication in progress", null);
      return;
    }

    Activity activity = registrar.activity();
    if (activity == null || activity.isFinishing()) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("no_activity", "local_auth plugin requires a foreground activity", null);
      }
      return;
    }

    if (!(activity instanceof FragmentActivity)) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("no_fragment_activity", "local_auth plugin requires activity to be a FragmentActivity.", null);
      }
      return;
    }

    if (call.argument("payload") == null) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("payload_not_provided", "You need to provide payload to sign", null);
      }
      return;
    }

    try {
      KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
      keyStore.load(null);

      PrivateKey privateKey = (PrivateKey) keyStore.getKey(KEY_ALIAS, null);

      Signature signature = Signature.getInstance("SHA256withRSA");
      signature.initSign(privateKey);

      CryptoObject cryptoObject = new CryptoObject(signature);

      AuthenticationHelper authenticationHelper = new AuthenticationHelper((FragmentActivity) activity, call,
          cryptoObject, new AuthenticationHelper.AuthCompletionHandler() {
            @Override
            public void onSuccess(CryptoObject cryptoObject) {
              if (authInProgress.compareAndSet(true, false)) {
                try {
                  Signature cryptoSignature = cryptoObject.getSignature();
                  byte[] decoded = Base64.decode((String) call.argument("payload"), Base64.DEFAULT);
                  cryptoSignature.update(decoded);
                  byte[] signed = cryptoSignature.sign();
                  String signedString = Base64.encodeToString(signed, Base64.DEFAULT);
                  signedString = signedString.replaceAll("\r", "").replaceAll("\n", "");
                  result.success(signedString);
                } catch (Exception e) {
                  result.error("sign_error", "Error generating signing payload: " + e.getMessage(), null);
                }
              }
            }

            @Override
            public void onFailure() {
              if (authInProgress.compareAndSet(true, false)) {
                result.success(false);
              }
            }

            @Override
            public void onError(String code, String error) {
              if (authInProgress.compareAndSet(true, false)) {
                result.error(code, error, null);
              }
            }
          });
      authenticationHelper.authenticate();
    } catch(KeyPermanentlyInvalidatedException invalidatedException) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("biometrics_invalidated", "Biometric keys are invalidated: " + invalidatedException.getMessage(), null);
      }
    } catch (Exception e) {
      if (authInProgress.compareAndSet(true, false)) {
        result.error("sign_error_key", "Error retrieving keys: " + e.getMessage(), null);
      }
    }
  }

  protected void availableBiometricTypes(final Result result) {
    try {
      Activity activity = registrar.activity();
      if (activity == null || activity.isFinishing()) {
        result.error("no_activity", "local_auth plugin requires a foreground activity", null);
        return;
      }
      ArrayList<String> biometrics = new ArrayList<String>();
      PackageManager packageManager = activity.getPackageManager();
      if (Build.VERSION.SDK_INT >= 23) {
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)) {
          biometrics.add("fingerprint");
        }
      }
      if (Build.VERSION.SDK_INT >= 29) {
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_FACE)) {
          biometrics.add("face");
        }
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_IRIS)) {
          biometrics.add("iris");
        }
      }
      result.success(biometrics);
    } catch (Exception e) {
      result.error("no_biometrics_available", e.getMessage(), null);
    }
  }

  protected String getEncodedPublicKey(KeyPair keyPair) {
    PublicKey publicKey = keyPair.getPublic();
    byte[] encodedPublicKey = publicKey.getEncoded();
    String publicKeyString = Base64.encodeToString(encodedPublicKey, Base64.DEFAULT);
    return publicKeyString.replaceAll("\r", "").replaceAll("\n", "");
  }

  protected boolean deleteBiometricKey() {
    try {
      KeyStore keyStore = KeyStore.getInstance(KEYSTORE);
      keyStore.load(null);

      keyStore.deleteEntry(KEY_ALIAS);
      return true;
    } catch (Exception e) {
      return false;
    }
  }
}
