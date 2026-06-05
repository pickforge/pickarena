import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_auth_redirect_race/auth_router.dart';

void main() {
  test('returns the latest protected deep link after login succeeds', () {
    final controller = AuthRedirectController();

    expect(
      controller.redirect(isAuthenticated: false, location: '/account'),
      AuthRedirectController.loginPath,
    );
    expect(
      controller.redirect(isAuthenticated: false, location: '/settings/profile'),
      AuthRedirectController.loginPath,
    );
    expect(
      controller.redirect(isAuthenticated: true, location: '/login'),
      '/settings/profile',
    );
    expect(
      controller.redirect(isAuthenticated: true, location: '/login'),
      isNull,
    );
  });

  test('public and login paths do not create redirect loops', () {
    final controller = AuthRedirectController();

    expect(
      controller.redirect(isAuthenticated: false, location: '/login'),
      isNull,
    );
    expect(
      controller.redirect(isAuthenticated: true, location: '/home'),
      isNull,
    );
  });
}
