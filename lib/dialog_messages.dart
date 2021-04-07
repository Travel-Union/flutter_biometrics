class DialogMessages {
  const DialogMessages({
    this.hint,
    this.notRecognized,
    this.success,
    this.cancel,
    this.title,
    this.requiredTitle,
    this.settings,
    this.settingsDescription,
    this.lockOut,
    this.goToSettingsButton,
    this.goToSettingsDescription,
    this.cancelButton,
  });

  final String? hint;
  final String? notRecognized;
  final String? success;
  final String? cancel;
  final String? title;
  final String? requiredTitle;
  final String? settings;
  final String? settingsDescription;
  //iOS specific messages
  final String? lockOut;
  final String? goToSettingsButton;
  final String? goToSettingsDescription;
  final String? cancelButton;

  Map<String, String> get messages {
    return <String, String>{
      'hint': hint ?? 'Touch sensor',
      'notRecognized':
          notRecognized ?? 'Fingerprint not recognized. Try again.',
      'success': success ?? 'Authentication successful.',
      'cancel': cancel ?? 'Cancel',
      'title': title ?? 'Authentication',
      'required': requiredTitle ?? 'Fingerprint required',
      'settings': settings ?? 'Go to settings',
      'settingsDescription': settingsDescription ??
          'Fingerprint is not set up on your device. Go to \'Settings > Security\' to add your fingerprint.',
      'lockOut': lockOut ??
          'Biometric authentication is disabled. Please lock and unlock your screen to '
              'enable it.',
      'goToSetting': goToSettingsButton ?? 'Go to settings',
      'goToSettingDescriptionIOS': goToSettingsDescription ??
          'Biometric authentication is not set up on your device. Please either enable '
              'Touch ID or Face ID on your phone.',
      'okButton': cancelButton ?? 'OK',
    };
  }
}
