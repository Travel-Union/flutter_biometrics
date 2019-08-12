package com.travelunion.flutter_biometrics;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.ContextThemeWrapper;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;
import android.content.DialogInterface;
import android.content.DialogInterface.OnClickListener;

import androidx.biometric.BiometricPrompt;
import androidx.biometric.BiometricPrompt.CryptoObject;
import androidx.fragment.app.FragmentActivity;

import java.util.concurrent.Executor;

import io.flutter.plugin.common.MethodCall;

@SuppressWarnings("deprecation")
class AuthenticationHelper extends BiometricPrompt.AuthenticationCallback
        implements Application.ActivityLifecycleCallbacks {

    interface AuthCompletionHandler {
        void onSuccess(CryptoObject cryptoObject);

        void onFailure();

        void onError(String code, String error);
    }

    private final FragmentActivity activity;
    private final AuthCompletionHandler completionHandler;
    private final MethodCall call;
    private final BiometricPrompt.PromptInfo promptInfo;
    private final UiThreadExecutor uiThreadExecutor;
    private final CryptoObject cryptoObject;

    public AuthenticationHelper(
            FragmentActivity activity, MethodCall call, AuthCompletionHandler completionHandler) {
        this.activity = activity;
        this.completionHandler = completionHandler;
        this.call = call;
        this.uiThreadExecutor = new UiThreadExecutor();
        this.promptInfo =
                new BiometricPrompt.PromptInfo.Builder()
                        .setDescription((String) call.argument("reason"))
                        .setTitle((String) call.argument("title"))
                        .setSubtitle((String) call.argument("hint"))
                        .setNegativeButtonText((String) call.argument("cancel"))
                        .build();
        this.cryptoObject = null;
    }

    public AuthenticationHelper(
            FragmentActivity activity, MethodCall call, CryptoObject cryptoObject, AuthCompletionHandler completionHandler) {
        this.activity = activity;
        this.completionHandler = completionHandler;
        this.call = call;
        this.uiThreadExecutor = new UiThreadExecutor();
        this.promptInfo =
                new BiometricPrompt.PromptInfo.Builder()
                        .setDescription((String) call.argument("reason"))
                        .setTitle((String) call.argument("title"))
                        .setSubtitle((String) call.argument("hint"))
                        .setNegativeButtonText((String) call.argument("cancel"))
                        .build();
        this.cryptoObject = cryptoObject;
    }

    public void authenticate() {
        activity.getApplication().registerActivityLifecycleCallbacks(this);
        BiometricPrompt prompt = new BiometricPrompt(activity, uiThreadExecutor, this);

        if(this.cryptoObject != null) {
            prompt.authenticate(promptInfo, cryptoObject);
        } else {
            prompt.authenticate(promptInfo);
        }
    }

    private void stop() {
        activity.getApplication().unregisterActivityLifecycleCallbacks(this);
    }

    @SuppressLint("SwitchIntDef")
    @Override
    public void onAuthenticationError(int errorCode, CharSequence errString) {
        switch (errorCode) {
            // https://developer.android.com/jetpack/androidx/releases/biometric
            // case BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL:
            //   completionHandler.onError(
            //       "PasscodeNotSet",
            //       "Phone not secured by PIN, pattern or password, or SIM is currently locked.");
            //   break;
            case BiometricPrompt.ERROR_NO_SPACE:
            case BiometricPrompt.ERROR_NO_BIOMETRICS:
                showGoToSettingsDialog();
                return;
            case BiometricPrompt.ERROR_HW_UNAVAILABLE:
            case BiometricPrompt.ERROR_HW_NOT_PRESENT:
                completionHandler.onError("not_available", "Biometrics is not available on this device.");
                break;
            case BiometricPrompt.ERROR_LOCKOUT:
                completionHandler.onError(
                        "temp_locked_out",
                        "The operation was canceled because the API is locked out due to too many attempts. This occurs after 5 failed attempts, and lasts for 30 seconds.");
                break;
            case BiometricPrompt.ERROR_LOCKOUT_PERMANENT:
                completionHandler.onError(
                        "locked_out",
                        "The operation was canceled because ERROR_LOCKOUT occurred too many times. Biometric authentication is disabled until the user unlocks with strong authentication (PIN/Pattern/Password)");
                break;
            case BiometricPrompt.ERROR_CANCELED:
                completionHandler.onFailure();
                break;
            default:
                completionHandler.onFailure();
        }
        stop();
    }

    @Override
    public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
        completionHandler.onSuccess(result.getCryptoObject());
        stop();
    }

    @Override
    public void onAuthenticationFailed() {}


    @Override
    public void onActivityPaused(Activity ignored) {
    }

    @Override
    public void onActivityResumed(Activity ignored) {
    }

    // Suppress inflateParams lint because dialogs do not need to attach to a parent view.
    @SuppressLint("InflateParams")
    private void showGoToSettingsDialog() {
        View view = LayoutInflater.from(activity).inflate(R.layout.go_to_setting, null, false);
        TextView message = (TextView) view.findViewById(R.id.fingerprint_required);
        TextView description = (TextView) view.findViewById(R.id.go_to_setting_description);
        message.setText((String) call.argument("required"));
        description.setText((String) call.argument("settingsDescription"));
        Context context = new ContextThemeWrapper(activity, R.style.AlertDialogCustom);
        OnClickListener goToSettingHandler =
                new OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        completionHandler.onFailure();
                        stop();
                        activity.startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS));
                    }
                };
        OnClickListener cancelHandler =
                new OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        completionHandler.onFailure();
                        stop();
                    }
                };
        new AlertDialog.Builder(context)
                .setView(view)
                .setPositiveButton((String) call.argument("settings"), goToSettingHandler)
                .setNegativeButton((String) call.argument("cancel"), cancelHandler)
                .setCancelable(false)
                .show();
    }

    // Unused methods for activity lifecycle.

    @Override
    public void onActivityCreated(Activity activity, Bundle bundle) {}

    @Override
    public void onActivityStarted(Activity activity) {}

    @Override
    public void onActivityStopped(Activity activity) {}

    @Override
    public void onActivitySaveInstanceState(Activity activity, Bundle bundle) {}

    @Override
    public void onActivityDestroyed(Activity activity) {}

    private static class UiThreadExecutor implements Executor {
        public final Handler handler = new Handler(Looper.getMainLooper());

        @Override
        public void execute(Runnable command) {
            handler.post(command);
        }
    }
}