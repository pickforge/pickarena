import 'package:flutter_test/flutter_test.dart';
import 'package:persistence_offline_feed_preferences/offline_feed_preferences.dart';

class _MapStore implements OfflineFeedPreferencesStore {
  _MapStore([Map<String, String>? initial]) : entries = {...?initial};

  final Map<String, String> entries;

  @override
  Future<String?> readString(String key) async => entries[key];

  @override
  Future<void> writeString(String key, String value) async {
    entries[key] = value;
  }
}

void main() {
  test(
    'persists saved values through the injected store for a fresh repository',
    () async {
      final store = _MapStore();
      final writer = OfflineFeedPreferencesRepository(store);

      const preferences = OfflineFeedPreferences(
        sortOrder: OfflineFeedSortOrder.unreadFirst,
        filter: OfflineFeedFilter.unread,
        downloadedOnly: true,
      );
      await writer.save(preferences);

      expect(
        store.entries[OfflineFeedPreferencesRepository.sortOrderKey],
        'unreadFirst',
      );
      expect(
        store.entries[OfflineFeedPreferencesRepository.filterKey],
        'unread',
      );
      expect(
        store.entries[OfflineFeedPreferencesRepository.downloadedOnlyKey],
        'true',
      );

      final reader = OfflineFeedPreferencesRepository(store);
      expect(await reader.load(), preferences);
    },
  );

  test('latest save wins across repository instances', () async {
    final store = _MapStore();
    final writer = OfflineFeedPreferencesRepository(store);

    await writer.save(
      const OfflineFeedPreferences(
        sortOrder: OfflineFeedSortOrder.oldestFirst,
        filter: OfflineFeedFilter.saved,
        downloadedOnly: true,
      ),
    );

    const latest = OfflineFeedPreferences(
      sortOrder: OfflineFeedSortOrder.newestFirst,
      filter: OfflineFeedFilter.unread,
      downloadedOnly: false,
    );
    await writer.save(latest);

    expect(
      store.entries[OfflineFeedPreferencesRepository.sortOrderKey],
      'newestFirst',
    );
    expect(store.entries[OfflineFeedPreferencesRepository.filterKey], 'unread');
    expect(
      store.entries[OfflineFeedPreferencesRepository.downloadedOnlyKey],
      'false',
    );

    final reader = OfflineFeedPreferencesRepository(store);
    expect(await reader.load(), latest);
  });

  test(
    'unknown stored values fall back to defaults without throwing',
    () async {
      final store = _MapStore({
        OfflineFeedPreferencesRepository.sortOrderKey: 'priorityFirst',
        OfflineFeedPreferencesRepository.filterKey: 'archivedOnly',
        OfflineFeedPreferencesRepository.downloadedOnlyKey: 'sometimes',
      });
      final repository = OfflineFeedPreferencesRepository(store);

      final loaded = await repository.load();

      expect(loaded, OfflineFeedPreferences.defaults);
    },
  );

  test('partial corruption defaults only the bad field', () async {
    final store = _MapStore({
      OfflineFeedPreferencesRepository.sortOrderKey: 'unreadFirst',
      OfflineFeedPreferencesRepository.filterKey: 'archivedOnly',
      OfflineFeedPreferencesRepository.downloadedOnlyKey: 'true',
    });
    final repository = OfflineFeedPreferencesRepository(store);

    final loaded = await repository.load();

    expect(loaded.sortOrder, OfflineFeedSortOrder.unreadFirst);
    expect(loaded.filter, OfflineFeedFilter.all);
    expect(loaded.downloadedOnly, isTrue);
  });

  test('valid hidden seeded values still load', () async {
    final store = _MapStore({
      OfflineFeedPreferencesRepository.sortOrderKey: 'unreadFirst',
      OfflineFeedPreferencesRepository.filterKey: 'unread',
      OfflineFeedPreferencesRepository.downloadedOnlyKey: 'false',
    });
    final repository = OfflineFeedPreferencesRepository(store);

    final loaded = await repository.load();

    expect(loaded.sortOrder, OfflineFeedSortOrder.unreadFirst);
    expect(loaded.filter, OfflineFeedFilter.unread);
    expect(loaded.downloadedOnly, isFalse);
  });

  test('repositories are isolated by their injected stores', () async {
    final storeOne = _MapStore({
      OfflineFeedPreferencesRepository.sortOrderKey: 'oldestFirst',
      OfflineFeedPreferencesRepository.filterKey: 'saved',
      OfflineFeedPreferencesRepository.downloadedOnlyKey: 'true',
    });
    final storeTwo = _MapStore({
      OfflineFeedPreferencesRepository.sortOrderKey: 'newestFirst',
      OfflineFeedPreferencesRepository.filterKey: 'unread',
      OfflineFeedPreferencesRepository.downloadedOnlyKey: 'false',
    });

    final repositoryOne = OfflineFeedPreferencesRepository(storeOne);
    final repositoryTwo = OfflineFeedPreferencesRepository(storeTwo);

    final loadedOne = await repositoryOne.load();
    final loadedTwo = await repositoryTwo.load();

    expect(loadedOne.sortOrder, OfflineFeedSortOrder.oldestFirst);
    expect(loadedOne.filter, OfflineFeedFilter.saved);
    expect(loadedOne.downloadedOnly, isTrue);

    expect(loadedTwo.sortOrder, OfflineFeedSortOrder.newestFirst);
    expect(loadedTwo.filter, OfflineFeedFilter.unread);
    expect(loadedTwo.downloadedOnly, isFalse);

    expect(loadedOne == loadedTwo, isFalse);

    await repositoryOne.save(
      const OfflineFeedPreferences(
        sortOrder: OfflineFeedSortOrder.unreadFirst,
        filter: OfflineFeedFilter.unread,
        downloadedOnly: false,
      ),
    );

    final reloadedTwo = await OfflineFeedPreferencesRepository(storeTwo).load();
    expect(reloadedTwo, loadedTwo);
  });
}
