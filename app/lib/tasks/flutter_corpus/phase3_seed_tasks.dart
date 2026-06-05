import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class Phase3SeedTaskIds {
  static const all = [
    'state.bloc_debounce_cancellation',
    'state.riverpod_stale_cache',
    'ui.responsive_profile_golden',
    'ui.localization_rtl_behavior',
    'testing.flaky_widget_test_repair',
    'performance.rebuild_reduction',
    'navigation.go_router_auth_redirect',
    'build.codegen_model_migration',
    'platform.platform_channel_mock',
    'refactor.large_screen_preserve_behavior',
  ];
}

List<BenchmarkTask> buildPhase3SeedTasks() => [
  BlocDebounceCancellationTask(),
  RiverpodStaleCacheTask(),
  ResponsiveProfileGoldenTask(),
  LocalizationRtlBehaviorTask(),
  FlakyWidgetTestRepairTask(),
  RebuildReductionTask(),
  GoRouterAuthRedirectTask(),
  CodegenModelMigrationTask(),
  PlatformChannelMockTask(),
  LargeScreenPreserveBehaviorTask(),
];

abstract class _Phase3SeedTask extends BenchmarkTask {
  _Phase3SeedTask(this._taskSpec);

  final _Phase3TaskSpec _taskSpec;

  @override
  String get id => _taskSpec.id;

  @override
  int get version => 1;

  @override
  Category get category => _taskSpec.category;

  @override
  BenchmarkTrack get track => _taskSpec.track;

  @override
  Set<TaskTag> get tags => _taskSpec.tags;

  @override
  TaskDifficulty get difficulty => _taskSpec.difficulty;

  @override
  Duration? get timeout => _taskSpec.timeout;

  @override
  Set<TaskPlatform> get platformRequirements => _taskSpec.platformRequirements;

  @override
  bool get isFlutter => _taskSpec.isFlutter;

  @override
  String get prompt => _taskSpec.prompt;

  @override
  Map<String, String> get fixtures => _taskSpec.fixtures;

  @override
  String get generatedCodePath => _taskSpec.generatedCodePath;

  @override
  List<VerifierFixture> get hiddenVerifiers => [
    VerifierFixture(
      id: '${id.replaceAll('.', '_')}_hidden',
      files: {_taskSpec.hiddenTestPath: _taskSpec.hiddenTest},
      testPath: _taskSpec.hiddenTestPath,
    ),
  ];

  @override
  ReferenceSolution get referenceSolution =>
      ReferenceFileSolution(_taskSpec.referenceFiles);

  @override
  List<TaskNegativeCase> get negativeCases => [
    const TaskNegativeCase(
      id: 'noop',
      description: 'Leaves the baseline implementation unchanged.',
      kind: TaskNegativeCaseKind.noop,
      solution: ReferenceFileSolution({}),
    ),
    TaskNegativeCase(
      id: 'api_breaking',
      description: 'Replaces the target file with invalid Dart code.',
      kind: TaskNegativeCaseKind.apiBreaking,
      solution: ReferenceFileSolution({
        generatedCodePath: 'void apiBreakingSolution() {\n',
      }),
    ),
    TaskNegativeCase(
      id: 'overfit_public_surface',
      description: 'Satisfies visible coverage while missing hidden behavior.',
      kind: TaskNegativeCaseKind.overfit,
      solution: ReferenceFileSolution(_taskSpec.overfitFiles ?? const {}),
    ),
  ];

  @override
  Set<TaskNegativeCaseKind> get requiredNegativeCaseKinds => const {
    TaskNegativeCaseKind.noop,
    TaskNegativeCaseKind.apiBreaking,
    TaskNegativeCaseKind.overfit,
  };

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    CompileEvaluator(),
    AnalyzeEvaluator(),
    TestEvaluator(),
    ...hiddenVerifiers.map(HiddenTestEvaluator.new),
  ];
}

class _Phase3TaskSpec {
  const _Phase3TaskSpec({
    required this.id,
    required this.category,
    required this.track,
    required this.tags,
    required this.difficulty,
    required this.timeout,
    this.platformRequirements = const {},
    required this.isFlutter,
    required this.prompt,
    required this.generatedCodePath,
    required this.fixtures,
    required this.hiddenTestPath,
    required this.hiddenTest,
    required this.referenceFiles,
    this.overfitFiles,
  });

  final String id;
  final Category category;
  final BenchmarkTrack track;
  final Set<TaskTag> tags;
  final TaskDifficulty difficulty;
  final Duration timeout;
  final Set<TaskPlatform> platformRequirements;
  final bool isFlutter;
  final String prompt;
  final String generatedCodePath;
  final Map<String, String> fixtures;
  final String hiddenTestPath;
  final String hiddenTest;
  final Map<String, String> referenceFiles;
  final Map<String, String>? overfitFiles;
}

class BlocDebounceCancellationTask extends _Phase3SeedTask {
  BlocDebounceCancellationTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'state.bloc_debounce_cancellation',
    category: Category.stateManagement,
    track: BenchmarkTrack.codegen,
    tags: const {TaskTag.stateBloc, TaskTag.bugfix},
    difficulty: TaskDifficulty.medium,
    timeout: const Duration(minutes: 6),
    isFlutter: false,
    generatedCodePath: 'lib/search_bloc.dart',
    prompt: '''
You are given a small Dart package with a search BLoC in `lib/search_bloc.dart`.

The BLoC debounces query events, but stale in-flight searches can still overwrite fresher results. Fix it so only the latest debounced query may emit loading/results states after overlapping async calls complete.

Constraints:
- Preserve the public API.
- Keep debouncing behavior.
- Do not busy-wait or add sleeps.

Return ONLY the corrected contents of `lib/search_bloc.dart` inside a single ```dart fenced block.
''',
    fixtures: {
      'pubspec.yaml': _dartPubspec('phase3_bloc_debounce'),
      'lib/search_bloc.dart': _blocBaseline,
      'test/search_bloc_test.dart': _blocPublicTest,
    },
    hiddenTestPath: 'test/_hidden/search_bloc_hidden_test.dart',
    hiddenTest: _blocHiddenTest,
    referenceFiles: {'lib/search_bloc.dart': _blocReference},
  );
}

