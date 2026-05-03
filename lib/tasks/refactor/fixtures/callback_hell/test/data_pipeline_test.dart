import 'package:callback_hell_fixture/data_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test('happy path returns aggregated record', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => 'u1',
      fetchUserName: (id) async => 'Alice ($id)',
      fetchOrderIds: (id) async => ['o1', 'o2', 'o3'],
      fetchOrderTotal: (oid) async => 100,
    );
    final r = await pipeline.run();
    expect(r.userId, 'u1');
    expect(r.userName, 'Alice (u1)');
    expect(r.orderCount, 3);
    expect(r.firstOrderId, 'o1');
  });

  test('empty orders returns count 0 and blank firstOrderId', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => 'u2',
      fetchUserName: (_) async => 'Bob',
      fetchOrderIds: (_) async => <String>[],
      fetchOrderTotal: (_) async => fail('should not be called'),
    );
    final r = await pipeline.run();
    expect(r.userId, 'u2');
    expect(r.orderCount, 0);
    expect(r.firstOrderId, '');
  });

  test('error in fetchUserId propagates', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => throw StateError('boom'),
      fetchUserName: (_) async => '',
      fetchOrderIds: (_) async => <String>[],
      fetchOrderTotal: (_) async => 0,
    );
    expect(pipeline.run(), throwsA(isA<StateError>()));
  });

  test('error in fetchOrderTotal propagates', () async {
    final pipeline = DataPipeline(
      fetchUserId: () async => 'u3',
      fetchUserName: (_) async => 'C',
      fetchOrderIds: (_) async => ['o1'],
      fetchOrderTotal: (_) async => throw StateError('total fail'),
    );
    expect(pipeline.run(), throwsA(isA<StateError>()));
  });

  test('calls happen in correct order', () async {
    final calls = <String>[];
    final pipeline = DataPipeline(
      fetchUserId: () async {
        calls.add('id');
        return 'u';
      },
      fetchUserName: (_) async {
        calls.add('name');
        return '';
      },
      fetchOrderIds: (_) async {
        calls.add('orders');
        return ['o1'];
      },
      fetchOrderTotal: (_) async {
        calls.add('total');
        return 0;
      },
    );
    await pipeline.run();
    expect(calls, ['id', 'name', 'orders', 'total']);
  });
}
