import 'package:flutter/services.dart';

class BatteryService {
  BatteryService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('battery');

  final MethodChannel _channel;

  Future<String> label() async {
    try {
      final level = await _channel.invokeMethod<int>('getBatteryLevel');
      if (level == null) return 'Battery unknown';
      return 'Battery: $level%';
    } on PlatformException {
      return 'Battery unknown';
    }
  }
}