class RiverpodStaleCacheTask extends _Phase3SeedTask {
  RiverpodStaleCacheTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'state.riverpod_stale_cache',
    category: Category.stateManagement,
    track: BenchmarkTrack.codegen,
    tags: const {TaskTag.stateRiverpod, TaskTag.bugfix},
    difficulty: TaskDifficulty.medium,
    timeout: const Duration(minutes: 6),
    isFlutter: false,
    generatedCodePath: 'lib/article_providers.dart',
    prompt: '''
You are given `lib/article_providers.dart`, a Riverpod-style async cache used by Flutter widgets.

`ArticleListNotifier.toggleFavorite` writes through to the repository but leaves the cached list stale. Fix the notifier so subsequent loads and the exposed state reflect the updated article without requiring a forced refresh.

Constraints:
- Preserve all public types and method signatures.
- Keep cached reads fast when no mutation happened.
- Do not fetch the entire list again after every toggle.

Return ONLY the corrected contents of `lib/article_providers.dart` inside a single ```dart fenced block.
''',
    fixtures: {
      'pubspec.yaml': _dartPubspec('phase3_riverpod_stale_cache'),
      'lib/article_providers.dart': _riverpodBaseline,
      'test/article_providers_test.dart': _riverpodPublicTest,
    },
    hiddenTestPath: 'test/_hidden/article_providers_hidden_test.dart',
    hiddenTest: _riverpodHiddenTest,
    referenceFiles: {'lib/article_providers.dart': _riverpodReference},
  );
}

class ResponsiveProfileGoldenTask extends _Phase3SeedTask {
  ResponsiveProfileGoldenTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'ui.responsive_profile_golden',
    category: Category.uiFromSpec,
    track: BenchmarkTrack.codegen,
    tags: const {TaskTag.ui, TaskTag.golden, TaskTag.accessibility},
    difficulty: TaskDifficulty.medium,
    timeout: const Duration(minutes: 8),
    isFlutter: true,
    generatedCodePath: 'lib/profile_screen.dart',
    prompt: '''
You are given `lib/profile_screen.dart`, a Flutter profile screen that only works at one size.

Make it responsive:
- At narrow widths, stack the avatar, text, and stat cards vertically.
- At wide widths, place profile identity and stats side by side.
- Keep the name, handle, headline, and all stat labels visible.
- Add a useful semantics label for the profile.

Return ONLY the corrected contents of `lib/profile_screen.dart` inside a single ```dart fenced block.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec('phase3_responsive_profile'),
      'lib/profile_screen.dart': _profileBaseline,
      'test/profile_screen_test.dart': _profilePublicTest,
    },
    hiddenTestPath: 'test/_hidden/profile_screen_hidden_test.dart',
    hiddenTest: _profileHiddenTest,
    referenceFiles: {'lib/profile_screen.dart': _profileReference},
  );
}

class LocalizationRtlBehaviorTask extends _Phase3SeedTask {
  LocalizationRtlBehaviorTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'ui.localization_rtl_behavior',
    category: Category.uiFromSpec,
    track: BenchmarkTrack.codegen,
    tags: const {TaskTag.ui, TaskTag.localization, TaskTag.accessibility},
    difficulty: TaskDifficulty.medium,
    timeout: const Duration(minutes: 8),
    isFlutter: true,
    generatedCodePath: 'lib/greeting_banner.dart',
    prompt: '''
You are given `lib/greeting_banner.dart`, a localized Flutter banner.

Fix the widget so English, Spanish, and Arabic greetings render correctly. Arabic must use RTL directionality, mirrored chevron direction, and a localized semantics label.

Constraints:
- Preserve the public constructor.
- Do not add generated localization files.
- Keep the widget deterministic for tests.

Return ONLY the corrected contents of `lib/greeting_banner.dart` inside a single ```dart fenced block.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec('phase3_localization_rtl'),
      'lib/greeting_banner.dart': _localizationBaseline,
      'test/greeting_banner_test.dart': _localizationPublicTest,
    },
    hiddenTestPath: 'test/_hidden/greeting_banner_hidden_test.dart',
    hiddenTest: _localizationHiddenTest,
    referenceFiles: {'lib/greeting_banner.dart': _localizationReference},
  );
}

class FlakyWidgetTestRepairTask extends _Phase3SeedTask {
  FlakyWidgetTestRepairTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'testing.flaky_widget_test_repair',
    category: Category.widgetTesting,
    track: BenchmarkTrack.codegen,
    tags: const {TaskTag.testing, TaskTag.bugfix},
    difficulty: TaskDifficulty.easy,
    timeout: const Duration(minutes: 6),
    isFlutter: true,
    generatedCodePath: 'test/countdown_banner_test.dart',
    prompt: '''
You are given a Flutter widget and a flaky widget test in `test/countdown_banner_test.dart`.

Repair the test so it advances Flutter fake time deterministically instead of waiting on wall-clock time. The test should still verify that `CountdownBanner` changes from the initial countdown text to `Done`.

Return ONLY the corrected contents of `test/countdown_banner_test.dart` inside a single ```dart fenced block.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec('phase3_flaky_widget_test'),
      'lib/countdown_banner.dart': _countdownWidget,
      'test/countdown_banner_test.dart': _countdownBaselineTest,
    },
    hiddenTestPath: 'test/_hidden/countdown_banner_hidden_test.dart',
    hiddenTest: _countdownHiddenTest,
    referenceFiles: {
      'test/countdown_banner_test.dart': _countdownReferenceTest,
    },
    overfitFiles: {'test/countdown_banner_test.dart': _countdownOverfitTest},
  );
}

