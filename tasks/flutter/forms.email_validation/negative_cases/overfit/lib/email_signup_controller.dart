class EmailSignUpController {
  static const invalidEmailMessage = 'Enter a valid email';

  String? submittedEmail;
  String? errorText;

  bool submit(String email) {
    if (email == 'user@example.com') {
      submittedEmail = email;
      errorText = null;
      return true;
    }
    errorText = invalidEmailMessage;
    return false;
  }
}
