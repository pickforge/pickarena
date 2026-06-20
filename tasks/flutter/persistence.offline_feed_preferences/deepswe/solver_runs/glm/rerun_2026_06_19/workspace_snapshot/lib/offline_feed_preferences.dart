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

  OfflineFeedPreferences? _cached;

  Future<OfflineFeedPreferences> load() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }

    final sortOrderRaw = await store.readString(sortOrderKey);
    final filterRaw = await store.readString(filterKey);
    final downloadedOnlyRaw = await store.readString(downloadedOnlyKey);

    return OfflineFeedPreferences(
      sortOrder: _parseEnum(
        OfflineFeedSortOrder.values,
        sortOrderRaw,
        OfflineFeedPreferences.defaults.sortOrder,
      ),
      filter: _parseEnum(
        OfflineFeedFilter.values,
        filterRaw,
        OfflineFeedPreferences.defaults.filter,
      ),
      downloadedOnly: _parseBool(
        downloadedOnlyRaw,
        OfflineFeedPreferences.defaults.downloadedOnly,
      ),
    );
  }

  Future<void> save(OfflineFeedPreferences preferences) async {
    await store.writeString(sortOrderKey, preferences.sortOrder.name);
    await store.writeString(filterKey, preferences.filter.name);
    await store.writeString(
      downloadedOnlyKey,
      preferences.downloadedOnly ? 'true' : 'false',
    );
    _cached = preferences;
  }

  T _parseEnum<T extends Enum>(List<T> values, String? raw, T fallback) {
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }

  bool _parseBool(String? raw, bool fallback) {
    return raw == 'true'
        ? true
        : raw == 'false'
        ? false
        : fallback;
  }
}
