Fix `BatteryService` so platform-channel battery reads are safe and testable.

Requirements:
- Preserve `BatteryService.label()`.
- Return `Battery: <level>%` when the platform returns an integer level.
- Return `Battery unknown` when the platform returns null or throws a `PlatformException`.
- Keep method-channel access injectable for tests.
