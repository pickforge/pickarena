import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channel_mock/battery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns unknown when the platform returns null', () async {
    const channel = MethodChannel('battery');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await expectLater(BatteryService().label(), completion('Battery unknown'));
  });

  test('returns unknown when the platform throws', () async {
    const channel = MethodChannel('battery');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await expectLater(BatteryService().label(), completion('Battery unknown'));
  });
}
