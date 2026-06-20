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

    // Only the values used by the public examples are recognized here.
    return OfflineFeedPreferences(
      sortOrder: sortOrderRaw == 'oldestFirst'
          ? OfflineFeedSortOrder.oldestFirst
          : OfflineFeedPreferences.defaults.sortOrder,
      filter: filterRaw == 'saved'
          ? OfflineFeedFilter.saved
          : OfflineFeedPreferences.defaults.filter,
      downloadedOnly: downloadedOnlyRaw == 'true'
          ? true
          : OfflineFeedPreferences.defaults.downloadedOnly,
    );
  }

  Future<void> save(OfflineFeedPreferences preferences) async {
    _cached = preferences;
  }
}
