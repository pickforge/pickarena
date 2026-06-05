class EmailSignUpController {
  static const invalidEmailMessage = 'Enter a valid email';

  String? submittedEmail;
  String? errorText;

  bool submit(String email) {
    if (!email.contains('@')) {
      errorText = invalidEmailMessage;
      return false;
    }
    submittedEmail = email;
    errorText = null;
    return true;
  }
}
