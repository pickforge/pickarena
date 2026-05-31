import 'dart:async';

typedef Searcher = Future<List<String>> Function(String query);

class SearchController {
  SearchController({required this.search});

  final Searcher search;
  final StreamController<List<String>> _results =
      StreamController<List<String>>.broadcast();

  int _queryId = 0;

  Stream<List<String>> get results => _results.stream;

  void onQueryChanged(String query) {
    final currentId = ++_queryId;
    search(query).then((value) {
      if (currentId != _queryId) return;
      if (_results.isClosed) return;
      _results.add(value);
    });
  }

  Future<void> dispose() async {
    await _results.close();
  }
}
