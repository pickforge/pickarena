Fix `AuthRedirectController` so protected deep links are remembered while a user is redirected to `/login`.

Requirements:
- Unauthenticated visits to protected paths must redirect to `/login`.
- The latest protected path must be returned immediately after authentication succeeds.
- Public paths and `/login` must not create redirect loops.
- Preserve the public `AuthRedirectController` API.
