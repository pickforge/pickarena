class AuthRedirectController {
  static const loginPath = '/login';
  static const homePath = '/home';

  String? redirect({required bool isAuthenticated, required String location}) {
    if (location.startsWith('/account') || location.startsWith('/settings')) {
      return isAuthenticated ? null : loginPath;
    }
    return null;
  }
}