class RebuildReductionTask extends _Phase3SeedTask {
  RebuildReductionTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'performance.rebuild_reduction',
    category: Category.refactor,
    track: BenchmarkTrack.codegen,
    tags: const {TaskTag.performance, TaskTag.ui, TaskTag.refactor},
    difficulty: TaskDifficulty.hard,
    timeout: const Duration(minutes: 8),
    isFlutter: true,
    generatedCodePath: 'lib/message_list.dart',
    prompt: '''
You are given `lib/message_list.dart`, a Flutter message list.

Selecting one row currently rebuilds every row. Refactor the selection state so only rows whose selected state changes rebuild, while preserving the visible selection behavior and public widget API.

Return ONLY the corrected contents of `lib/message_list.dart` inside a single ```dart fenced block.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec('phase3_rebuild_reduction'),
      'lib/message_list.dart': _rebuildBaseline,
      'test/message_list_test.dart': _rebuildPublicTest,
    },
    hiddenTestPath: 'test/_hidden/message_list_hidden_test.dart',
    hiddenTest: _rebuildHiddenTest,
    referenceFiles: {'lib/message_list.dart': _rebuildReference},
  );
}

class GoRouterAuthRedirectTask extends _Phase3SeedTask {
  GoRouterAuthRedirectTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'navigation.go_router_auth_redirect',
    category: Category.bugFix,
    track: BenchmarkTrack.agentic,
    tags: const {TaskTag.navigation, TaskTag.bugfix},
    difficulty: TaskDifficulty.hard,
    timeout: const Duration(minutes: 12),
    isFlutter: true,
    generatedCodePath: 'lib/app_router.dart',
    prompt: '''
You are working in a small Flutter package that uses `go_router`.

Unauthenticated users can open `/dashboard`, and signed-in users can remain on `/login`. Add auth-aware redirects so:
- anonymous users visiting `/dashboard` see the login page;
- signing in refreshes routing and lands on the dashboard;
- signed-in users visiting `/login` are redirected to the dashboard.

Edit workspace files as needed and leave the package ready for `flutter test`.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec(
        'phase3_go_router_auth',
        dependencies: {'go_router': '^14.6.2'},
      ),
      'lib/auth_state.dart': _routerAuthState,
      'lib/app_router.dart': _routerBaseline,
      'test/router_smoke_test.dart': _routerPublicTest,
    },
    hiddenTestPath: 'test/_hidden/router_auth_hidden_test.dart',
    hiddenTest: _routerHiddenTest,
    referenceFiles: {'lib/app_router.dart': _routerReference},
  );
}

class CodegenModelMigrationTask extends _Phase3SeedTask {
  CodegenModelMigrationTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'build.codegen_model_migration',
    category: Category.refactor,
    track: BenchmarkTrack.agentic,
    tags: const {TaskTag.buildCodegen, TaskTag.refactor},
    difficulty: TaskDifficulty.hard,
    timeout: const Duration(minutes: 12),
    isFlutter: false,
    generatedCodePath: 'lib/user_model.dart',
    prompt: '''
You are working in a Dart package with a generated JSON model.

Migrate `User` to include a `role` field that defaults to `viewer` when missing from JSON. Update the json_serializable source model, run `dart run build_runner build`, and include the generated `lib/user_model.g.dart` output.

Edit workspace files as needed and leave the package ready for `dart test`.
''',
    fixtures: {
      'pubspec.yaml': _codegenModelPubspec(),
      'lib/user_model.dart': _modelBaseline,
      'lib/user_model.g.dart': _modelGeneratedBaseline,
      'test/user_model_test.dart': _modelPublicTest,
    },
    hiddenTestPath: 'test/_hidden/user_model_hidden_test.dart',
    hiddenTest: _modelHiddenTest,
    referenceFiles: {
      'lib/user_model.dart': _modelReference,
      'lib/user_model.g.dart': _modelGeneratedReference,
    },
  );
}

