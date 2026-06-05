import 'package:flutter_test/flutter_test.dart';
import 'package:forms_email_validation/email_signup_controller.dart';

void main() {
  test('normalizes accepted emails before storing them', () {
    final controller = EmailSignUpController();

    expect(controller.submit('  USER.Name+tag@Example.COM  '), isTrue);
    expect(controller.errorText, isNull);
    expect(controller.submittedEmail, 'user.name+tag@example.com');
  });

  test('rejects malformed emails that only contain an at sign', () {
    for (final email in [
      '@example.com',
      'user@',
      'user@example',
      'user@@example.com',
      'user name@example.com',
    ]) {
      final controller = EmailSignUpController();

      expect(controller.submit(email), isFalse, reason: email);
      expect(
        controller.errorText,
        EmailSignUpController.invalidEmailMessage,
        reason: email,
      );
      expect(controller.submittedEmail, isNull, reason: email);
    }
  });

  test('clears stale error state after a later valid submission', () {
    final controller = EmailSignUpController();

    expect(controller.submit('invalid'), isFalse);
    expect(controller.submit('next@example.com'), isTrue);
    expect(controller.errorText, isNull);
    expect(controller.submittedEmail, 'next@example.com');
  });
}
