import 'package:flutter_test/flutter_test.dart';
import 'package:forms_email_validation/email_signup_controller.dart';

void main() {
  test('rejects a blank email', () {
    final controller = EmailSignUpController();

    expect(controller.submit(''), isFalse);
    expect(controller.errorText, EmailSignUpController.invalidEmailMessage);
    expect(controller.submittedEmail, isNull);
  });

  test('accepts a simple valid email', () {
    final controller = EmailSignUpController();

    expect(controller.submit('user@example.com'), isTrue);
    expect(controller.errorText, isNull);
    expect(controller.submittedEmail, 'user@example.com');
  });
}
