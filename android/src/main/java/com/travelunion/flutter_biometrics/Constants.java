package com.travelunion.flutter_biometrics;

public class Constants {
    private Constants() {}

    final static String channel = "flutter_biometrics";

    final static class MethodNames {
        private MethodNames() {}

        final static String availableBiometricTypes = "availableBiometricTypes";
        final static String createKeys = "createKeys";
        final static String sign = "sign";
    }

    final static class BiometricsType {
        private BiometricsType() {}

        final static String faceId = "faceId";
        final static String fingerprint = "fingerprint";
        final static String iris = "iris";
        final static String undefined = "undefined";
    }

}
