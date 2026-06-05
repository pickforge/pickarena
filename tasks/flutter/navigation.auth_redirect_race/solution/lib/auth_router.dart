class AuthRedirectController {
  static const loginPath = '/login';
  static const homePath = '/home';

  String? _pendingPath;

  String? redirect({required bool isAuthenticated, required String location}) {
    if (!isAuthenticated) {
      if (_isProtected(location)) {
        _pendingPath = location;
        return loginPath;
      }
      return null;
    }

    if (location == loginPath) {
      final pending = _pendingPath;
      _pendingPath = null;
      return pending;
    }

    return null;
  }

  bool _isProtected(String location) {
    return location.startsWith('/account') || location.startsWith('/settings');
  }
}
