enum OfflineFeedSortOrder { newestFirst, oldestFirst, unreadFirst }

enum OfflineFeedFilter { all, unread, saved }

class OfflineFeedPreferences {
  const OfflineFeedPreferences({
    this.sortOrder = OfflineFeedSortOrder.newestFirst,
    this.filter = OfflineFeedFilter.all,
    this.downloadedOnly = false,
  });

  static const defaults = OfflineFeedPreferences();

  final OfflineFeedSortOrder sortOrder;
  final OfflineFeedFilter filter;
  final bool downloadedOnly;

  OfflineFeedPreferences copyWith({
    OfflineFeedSortOrder? sortOrder,
    OfflineFeedFilter? filter,
    bool? downloadedOnly,
  }) {
    return OfflineFeedPreferences(
      sortOrder: sortOrder ?? this.sortOrder,
      filter: filter ?? this.filter,
      downloadedOnly: downloadedOnly ?? this.downloadedOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OfflineFeedPreferences &&
      other.sortOrder == sortOrder &&
      other.filter == filter &&
      other.downloadedOnly == downloadedOnly;

  @override
  int get hashCode => Object.hash(sortOrder, filter, downloadedOnly);
}

abstract class OfflineFeedPreferencesStore {
  Future<String?> readString(String key);
  Future<void> writeString(String key, String value);
}

class OfflineFeedPreferencesRepository {
  OfflineFeedPreferencesRepository(this.store);

  static const sortOrderKey = 'offlineFeed.sortOrder';
  static const filterKey = 'offlineFeed.filter';
  static const downloadedOnlyKey = 'offlineFeed.downloadedOnly';

  final OfflineFeedPreferencesStore store;

  Future<OfflineFeedPreferences> load() async {
    final sortOrderRaw = await store.readString(sortOrderKey);
    final filterRaw = await store.readString(filterKey);
    final downloadedOnlyRaw = await store.readString(downloadedOnlyKey);

    // One broad guard around the whole parse: a single bad field collapses
    // everything back to defaults, discarding valid sibling fields.
    try {
      return OfflineFeedPreferences(
        sortOrder: sortOrderRaw == null
            ? OfflineFeedPreferences.defaults.sortOrder
            : OfflineFeedSortOrder.values.byName(sortOrderRaw),
        filter: filterRaw == null
            ? OfflineFeedPreferences.defaults.filter
            : OfflineFeedFilter.values.byName(filterRaw),
        downloadedOnly: downloadedOnlyRaw == null
            ? OfflineFeedPreferences.defaults.downloadedOnly
            : bool.parse(downloadedOnlyRaw),
      );
    } catch (_) {
      return OfflineFeedPreferences.defaults;
    }
  }

  Future<void> save(OfflineFeedPreferences preferences) async {
    await store.writeString(sortOrderKey, preferences.sortOrder.name);
    await store.writeString(filterKey, preferences.filter.name);
    await store.writeString(
      downloadedOnlyKey,
      preferences.downloadedOnly ? 'true' : 'false',
    );
  }
}