class PlatformChannelMockTask extends _Phase3SeedTask {
  PlatformChannelMockTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'platform.platform_channel_mock',
    category: Category.bugFix,
    track: BenchmarkTrack.agentic,
    tags: const {TaskTag.platform, TaskTag.testing, TaskTag.bugfix},
    difficulty: TaskDifficulty.medium,
    timeout: const Duration(minutes: 10),
    isFlutter: true,
    generatedCodePath: 'lib/battery_service.dart',
    prompt: '''
You are working in a Flutter package with a platform-channel wrapper in `lib/battery_service.dart`.

The public mock test covers a successful host response, but production code must also handle missing or failing platform implementations. Fix `BatteryService.batteryLevel` so it returns `-1` when the channel throws `PlatformException` or returns no value.

Edit workspace files as needed and leave the package ready for `flutter test`.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec('phase3_platform_channel_mock'),
      'lib/battery_service.dart': _platformBaseline,
      'test/battery_service_test.dart': _platformPublicTest,
    },
    hiddenTestPath: 'test/_hidden/battery_service_hidden_test.dart',
    hiddenTest: _platformHiddenTest,
    referenceFiles: {'lib/battery_service.dart': _platformReference},
  );
}

class LargeScreenPreserveBehaviorTask extends _Phase3SeedTask {
  LargeScreenPreserveBehaviorTask() : super(_spec);

  static final _spec = _Phase3TaskSpec(
    id: 'refactor.large_screen_preserve_behavior',
    category: Category.refactor,
    track: BenchmarkTrack.agentic,
    tags: const {TaskTag.refactor, TaskTag.ui},
    difficulty: TaskDifficulty.hard,
    timeout: const Duration(minutes: 12),
    isFlutter: true,
    generatedCodePath: 'lib/settings_screen.dart',
    prompt: '''
You are working in a Flutter package with a large settings screen.

Refactor `SettingsScreen` so wide layouts use two panes while narrow layouts keep the current single-column behavior. Preserve all existing toggle behavior and public API.

Edit workspace files as needed and leave the package ready for `flutter test`.
''',
    fixtures: {
      'pubspec.yaml': _flutterPubspec('phase3_large_screen_refactor'),
      'lib/settings_screen.dart': _settingsBaseline,
      'test/settings_screen_test.dart': _settingsPublicTest,
    },
    hiddenTestPath: 'test/_hidden/settings_screen_hidden_test.dart',
    hiddenTest: _settingsHiddenTest,
    referenceFiles: {'lib/settings_screen.dart': _settingsReference},
  );
}

String _dartPubspec(String name) =>
    '''
name: $name
publish_to: none
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''';

String _codegenModelPubspec() => '''
name: phase3_codegen_model_migration
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  json_annotation: ^4.12.0
dev_dependencies:
  build_runner: ^2.4.13
  json_serializable: ^6.9.0
  test: ^1.25.0
''';

String _flutterPubspec(
  String name, {
  Map<String, String> dependencies = const {},
}) {
  final buffer = StringBuffer('''
name: $name
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''');
  for (final entry in dependencies.entries) {
    buffer.writeln('  ${entry.key}: ${entry.value}');
  }
  buffer.write('''
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''');
  return buffer.toString();
}

const _blocBaseline = r'''
import 'dart:async';

typedef SearchApi = Future<List<String>> Function(String query);

class SearchEvent {
  const SearchEvent(this.query);
  final String query;
}

class SearchState {
  const SearchState({
    required this.query,
    required this.isLoading,
    required this.results,
  });

  factory SearchState.initial() =>
      const SearchState(query: '', isLoading: false, results: []);

  final String query;
  final bool isLoading;
  final List<String> results;
}

class SearchBloc {
  SearchBloc({required SearchApi search, this.debounce = const Duration(milliseconds: 300)})
      : _search = search,
        _state = SearchState.initial();

  final SearchApi _search;
  final Duration debounce;
  final _controller = StreamController<SearchState>.broadcast();
  Timer? _debounceTimer;
  SearchState _state;

  SearchState get state => _state;
  Stream<SearchState> get stream => _controller.stream;

  void add(SearchEvent event) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      _emit(SearchState(query: event.query, isLoading: true, results: _state.results));
      final results = await _search(event.query);
      _emit(SearchState(query: event.query, isLoading: false, results: results));
    });
  }

  void _emit(SearchState next) {
    _state = next;
    _controller.add(next);
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _controller.close();
  }
}
''';

const _blocReference = r'''
import 'dart:async';

typedef SearchApi = Future<List<String>> Function(String query);

class SearchEvent {
  const SearchEvent(this.query);
  final String query;
}

class SearchState {
  const SearchState({
    required this.query,
    required this.isLoading,
    required this.results,
  });

  factory SearchState.initial() =>
      const SearchState(query: '', isLoading: false, results: []);

  final String query;
  final bool isLoading;
  final List<String> results;
}

class SearchBloc {
  SearchBloc({required SearchApi search, this.debounce = const Duration(milliseconds: 300)})
      : _search = search,
        _state = SearchState.initial();

  final SearchApi _search;
  final Duration debounce;
  final _controller = StreamController<SearchState>.broadcast();
  Timer? _debounceTimer;
  SearchState _state;
  int _requestGeneration = 0;

  SearchState get state => _state;
  Stream<SearchState> get stream => _controller.stream;

  void add(SearchEvent event) {
    _debounceTimer?.cancel();
    final generation = ++_requestGeneration;
    _debounceTimer = Timer(debounce, () async {
      if (generation != _requestGeneration) return;
      _emit(SearchState(query: event.query, isLoading: true, results: _state.results));
      final results = await _search(event.query);
      if (generation != _requestGeneration) return;
      _emit(SearchState(query: event.query, isLoading: false, results: results));
    });
  }

  void _emit(SearchState next) {
    _state = next;
    _controller.add(next);
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _requestGeneration++;
    await _controller.close();
  }
}
''';

const _blocPublicTest = r'''
import 'package:phase3_bloc_debounce/search_bloc.dart';
import 'package:test/test.dart';

void main() {
  test('emits results for a settled query', () async {
    final bloc = SearchBloc(
      debounce: Duration.zero,
      search: (query) async => ['$query result'],
    );
    addTearDown(bloc.dispose);

    bloc.add(const SearchEvent('flutter'));
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<SearchState>(
          (state) =>
              state.query == 'flutter' &&
              state.results.length == 1 &&
              state.results.single == 'flutter result',
        ),
      ),
    );
  });
}
''';

const _blocHiddenTest = r'''
import 'dart:async';

import 'package:phase3_bloc_debounce/search_bloc.dart';
import 'package:test/test.dart';

