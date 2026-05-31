import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_validation_fixture/signup_form.dart';

void main() {
  testWidgets(
    'submit button is disabled until both email and password are valid',
    (tester) async {
      bool submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignupForm(
              onSubmit: ({required String email, required String password}) {
                submitted = true;
              },
            ),
          ),
        ),
      );

      // Both fields empty — button disabled
      final submitFinder = find.byKey(const Key('submit'));
      final button = tester.widget<ElevatedButton>(submitFinder);
      expect(button.onPressed, isNull);

      // Enter invalid email only — still disabled
      await tester.enterText(find.byKey(const Key('email')), 'bad');
      await tester.pump();
      final button2 = tester.widget<ElevatedButton>(submitFinder);
      expect(button2.onPressed, isNull);

      // Enter invalid password only — still disabled
      await tester.enterText(find.byKey(const Key('password')), 'short');
      await tester.pump();
      final button3 = tester.widget<ElevatedButton>(submitFinder);
      expect(button3.onPressed, isNull);

      // Both valid — button enabled
      await tester.enterText(
        find.byKey(const Key('email')),
        'test@example.com',
      );
      await tester.enterText(find.byKey(const Key('password')), 'password123');
      await tester.pump();
      final button4 = tester.widget<ElevatedButton>(submitFinder);
      expect(button4.onPressed, isNotNull);
    },
  );

  testWidgets('invalid email shows "Enter a valid email" error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupForm(
            onSubmit: ({required String email, required String password}) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('email')), 'not-an-email');
    await tester.tap(find.byType(TextFormField).first); // trigger validation
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('empty email shows "Email is required" error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupForm(
            onSubmit: ({required String email, required String password}) {},
          ),
        ),
      ),
    );

    // Enter text to trigger interaction, then clear and unfocus
    final emailFinder = find.byKey(const Key('email'));
    await tester.enterText(emailFinder, 'a');
    await tester.pump();
    await tester.enterText(emailFinder, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('empty password shows "Password is required" error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupForm(
            onSubmit: ({required String email, required String password}) {},
          ),
        ),
      ),
    );

    // Enter text to trigger interaction, then clear and unfocus
    final passwordFinder = find.byKey(const Key('password'));
    await tester.enterText(passwordFinder, 'a');
    await tester.pump();
    await tester.enterText(passwordFinder, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets(
    'password shorter than 8 characters shows "Password must be at least 8 characters"',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignupForm(
              onSubmit: ({required String email, required String password}) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('password')), 'short');
      await tester.tap(find.byType(TextFormField).last); // trigger validation
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping Submit with valid inputs calls onSubmit with the trimmed email and the password',
    (tester) async {
      String? capturedEmail;
      String? capturedPassword;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignupForm(
              onSubmit: ({required String email, required String password}) {
                capturedEmail = email;
                capturedPassword = password;
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('email')),
        '  test@example.com  ',
      );
      await tester.enterText(find.byKey(const Key('password')), 'password123');
      await tester.pump();

      await tester.tap(find.byKey(const Key('submit')));
      await tester.pump();

      expect(capturedEmail, equals('test@example.com'));
      expect(capturedPassword, equals('password123'));
    },
  );
}
