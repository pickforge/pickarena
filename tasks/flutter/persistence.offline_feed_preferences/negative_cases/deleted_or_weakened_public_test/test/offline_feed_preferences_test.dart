import 'package:flutter_test/flutter_test.dart';
import 'package:persistence_offline_feed_preferences/offline_feed_preferences.dart';

void main() {
  test('repository can be constructed', () {
    final repository = OfflineFeedPreferencesRepository(_NullStore());
    expect(repository.store, isNotNull);
  });
}

class _NullStore implements OfflineFeedPreferencesStore {
  @override
  Future<String?> readString(String key) async => null;

  @override
  Future<void> writeString(String key, String value) async {}
}
