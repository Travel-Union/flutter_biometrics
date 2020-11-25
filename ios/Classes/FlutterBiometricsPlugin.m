#import "FlutterBiometricsPlugin.h"
#if __has_include(<flutter_biometrics/flutter_biometrics-Swift.h>)
#import <flutter_biometrics/flutter_biometrics-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_biometrics-Swift.h"
#endif

@implementation FlutterBiometricsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterBiometricsPlugin registerWithRegistrar:registrar];
}
@end
