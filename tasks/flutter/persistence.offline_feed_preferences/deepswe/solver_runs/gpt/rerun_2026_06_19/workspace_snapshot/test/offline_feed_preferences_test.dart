import 'package:flutter_test/flutter_test.dart';
import 'package:persistence_offline_feed_preferences/offline_feed_preferences.dart';

class _FakeStore implements OfflineFeedPreferencesStore {
  _FakeStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('empty store loads default offline feed preferences', () async {
    final repository = OfflineFeedPreferencesRepository(_FakeStore());

    final loaded = await repository.load();

    expect(loaded, OfflineFeedPreferences.defaults);
  });

  test(
    'save then load on the same repository returns the latest preferences',
    () async {
      final repository = OfflineFeedPreferencesRepository(_FakeStore());

      const preferences = OfflineFeedPreferences(
        sortOrder: OfflineFeedSortOrder.oldestFirst,
        filter: OfflineFeedFilter.saved,
        downloadedOnly: true,
      );
      await repository.save(preferences);

      expect(await repository.load(), preferences);
    },
  );

  test('loads valid preference strings already present in the store', () async {
    final store = _FakeStore({
      OfflineFeedPreferencesRepository.sortOrderKey: 'oldestFirst',
      OfflineFeedPreferencesRepository.filterKey: 'saved',
      OfflineFeedPreferencesRepository.downloadedOnlyKey: 'true',
    });
    final repository = OfflineFeedPreferencesRepository(store);

    final loaded = await repository.load();

    expect(loaded.sortOrder, OfflineFeedSortOrder.oldestFirst);
    expect(loaded.filter, OfflineFeedFilter.saved);
    expect(loaded.downloadedOnly, isTrue);
  });

  test('copyWith and equality preserve value-object behavior', () {
    const base = OfflineFeedPreferences.defaults;

    final updated = base.copyWith(
      filter: OfflineFeedFilter.unread,
      downloadedOnly: true,
    );

    expect(updated.sortOrder, base.sortOrder);
    expect(updated.filter, OfflineFeedFilter.unread);
    expect(updated.downloadedOnly, isTrue);
    expect(updated == base, isFalse);

    final sameAsUpdated = base.copyWith(
      filter: OfflineFeedFilter.unread,
      downloadedOnly: true,
    );
    expect(updated, sameAsUpdated);
    expect(updated.hashCode, sameAsUpdated.hashCode);
  });
}
