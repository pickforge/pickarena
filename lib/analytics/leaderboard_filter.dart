import 'package:dart_arena/analytics/dimensions.dart';
import 'package:dart_arena/core/category.dart';
import 'package:equatable/equatable.dart';

class DateRange extends Equatable {
  const DateRange._({_Kind kind = _Kind.allTime, this.from, this.to})
      : _kind = kind;
  final _Kind _kind;
  final DateTime? from;
  final DateTime? to;

  static const DateRange allTime = DateRange._();
  static const DateRange last7d = DateRange._(kind: _Kind.last7d);
  static const DateRange last30d = DateRange._(kind: _Kind.last30d);

  factory DateRange.custom({required DateTime from, required DateTime to}) =>
      DateRange._(kind: _Kind.custom, from: from, to: to);

  bool get isCustom => _kind == _Kind.custom;

  DateTime? fromForNow(DateTime now) => switch (_kind) {
        _Kind.allTime => null,
        _Kind.last7d => now.subtract(const Duration(days: 7)),
        _Kind.last30d => now.subtract(const Duration(days: 30)),
        _Kind.custom => from,
      };

  DateTime? toForNow(DateTime now) => switch (_kind) {
        _Kind.allTime => null,
        _Kind.last7d => now,
        _Kind.last30d => now,
        _Kind.custom => to,
      };

  String toQueryParam() => switch (_kind) {
        _Kind.allTime => 'all',
        _Kind.last7d => '7d',
        _Kind.last30d => '30d',
        _Kind.custom => '${from!.toIso8601String()}..${to!.toIso8601String()}',
      };

  static DateRange fromQueryParam(String? raw) {
    if (raw == null || raw == 'all') return DateRange.allTime;
    if (raw == '7d') return DateRange.last7d;
    if (raw == '30d') return DateRange.last30d;
    final parts = raw.split('..');
    if (parts.length == 2) {
      final f = DateTime.tryParse(parts[0]);
      final t = DateTime.tryParse(parts[1]);
      if (f != null && t != null) return DateRange.custom(from: f, to: t);
    }
    return DateRange.allTime;
  }

  @override
  List<Object?> get props => [_kind, from, to];
}

enum _Kind { allTime, last7d, last30d, custom }

class LeaderboardFilter extends Equatable {
  const LeaderboardFilter({
    this.category,
    this.providerId,
    this.dateRange = DateRange.allTime,
    this.dimension = ScoreDimension.overall,
  });

  final Category? category;
  final String? providerId;
  final DateRange dateRange;
  final ScoreDimension dimension;

  LeaderboardFilter copyWith({
    Category? category,
    bool clearCategory = false,
    String? providerId,
    bool clearProviderId = false,
    DateRange? dateRange,
    ScoreDimension? dimension,
  }) =>
      LeaderboardFilter(
        category: clearCategory ? null : (category ?? this.category),
        providerId: clearProviderId ? null : (providerId ?? this.providerId),
        dateRange: dateRange ?? this.dateRange,
        dimension: dimension ?? this.dimension,
      );

  @override
  List<Object?> get props => [category, providerId, dateRange, dimension];
}
