class AuthRedirectController {
  static const loginPath = '/login';
  static const homePath = '/home';

  String? _pendingPath;

  String? redirect({required bool isAuthenticated, required String location}) {
    if (!_isProtected(location)) {
      return null;
    }
    if (!isAuthenticated) {
      return loginPath;
    }
    final pending = _pendingPath;
    _pendingPath = null;
    return pending;
  }

  bool _isProtected(String location) {
    return location.startsWith('/account') || location.startsWith('/settings');
  }
}
