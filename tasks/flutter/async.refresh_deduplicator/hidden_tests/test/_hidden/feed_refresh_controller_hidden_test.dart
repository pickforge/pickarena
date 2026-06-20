import 'dart:async';

import 'package:async_refresh_deduplicator/feed_refresh_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledRepository implements FeedRepository {
  final List<Completer<List<FeedItem>>> calls = <Completer<List<FeedItem>>>[];

  int get callCount => calls.length;

  @override
  Future<List<FeedItem>> fetchFeed() {
    final completer = Completer<List<FeedItem>>();
    calls.add(completer);
    return completer.future;
  }
}

void main() {
  test('duplicate refresh while loading issues exactly one repository call',
      () async {
    final repository = _ControlledRepository();
    final controller = FeedRefreshController(repository);

    final first = controller.refresh();
    final second = controller.refresh();

    expect(repository.callCount, 1);

    repository.calls.single.complete(const [FeedItem('x')]);
    await Future.wait<void>([first, second]);

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('x')]);
  });

  test('forceRefresh starts a newer request while an older one is pending',
      () async {
    final repository = _ControlledRepository();
    final controller = FeedRefreshController(repository);

    final older = controller.refresh();
    final newer = controller.forceRefresh();

    expect(repository.callCount, 2);

    repository.calls[1].complete(const [FeedItem('new')]);
    await newer;

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('new')]);

    repository.calls[0].complete(const [FeedItem('old')]);
    await older;
  });

  test('a stale older success does not overwrite a newer success', () async {
    final repository = _ControlledRepository();
    final controller = FeedRefreshController(repository);

    final older = controller.refresh();
    final newer = controller.forceRefresh();

    repository.calls[1].complete(const [FeedItem('new')]);
    await newer;
    expect(controller.state.items, const [FeedItem('new')]);

    repository.calls[0].complete(const [FeedItem('old')]);
    await older;

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('new')]);
  });

  test('a stale older error does not overwrite a newer success', () async {
    final repository = _ControlledRepository();
    final controller = FeedRefreshController(repository);

    final older = controller.refresh();
    final newer = controller.forceRefresh();

    repository.calls[1].complete(const [FeedItem('new')]);
    await newer;
    expect(controller.state.status, RefreshStatus.success);

    repository.calls[0].completeError(StateError('stale'));
    await older;

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('new')]);
    expect(controller.canRetry, isFalse);
  });

  test('retry from error issues exactly one new call and can reach success',
      () async {
    final repository = _ControlledRepository();
    final controller = FeedRefreshController(repository);

    final first = controller.refresh();
    repository.calls[0].completeError(StateError('boom'));
    await first;

    expect(controller.state.status, RefreshStatus.error);
    expect(repository.callCount, 1);

    final retried = controller.retry();
    expect(repository.callCount, 2);

    repository.calls[1].complete(const [FeedItem('ok')]);
    await retried;

    expect(controller.state.status, RefreshStatus.success);
    expect(controller.state.items, const [FeedItem('ok')]);
  });

  test('canRetry is true only in the error state', () async {
    final repository = _ControlledRepository();
    final controller = FeedRefreshController(repository);

    expect(controller.canRetry, isFalse);

    final loading = controller.refresh();
    expect(controller.state.status, RefreshStatus.loading);
    expect(controller.canRetry, isFalse);

    repository.calls[0].complete(const [FeedItem('y')]);
    await loading;
    expect(controller.canRetry, isFalse);

    final failing = controller.forceRefresh();
    repository.calls[1].completeError(StateError('err'));
    await failing;
    expect(controller.state.status, RefreshStatus.error);
    expect(controller.canRetry, isTrue);

    // retry() is a no-op outside the error state.
    final recover = controller.retry();
    repository.calls[2].complete(const [FeedItem('z')]);
    await recover;
    expect(controller.state.status, RefreshStatus.success);

    final beforeNoop = repository.callCount;
    await controller.retry();
    expect(repository.callCount, beforeNoop);
  });
}
