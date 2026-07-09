class EmailSignUpController {
  static const invalidEmailMessage = 'Enter a valid email';

  String? submittedEmail;
  String? errorText;

  bool submit(String email) {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      errorText = invalidEmailMessage;
      return false;
    }
    submittedEmail = normalized;
    errorText = null;
    return true;
  }

  bool _isValidEmail(String email) {
    if (email.contains(RegExp(r'\s'))) {
      return false;
    }
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) {
      return false;
    }
    final domainLabels = parts.last.split('.');
    return domainLabels.length >= 2 &&
        domainLabels.every((label) => label.isNotEmpty);
  }
}
