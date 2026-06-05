import 'package:flutter/services.dart';

class BatteryService {
  BatteryService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('battery');

  final MethodChannel _channel;

  Future<String> label() async {
    final level = await _channel.invokeMethod<int>('getBatteryLevel');
    return 'Battery: ${level ?? 0}%';
  }
}