void main() {
  test('stale in-flight searches cannot overwrite newer results', () async {
    final pending = <String, Completer<List<String>>>{};
    final bloc = SearchBloc(
      debounce: Duration.zero,
      search: (query) => (pending[query] = Completer<List<String>>()).future,
    );
    addTearDown(bloc.dispose);

    bloc.add(const SearchEvent('old'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const SearchEvent('new'));
    await Future<void>.delayed(Duration.zero);

    pending['new']!.complete(['fresh']);
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<SearchState>(
          (state) => state.query == 'new' && state.results.single == 'fresh',
        ),
      ),
    );

    pending['old']!.complete(['stale']);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.query, 'new');
    expect(bloc.state.results, ['fresh']);
  });
}
''';

const _riverpodBaseline = r'''
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final bool isFavorite;

  Article copyWith({String? title, bool? isFavorite}) {
    return Article(
      id: id,
      title: title ?? this.title,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

abstract class ArticleRepository {
  Future<List<Article>> fetchArticles();
  Future<Article> toggleFavorite(String id);
}

class ArticleListNotifier {
  ArticleListNotifier(this._repository);

  final ArticleRepository _repository;
  List<Article>? _cache;
  List<Article> state = const [];

  Future<List<Article>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      state = _cache!;
      return state;
    }
    final articles = await _repository.fetchArticles();
    _cache = articles;
    state = articles;
    return articles;
  }

  Future<Article> toggleFavorite(String id) async {
    final updated = await _repository.toggleFavorite(id);
    return updated;
  }

  void invalidate() {
    _cache = null;
  }
}
''';

const _riverpodReference = r'''
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.isFavorite,
  });

  final String id;
  final String title;
  final bool isFavorite;

  Article copyWith({String? title, bool? isFavorite}) {
    return Article(
      id: id,
      title: title ?? this.title,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

abstract class ArticleRepository {
  Future<List<Article>> fetchArticles();
  Future<Article> toggleFavorite(String id);
}

class ArticleListNotifier {
  ArticleListNotifier(this._repository);

  final ArticleRepository _repository;
  List<Article>? _cache;
  List<Article> state = const [];

  Future<List<Article>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      state = _cache!;
      return state;
    }
    final articles = await _repository.fetchArticles();
    _cache = articles;
    state = articles;
    return articles;
  }

  Future<Article> toggleFavorite(String id) async {
    final updated = await _repository.toggleFavorite(id);
    final current = _cache ?? state;
    final next = [
      for (final article in current)
        if (article.id == id) updated else article,
    ];
    _cache = next;
    state = next;
    return updated;
  }

  void invalidate() {
    _cache = null;
  }
}
''';

const _riverpodPublicTest = r'''
import 'package:phase3_riverpod_stale_cache/article_providers.dart';
import 'package:test/test.dart';

class FakeRepository implements ArticleRepository {
  var fetches = 0;

  @override
  Future<List<Article>> fetchArticles() async {
    fetches++;
    return const [Article(id: 'a', title: 'A', isFavorite: false)];
  }

  @override
  Future<Article> toggleFavorite(String id) async {
    return const Article(id: 'a', title: 'A', isFavorite: true);
  }
}

void main() {
  test('load uses cached articles', () async {
    final repo = FakeRepository();
    final notifier = ArticleListNotifier(repo);

    await notifier.load();
    await notifier.load();

    expect(repo.fetches, 1);
    expect(notifier.state.single.title, 'A');
  });
}
''';

const _riverpodHiddenTest = r'''
import 'package:phase3_riverpod_stale_cache/article_providers.dart';
import 'package:test/test.dart';

class FakeRepository implements ArticleRepository {
  @override
  Future<List<Article>> fetchArticles() async {
    return const [Article(id: 'a', title: 'A', isFavorite: false)];
  }

  @override
  Future<Article> toggleFavorite(String id) async {
    return const Article(id: 'a', title: 'A', isFavorite: true);
  }
}

void main() {
  test('toggle updates cached state without a forced refresh', () async {
    final notifier = ArticleListNotifier(FakeRepository());

    await notifier.load();
    final updated = await notifier.toggleFavorite('a');
    final cached = await notifier.load();

    expect(updated.isFavorite, isTrue);
    expect(notifier.state.single.isFavorite, isTrue);
    expect(cached.single.isFavorite, isTrue);
  });
}
''';

const _profileBaseline = r'''
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.handle,
    required this.headline,
    required this.stats,
  });

  final String name;
  final String handle;
  final String headline;
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 36, child: Icon(Icons.person)),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.headlineSmall),
                  Text(handle),
                  Text(headline),
                  Row(
                    children: [
                      for (final entry in stats.entries)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('${entry.key}: ${entry.value}'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''';

const _profileReference = r'''
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.handle,
    required this.headline,
    required this.stats,
  });

  final String name;
  final String handle;
  final String headline;
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name $handle profile',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = _Identity(name: name, handle: handle, headline: headline);
          final statCards = _Stats(stats: stats, vertical: constraints.maxWidth < 600);
          final child = constraints.maxWidth < 600
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 16), statCards],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: identity),
                    const SizedBox(width: 24),
                    Flexible(child: statCards),
                  ],
                );
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.name, required this.handle, required this.headline});

  final String name;
  final String handle;
  final String headline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(radius: 36, child: Icon(Icons.person)),
        const SizedBox(height: 12),
        Text(name, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        Text(handle, textAlign: TextAlign.center),
        Text(headline, textAlign: TextAlign.center),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats, required this.vertical});

  final Map<String, int> stats;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final entry in stats.entries)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${entry.key}: ${entry.value}', textAlign: TextAlign.center),
          ),
        ),
    ];
    return vertical
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards)
        : Wrap(spacing: 8, runSpacing: 8, children: cards);
  }
}
''';

const _profilePublicTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_responsive_profile/profile_screen.dart';

void main() {
  testWidgets('renders profile basics', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          name: 'Ada',
          handle: '@ada',
          headline: 'Flutter engineer',
          stats: {'Posts': 12, 'Followers': 34},
        ),
      ),
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
    expect(find.text('Posts: 12'), findsOneWidget);
  });
}
''';

