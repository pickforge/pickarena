import 'dart:async';

class FeedItem {
  const FeedItem(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is FeedItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum RefreshStatus { idle, loading, success, error }

class RefreshState {
  const RefreshState({
    required this.status,
    this.items = const <FeedItem>[],
    this.error,
  });

  final RefreshStatus status;
  final List<FeedItem> items;
  final Object? error;
}

abstract class FeedRepository {
  Future<List<FeedItem>> fetchFeed();
}

class FeedRefreshController {
  FeedRefreshController(this._repository);

  final FeedRepository _repository;

  RefreshState _state = const RefreshState(status: RefreshStatus.idle);
  int _latestRequestId = 0;
  int _inFlightCount = 0;
  Completer<void>? _idleCompleter;

  RefreshState get state => _state;

  bool get canRetry => _state.status == RefreshStatus.error;

  bool get isLoading => _inFlightCount > 0;

  Future<void> refresh() {
    if (isLoading) {
      return _idleCompleter?.future ?? Future<void>.value();
    }

    return _load();
  }

  Future<void> forceRefresh() => _load();

  Future<void> retry() {
    if (!canRetry) {
      return Future<void>.value();
    }

    return _load();
  }

  Future<void> _load() async {
    final requestId = ++_latestRequestId;
    _inFlightCount += 1;
    _idleCompleter ??= Completer<void>();
    _state = const RefreshState(status: RefreshStatus.loading);

    try {
      final items = await _repository.fetchFeed();
      if (requestId == _latestRequestId) {
        _state = RefreshState(status: RefreshStatus.success, items: items);
      }
    } catch (error) {
      if (requestId == _latestRequestId) {
        _state = RefreshState(status: RefreshStatus.error, error: error);
      }
    } finally {
      _inFlightCount -= 1;
      if (_inFlightCount == 0) {
        _idleCompleter?.complete();
        _idleCompleter = null;
      }
    }
  }
}
