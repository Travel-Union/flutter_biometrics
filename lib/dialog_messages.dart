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
  });

  final String hint;
  final String notRecognized;
  final String success;
  final String cancel;
  final String title;
  final String requiredTitle;
  final String settings;
  final String settingsDescription;

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
    };
  }
}