const _profileHiddenTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_responsive_profile/profile_screen.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          name: 'Ada',
          handle: '@ada',
          headline: 'Flutter engineer',
          stats: {'Posts': 12, 'Followers': 34},
        ),
      ),
    );
  }

  testWidgets('stacks stat cards on narrow screens', (tester) async {
    await pumpAt(tester, const Size(360, 640));

    final posts = tester.getTopLeft(find.text('Posts: 12'));
    final followers = tester.getTopLeft(find.text('Followers: 34'));
    expect(followers.dy, greaterThan(posts.dy + 20));
  });

  testWidgets('places identity and stats side by side on wide screens', (tester) async {
    await pumpAt(tester, const Size(900, 640));

    final name = tester.getTopLeft(find.text('Ada'));
    final posts = tester.getTopLeft(find.text('Posts: 12'));
    expect(posts.dx, greaterThan(name.dx + 100));
    expect(find.bySemanticsLabel('Ada @ada profile'), findsOneWidget);
  });
}
''';

const _localizationBaseline = r'''
import 'package:flutter/material.dart';

class GreetingBanner extends StatelessWidget {
  const GreetingBanner({
    super.key,
    required this.locale,
    required this.userName,
    this.onTap,
  });

  final Locale locale;
  final String userName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        label: 'Hello, $userName',
        container: true,
        button: true,
        child: ListTile(
          leading: const Icon(Icons.waving_hand),
          title: Text('Hello, $userName'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
''';

const _localizationReference = r'''
import 'package:flutter/material.dart';

class GreetingBanner extends StatelessWidget {
  const GreetingBanner({
    super.key,
    required this.locale,
    required this.userName,
    this.onTap,
  });

  final Locale locale;
  final String userName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = locale.languageCode == 'ar';
    final greeting = switch (locale.languageCode) {
      'es' => 'Hola, $userName',
      'ar' => 'مرحبا، $userName',
      _ => 'Hello, $userName',
    };
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Semantics(
        label: greeting,
        container: true,
        button: true,
        child: ListTile(
          leading: const Icon(Icons.waving_hand),
          title: Text(greeting),
          trailing: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
''';

const _localizationPublicTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_localization_rtl/greeting_banner.dart';

void main() {
  testWidgets('renders English greeting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GreetingBanner(locale: Locale('en'), userName: 'Ada'),
        ),
      ),
    );

    expect(find.text('Hello, Ada'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
''';

const _localizationHiddenTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_localization_rtl/greeting_banner.dart';

void main() {
  testWidgets('supports Spanish greeting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GreetingBanner(locale: Locale('es'), userName: 'Ada'),
        ),
      ),
    );

    expect(find.text('Hola, Ada'), findsOneWidget);
  });

  testWidgets('Arabic uses RTL direction and mirrored affordance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GreetingBanner(locale: Locale('ar'), userName: 'ليلى'),
        ),
      ),
    );

    expect(find.text('مرحبا، ليلى'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    final directionality = tester.widget<Directionality>(find.byType(Directionality).last);
    expect(directionality.textDirection, TextDirection.rtl);
    final semantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(GreetingBanner),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(semantics.properties.label, 'مرحبا، ليلى');
  });
}
''';

const _countdownWidget = r'''
import 'dart:async';

import 'package:flutter/material.dart';

class CountdownBanner extends StatefulWidget {
  const CountdownBanner({super.key, required this.seconds});

  final int seconds;

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= 1;
        if (_remaining <= 0) {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_remaining <= 0 ? 'Done' : '$_remaining seconds');
  }
}
''';

const _countdownBaselineTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_flaky_widget_test/countdown_banner.dart';

void main() {
  testWidgets('shows Done after countdown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CountdownBanner(seconds: 1)));

    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
  });
}
''';

const _countdownReferenceTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_flaky_widget_test/countdown_banner.dart';

void main() {
  testWidgets('shows Done after countdown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CountdownBanner(seconds: 1)));

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Done'), findsOneWidget);
  });
}
''';

const _countdownOverfitTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_flaky_widget_test/countdown_banner.dart';

void main() {
  testWidgets('shows countdown text initially', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CountdownBanner(seconds: 1)));

    expect(find.text('1 seconds'), findsOneWidget);
  });
}
''';

const _countdownHiddenTest = r'''
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget test advances fake time instead of wall-clock time', () {
    final content = File('test/countdown_banner_test.dart').readAsStringSync();

    expect(content, contains('tester.pump(const Duration(seconds: 1))'));
    expect(content, isNot(contains('Future<void>.delayed')));
    expect(content, isNot(contains('Future.delayed')));
  });
}
''';

const _rebuildBaseline = r'''
import 'package:flutter/material.dart';

typedef RowBuildRecorder = void Function(int id);

class Message {
  const Message({required this.id, required this.title});
  final int id;
  final String title;
}

class MessageList extends StatefulWidget {
  const MessageList({super.key, required this.messages, this.onRowBuild});

  final List<Message> messages;
  final RowBuildRecorder? onRowBuild;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  int? selectedId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final message in widget.messages)
          MessageRow(
            message: message,
            selected: selectedId == message.id,
            onTap: () => setState(() => selectedId = message.id),
            onBuild: widget.onRowBuild,
          ),
      ],
    );
  }
}

class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.selected,
    required this.onTap,
    this.onBuild,
  });

  final Message message;
  final bool selected;
  final VoidCallback onTap;
  final RowBuildRecorder? onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild?.call(message.id);
    return ListTile(
      selected: selected,
      title: Text(message.title),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
''';

