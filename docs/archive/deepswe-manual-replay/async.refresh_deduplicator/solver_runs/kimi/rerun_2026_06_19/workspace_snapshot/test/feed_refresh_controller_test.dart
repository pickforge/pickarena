import 'dart:async';

import 'package:async_refresh_deduplicator/feed_refresh_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueuedRepository implements FeedRepository {
  final List<Completer<List<FeedItem>>> pending = <Completer<List<FeedItem>>>[];

  @override
  Future<List<FeedItem>> fetchFeed() {
    final completer = Completer<List<FeedItem>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  test('single refresh goes loading then success and stores items', () async {
    final repository = _QueuedRepository();
    final controller = FeedRefreshController(repository);

    final future = controller.refresh();
    expect(controller.state.status, RefreshStatus.loading);
    expect(controller.isLoading, isTrue);

    repository.pending.single.complete(const [FeedItem('a'), FeedItem('b')]);
    await future;

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('a'), FeedItem('b')]);
    expect(controller.canRetry, isFalse);
    expect(controller.isLoading, isFalse);
  });

  test('error enables retry and retry can reach success', () async {
    final repository = _QueuedRepository();
    final controller = FeedRefreshController(repository);

    final firstFuture = controller.refresh();
    repository.pending.single.completeError(StateError('boom'));
    await firstFuture;

    expect(controller.state.status, RefreshStatus.error);
    expect(controller.canRetry, isTrue);
    expect(controller.isLoading, isFalse);

    final retryFuture = controller.retry();
    repository.pending.last.complete(const [FeedItem('c')]);
    await retryFuture;

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('c')]);
    expect(controller.canRetry, isFalse);
  });
}
