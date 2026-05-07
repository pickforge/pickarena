import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_validation_fixture/signup_form.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('submit disabled until both fields valid', (tester) async {
    await tester.pumpWidget(
      _wrap(SignupForm(onSubmit: ({required email, required password}) {})),
    );
    final initial = tester.widget<ElevatedButton>(
      find.byKey(const Key('submit')),
    );
    expect(initial.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
    await tester.pump();
    final emailOnly = tester.widget<ElevatedButton>(
      find.byKey(const Key('submit')),
    );
    expect(emailOnly.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('password')), 'longenough');
    await tester.pump();
    final both = tester.widget<ElevatedButton>(find.byKey(const Key('submit')));
    expect(both.onPressed, isNotNull);
  });

  testWidgets('valid submit fires onSubmit with values', (tester) async {
    String? capturedEmail;
    String? capturedPwd;
    await tester.pumpWidget(
      _wrap(
        SignupForm(
          onSubmit: ({required email, required password}) {
            capturedEmail = email;
            capturedPwd = password;
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('password')), 'longenough');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();
    expect(capturedEmail, 'a@b.com');
    expect(capturedPwd, 'longenough');
  });

  testWidgets('invalid email shows error message', (tester) async {
    await tester.pumpWidget(
      _wrap(SignupForm(onSubmit: ({required email, required password}) {})),
    );
    await tester.enterText(find.byKey(const Key('email')), 'nope');
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('short password shows error message', (tester) async {
    await tester.pumpWidget(
      _wrap(SignupForm(onSubmit: ({required email, required password}) {})),
    );
    await tester.enterText(find.byKey(const Key('password')), 'short');
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });
}
