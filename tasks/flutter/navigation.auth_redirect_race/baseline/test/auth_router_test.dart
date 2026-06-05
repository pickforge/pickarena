import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_auth_redirect_race/auth_router.dart';

void main() {
  test('redirects unauthenticated protected routes to login', () {
    final controller = AuthRedirectController();

    expect(
      controller.redirect(isAuthenticated: false, location: '/account'),
      AuthRedirectController.loginPath,
    );
  });

  test('does not redirect public routes', () {
    final controller = AuthRedirectController();

    expect(
      controller.redirect(isAuthenticated: false, location: '/about'),
      isNull,
    );
  });
}
