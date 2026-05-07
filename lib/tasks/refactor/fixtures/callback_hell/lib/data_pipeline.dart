import 'dart:async';

typedef Fetcher<T> = Future<T> Function();

class PipelineRecord {
  PipelineRecord({
    required this.userId,
    required this.userName,
    required this.orderCount,
    required this.firstOrderId,
  });
  final String userId;
  final String userName;
  final int orderCount;
  final String firstOrderId;
}

class DataPipeline {
  DataPipeline({
    required this.fetchUserId,
    required this.fetchUserName,
    required this.fetchOrderIds,
    required this.fetchOrderTotal,
  });

  final Fetcher<String> fetchUserId;
  final Future<String> Function(String userId) fetchUserName;
  final Future<List<String>> Function(String userId) fetchOrderIds;
  final Future<int> Function(String orderId) fetchOrderTotal;

  Future<PipelineRecord> run() {
    return fetchUserId().then((userId) {
      return fetchUserName(userId).then((userName) {
        return fetchOrderIds(userId).then((orderIds) {
          if (orderIds.isEmpty) {
            return PipelineRecord(
              userId: userId,
              userName: userName,
              orderCount: 0,
              firstOrderId: '',
            );
          }
          return fetchOrderTotal(orderIds.first).then((_) {
            return PipelineRecord(
              userId: userId,
              userName: userName,
              orderCount: orderIds.length,
              firstOrderId: orderIds.first,
            );
          });
        });
      });
    });
  }
}
