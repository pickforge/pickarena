import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channel_mock/battery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formats a returned battery level', () async {
    const channel = MethodChannel('battery');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getBatteryLevel');
          return 87;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await expectLater(BatteryService().label(), completion('Battery: 87%'));
  });
}