const _rebuildReference = r'''
import 'package:flutter/material.dart';

typedef RowBuildRecorder = void Function(int id);

class Message {
  const Message({required this.id, required this.title});
  final int id;
  final String title;
}

class MessageList extends StatefulWidget {
  const MessageList({super.key, required this.messages, this.onRowBuild});

  final List<Message> messages;
  final RowBuildRecorder? onRowBuild;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final selectedId = ValueNotifier<int?>(null);

  @override
  void dispose() {
    selectedId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final message in widget.messages)
          _SelectableMessageRow(
            message: message,
            selectedId: selectedId,
            onBuild: widget.onRowBuild,
          ),
      ],
    );
  }
}

class _SelectableMessageRow extends StatefulWidget {
  const _SelectableMessageRow({
    required this.message,
    required this.selectedId,
    this.onBuild,
  });

  final Message message;
  final ValueNotifier<int?> selectedId;
  final RowBuildRecorder? onBuild;

  @override
  State<_SelectableMessageRow> createState() => _SelectableMessageRowState();
}

class _SelectableMessageRowState extends State<_SelectableMessageRow> {
  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selectedId.value == widget.message.id;
    widget.selectedId.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(_SelectableMessageRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      oldWidget.selectedId.removeListener(_handleSelectionChanged);
      widget.selectedId.addListener(_handleSelectionChanged);
    }
    selected = widget.selectedId.value == widget.message.id;
  }

  @override
  void dispose() {
    widget.selectedId.removeListener(_handleSelectionChanged);
    super.dispose();
  }

  void _handleSelectionChanged() {
    final next = widget.selectedId.value == widget.message.id;
    if (next != selected) {
      setState(() => selected = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call(widget.message.id);
    return ListTile(
      selected: selected,
      title: Text(widget.message.title),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => widget.selectedId.value = widget.message.id,
    );
  }
}
''';

const _rebuildPublicTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_rebuild_reduction/message_list.dart';

