import 'package:async_refresh_deduplicator/feed_refresh_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller can be constructed', () {
    final controller = FeedRefreshController(_NullRepository());
    expect(controller.state.status, RefreshStatus.idle);
  });
}

class _NullRepository implements FeedRepository {
  @override
  Future<List<FeedItem>> fetchFeed() async => const <FeedItem>[];
}
