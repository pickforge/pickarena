class EmailSignUpController {
  static const invalidEmailMessage = 'Enter a valid email';

  String? submittedEmail;
  String? errorText;

  bool submit(String email) {
    final normalized = email.trim().toLowerCase();
    final validEmail = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(normalized);
    if (!validEmail) {
      errorText = invalidEmailMessage;
      return false;
    }
    submittedEmail = normalized;
    errorText = null;
    return true;
  }
}