void main() {
  testWidgets('selects tapped row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageList(
            messages: [
              Message(id: 1, title: 'One'),
              Message(id: 2, title: 'Two'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Two'));
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
''';

const _rebuildHiddenTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_rebuild_reduction/message_list.dart';

void main() {
  testWidgets('only rows with changed selected state rebuild', (tester) async {
    final builds = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageList(
            messages: const [
              Message(id: 1, title: 'One'),
              Message(id: 2, title: 'Two'),
              Message(id: 3, title: 'Three'),
            ],
            onRowBuild: builds.add,
          ),
        ),
      ),
    );

    builds.clear();
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(builds, [2]);

    builds.clear();
    await tester.tap(find.text('Three'));
    await tester.pump();
    expect(builds.toSet(), {2, 3});
  });
}
''';

const _routerAuthState = r'''
import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  bool _signedIn;

  AuthState({bool signedIn = false}) : _signedIn = signedIn;

  bool get signedIn => _signedIn;

  void signIn() {
    _signedIn = true;
    notifyListeners();
  }

  void signOut() {
    _signedIn = false;
    notifyListeners();
  }
}
''';

const _routerBaseline = r'''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_state.dart';

GoRouter createRouter(AuthState auth, {String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: auth.signIn,
              child: const Text('Sign in'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Dashboard')),
        ),
      ),
    ],
  );
}
''';

const _routerReference = r'''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_state.dart';

GoRouter createRouter(AuthState auth, {String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.signedIn) {
        return loggingIn ? null : '/login';
      }
      return loggingIn ? '/dashboard' : null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: auth.signIn,
              child: const Text('Sign in'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Dashboard')),
        ),
      ),
    ],
  );
}
''';

const _routerPublicTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_go_router_auth/app_router.dart';
import 'package:phase3_go_router_auth/auth_state.dart';

void main() {
  testWidgets('signed-in users can open dashboard', (tester) async {
    final auth = AuthState(signedIn: true);
    await tester.pumpWidget(MaterialApp.router(routerConfig: createRouter(auth, initialLocation: '/dashboard')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
''';

const _routerHiddenTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_go_router_auth/app_router.dart';
import 'package:phase3_go_router_auth/auth_state.dart';

void main() {
  testWidgets('anonymous dashboard deep link redirects to login', (tester) async {
    final auth = AuthState();
    await tester.pumpWidget(MaterialApp.router(routerConfig: createRouter(auth, initialLocation: '/dashboard')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('sign-in refresh sends login page to dashboard', (tester) async {
    final auth = AuthState();
    await tester.pumpWidget(MaterialApp.router(routerConfig: createRouter(auth)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
''';

const _modelBaseline = r'''
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
''';

const _modelGeneratedBaseline = r'''
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) =>
    User(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};
''';

const _modelReference = r'''
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.name,
    this.role = 'viewer',
  });

  final String id;
  final String name;
  final String role;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
''';

const _modelGeneratedReference = r'''
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  name: json['name'] as String,
  role: json['role'] as String? ?? 'viewer',
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'role': instance.role,
};
''';

const _modelPublicTest = r'''
import 'package:phase3_codegen_model_migration/user_model.dart';
import 'package:test/test.dart';

void main() {
  test('round trips existing fields', () {
    final user = User.fromJson({'id': 'u1', 'name': 'Ada'});

    expect(user.id, 'u1');
    expect(user.name, 'Ada');
    expect(user.toJson()['name'], 'Ada');
  });
}
''';

const _modelHiddenTest = r'''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'role defaults and round-trips through generated companion',
    () async {
      await _runCodegen();
      await _runRoleCheck();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _runCodegen() async {
  final result = await Process.run('dart', [
    'run',
    'build_runner',
    'build',
  ]);
  expect(result.exitCode, 0, reason: _processOutput(result));
}

Future<void> _runRoleCheck() async {
  final checkDir = Directory('tool/task_checks');
  await checkDir.create(recursive: true);
  final checkFile = File('${checkDir.path}/user_model_role_check.dart');
  await checkFile.writeAsString(r"""
import 'package:phase3_codegen_model_migration/user_model.dart';

void main() {
  final viewer = User.fromJson({'id': 'u1', 'name': 'Ada'});
  final admin = User.fromJson({'id': 'u2', 'name': 'Grace', 'role': 'admin'});

  if (viewer.role != 'viewer') {
    throw StateError('Expected missing role to default to viewer, got ${viewer.role}.');
  }
  if (viewer.toJson()['role'] != 'viewer') {
    throw StateError('Expected viewer role to be serialized.');
  }
  if (admin.role != 'admin') {
    throw StateError('Expected JSON role to round-trip, got ${admin.role}.');
  }
  if (admin.toJson()['role'] != 'admin') {
    throw StateError('Expected admin role to be serialized.');
  }
}
""");

  final result = await Process.run('dart', [checkFile.path]);
  expect(result.exitCode, 0, reason: _processOutput(result));
}

String _processOutput(ProcessResult result) {
  return """
exit code: ${result.exitCode}
stdout:
${result.stdout}
stderr:
${result.stderr}
""";
}
''';

const _platformBaseline = r'''
import 'package:flutter/services.dart';

class BatteryService {
  BatteryService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('phase3/battery');

  final MethodChannel _channel;

  Future<int> batteryLevel() async {
    final level = await _channel.invokeMethod<int>('batteryLevel');
    return level ?? 0;
  }
}
''';

const _platformReference = r'''
import 'package:flutter/services.dart';

class BatteryService {
  BatteryService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('phase3/battery');

  final MethodChannel _channel;

  Future<int> batteryLevel() async {
    try {
      final level = await _channel.invokeMethod<int>('batteryLevel');
      return level ?? -1;
    } on PlatformException {
      return -1;
    }
  }
}
''';

const _platformPublicTest = r'''
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_platform_channel_mock/battery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads battery level from mock channel', () async {
    const channel = MethodChannel('phase3/battery_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'batteryLevel' ? 87 : null,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    await expectLater(BatteryService(channel: channel).batteryLevel(), completion(87));
  });
}
''';

const _platformHiddenTest = r'''
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_platform_channel_mock/battery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns fallback when host throws', () async {
    const channel = MethodChannel('phase3/battery_throw');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'missing'),
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    await expectLater(BatteryService(channel: channel).batteryLevel(), completion(-1));
  });

  test('returns fallback when host returns null', () async {
    const channel = MethodChannel('phase3/battery_null');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    await expectLater(BatteryService(channel: channel).batteryLevel(), completion(-1));
  });
}
''';

const _settingsBaseline = r'''
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool analytics = false;
  bool privateProfile = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Account', style: Theme.of(context).textTheme.titleLarge),
        const ListTile(title: Text('Email'), subtitle: Text('ada@example.com')),
        const SizedBox(height: 16),
        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('Push alerts'),
          value: notifications,
          onChanged: (value) => setState(() => notifications = value),
        ),
        SwitchListTile(
          title: const Text('Usage analytics'),
          value: analytics,
          onChanged: (value) => setState(() => analytics = value),
        ),
        const SizedBox(height: 16),
        Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('Private profile'),
          value: privateProfile,
          onChanged: (value) => setState(() => privateProfile = value),
        ),
      ],
    );
  }
}
''';

const _settingsReference = r'''
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool analytics = false;
  bool privateProfile = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final account = const _Section(
          title: 'Account',
          children: [
            ListTile(title: Text('Email'), subtitle: Text('ada@example.com')),
          ],
        );
        final controls = _Section(
          title: 'Notifications',
          children: [
            SwitchListTile(
              title: const Text('Push alerts'),
              value: notifications,
              onChanged: (value) => setState(() => notifications = value),
            ),
            SwitchListTile(
              title: const Text('Usage analytics'),
              value: analytics,
              onChanged: (value) => setState(() => analytics = value),
            ),
            const SizedBox(height: 16),
            Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(
              title: const Text('Private profile'),
              value: privateProfile,
              onChanged: (value) => setState(() => privateProfile = value),
            ),
          ],
        );
        if (constraints.maxWidth >= 720) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: account),
                const SizedBox(width: 24),
                Expanded(child: controls),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [account, const SizedBox(height: 16), controls],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        ...children,
      ],
    );
  }
}
''';

const _settingsPublicTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_large_screen_refactor/settings_screen.dart';

void main() {
  testWidgets('toggles settings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Push alerts')).value, isTrue);
    await tester.tap(find.text('Push alerts'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Push alerts')).value, isFalse);
  });
}
''';

const _settingsHiddenTest = r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phase3_large_screen_refactor/settings_screen.dart';

void main() {
  testWidgets('wide screens use two panes without breaking toggles', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

    final account = tester.getTopLeft(find.text('Account'));
    final notifications = tester.getTopLeft(find.text('Notifications'));
    expect(notifications.dx, greaterThan(account.dx + 250));

    await tester.tap(find.text('Private profile'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Private profile')).value, isTrue);
  });
}
''';
