import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dart_arena/ui/widgets/evaluator_weights_section.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsRepository _repo;
  int _providersVersion = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<SettingsRepository>();
  }

  void _onProvidersChanged() => setState(() => _providersVersion++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _JudgeSection(key: ValueKey('judge_$_providersVersion')),
          const Divider(),
          const EvaluatorWeightsSection(),
          const Divider(),
          _OllamaLocalSection(repo: _repo),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'ollama_cloud',
            label: 'Ollama Cloud',
          ),
          const Divider(),
          _CustomLocalProvidersSection(
            repo: _repo,
            onChanged: _onProvidersChanged,
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'opencode_go',
            label: 'OpenCode Go',
          ),
          const Divider(),
          _ApiKeySection(repo: _repo, providerId: 'openai', label: 'OpenAI'),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'openrouter',
            label: 'OpenRouter',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'deepseek',
            label: 'DeepSeek',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'anthropic',
            label: 'Anthropic',
          ),
          const Divider(),
          _ReadmeSection(repo: _repo),
          const Divider(),
          const ListTile(
            title: Text('Factory Droid'),
            subtitle: Text('Uses local droid CLI; no key needed in app.'),
          ),
          const Divider(),
          const _CacheSection(),
          const Divider(),
          const _ConcurrencySection(),
        ],
      ),
    );
  }
}

class _CacheSection extends StatefulWidget {
  const _CacheSection();
  @override
  State<_CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends State<_CacheSection> {
  late final TmpDirManager _manager;
  int? _size;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _manager = context.read<TmpDirManager>();
    _refresh();
  }

  Future<void> _refresh() async {
    final size = await _manager.currentSize();
    if (!mounted) return;
    setState(() => _size = size);
  }

  String _format(int? bytes) {
    if (bytes == null) return '…';
    if (bytes < 1024) return '$bytes B';
    const kb = 1024;
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear subprocess cache?'),
        content: const Text(
          'Delete all cached subprocess files? This may slow down the next '
          'benchmark run while caches are rebuilt. Do not clear the cache '
          'while a benchmark is running.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final before = _size ?? await _manager.currentSize();
    await _manager.clear();
    final after = await _manager.currentSize();
    if (!mounted) return;
    setState(() {
      _size = after;
      _busy = false;
    });
    final freed = (before - after).clamp(0, before);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Freed ${_format(freed)}')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subprocess cache (TMPDIR)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText(
            _manager.root.path,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text('Current size: ${_format(_size)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : _confirmClear,
                child: const Text('Clear cache'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConcurrencySection extends StatefulWidget {
  const _ConcurrencySection();
  @override
  State<_ConcurrencySection> createState() => _ConcurrencySectionState();
}

class _ConcurrencySectionState extends State<_ConcurrencySection> {
  final _repo = SettingsRepository();
  double _value = 4;

  @override
  void initState() {
    super.initState();
    _repo.getRunConcurrency().then(
      (v) => setState(() => _value = v.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Max concurrent generations: ${_value.toInt()}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _value,
            min: 1,
            max: 8,
            divisions: 7,
            label: _value.toInt().toString(),
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: (v) => _repo.setRunConcurrency(v.toInt()),
          ),
        ],
      ),
    );
  }
}

class _JudgeSection extends StatefulWidget {
  const _JudgeSection({super.key});
  @override
  State<_JudgeSection> createState() => _JudgeSectionState();
}

class _JudgeSectionState extends State<_JudgeSection> {
  final _repo = SettingsRepository();
  final _modelController = TextEditingController();
  String? _providerId;
  List<String> _providerIds = const [];

  static const _knownProviders = <String>[
    'ollama_local',
    'ollama_cloud',
    'opencode_go',
    'openai',
    'openrouter',
    'deepseek',
    'anthropic',
    'droid',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = await _repo.getJudgeProviderId();
    final mid = await _repo.getJudgeModelId();
    final customs = await _repo.getCustomLocalProviders();
    final dynamicIds = customs.map((c) => c.id).toList();
    final merged = <String>[..._knownProviders];
    for (final id in dynamicIds) {
      if (!merged.contains(id)) merged.add(id);
    }
    if (!mounted) return;
    setState(() {
      _providerId = (pid != null && merged.contains(pid)) ? pid : null;
      _modelController.text = mid ?? '';
      _providerIds = merged;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Judge Model',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey(_providerId),
              initialValue: _providerIds.contains(_providerId)
                  ? _providerId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Judge provider',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('(none — disable judge)'),
                ),
                ..._providerIds.map(
                  (p) => DropdownMenuItem<String?>(value: p, child: Text(p)),
                ),
              ],
              onChanged: (v) => setState(() => _providerId = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Judge model id',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await _repo.setJudgeProviderId(_providerId);
                await _repo.setJudgeModelId(
                  _modelController.text.trim().isEmpty
                      ? null
                      : _modelController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Judge saved')));
                }
              },
              child: const Text('Save judge'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomLocalProvidersSection extends StatefulWidget {
  const _CustomLocalProvidersSection({required this.repo, this.onChanged});
  final SettingsRepository repo;
  final VoidCallback? onChanged;

  @override
  State<_CustomLocalProvidersSection> createState() =>
      _CustomLocalProvidersSectionState();
}

class _CustomLocalProvidersSectionState
    extends State<_CustomLocalProvidersSection> {
  Future<List<CustomLocalProviderEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      _future = widget.repo.getCustomLocalProviders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Local OpenAI-compatible providers',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'For llama.cpp, vLLM, LM Studio, Codex, and other local /v1 endpoints.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<CustomLocalProviderEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            final entries = snap.data ?? const [];
            return Column(
              children: [
                for (final entry in entries)
                  _ProviderCard(
                    entry: entry,
                    repo: widget.repo,
                    onEdited: () => _openDialog(entry: entry),
                    onDeleted: () => _delete(entry.id),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add provider'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openDialog({CustomLocalProviderEntry? entry}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _LocalProviderDialog(entry: entry, repo: widget.repo),
    );
    if (saved == true) {
      _load();
      widget.onChanged?.call();
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete provider?'),
        content: Text('Delete "$id" and its stored URL and API key?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repo.deleteCustomLocalProvider(id);
      _load();
      widget.onChanged?.call();
    }
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.entry,
    required this.repo,
    required this.onEdited,
    required this.onDeleted,
  });

  final CustomLocalProviderEntry entry;
  final SettingsRepository repo;
  final VoidCallback onEdited;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _UrlPreview(id: entry.id, repo: repo),
                  _KeyBadge(id: entry.id, repo: repo),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdited),
            IconButton(icon: const Icon(Icons.delete), onPressed: onDeleted),
          ],
        ),
      ),
    );
  }
}

class _UrlPreview extends StatelessWidget {
  const _UrlPreview({required this.id, required this.repo});
  final String id;
  final SettingsRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: repo.getBaseUrlOverride(id),
      builder: (context, snap) {
        final url = snap.data?.trim();
        return Text(
          (url != null && url.isNotEmpty) ? url : 'No URL configured',
          style: TextStyle(
            fontSize: 12,
            fontStyle: url == null || url.isEmpty ? FontStyle.italic : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.id, required this.repo});
  final String id;
  final SettingsRepository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: repo.getApiKey(id),
      builder: (context, snap) {
        final hasKey = snap.data != null && snap.data!.trim().isNotEmpty;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasKey ? Icons.vpn_key : Icons.vpn_key_off,
              size: 14,
              color: hasKey ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              hasKey ? 'Key set' : 'No key',
              style: TextStyle(
                fontSize: 11,
                color: hasKey ? Colors.green : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LocalProviderDialog extends StatefulWidget {
  const _LocalProviderDialog({this.entry, required this.repo});
  final CustomLocalProviderEntry? entry;
  final SettingsRepository repo;

  @override
  State<_LocalProviderDialog> createState() => _LocalProviderDialogState();
}

class _LocalProviderDialogState extends State<_LocalProviderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _effortsController = TextEditingController();
  bool _obscured = true;
  bool _testing = false;
  final _headerRows =
      <({TextEditingController key, TextEditingController value})>[];

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _nameController.text = e.name;
      _idController.text = e.id;
      _effortsController.text = e.defaultEfforts.join(', ');
      for (final header in e.extraHeaders.entries) {
        _headerRows.add((
          key: TextEditingController(text: header.key),
          value: TextEditingController(text: header.value),
        ));
      }
    }
    _loadUrlAndKey();
  }

  Future<void> _loadUrlAndKey() async {
    final e = widget.entry;
    if (e != null) {
      final url = await widget.repo.getBaseUrlOverride(e.id);
      final key = await widget.repo.getApiKey(e.id);
      if (!mounted) return;
      _urlController.text = url ?? 'http://127.0.0.1:8080/v1';
      _keyController.text = key ?? '';
    } else {
      _urlController.text = 'http://127.0.0.1:8080/v1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _effortsController.dispose();
    for (final row in _headerRows) {
      row.key.dispose();
      row.value.dispose();
    }
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final provider = OpenAiCompatibleProvider(
        null,
        id: _idController.text.trim(),
        displayName: _nameController.text.trim(),
        baseUrl: _urlController.text.trim(),
        apiKey: _keyController.text.trim(),
        extraHeaders: _parsedHeaders(),
      );
      final models = await provider.listModels();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OK (${models.length} models)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Map<String, String> _parsedHeaders() {
    final headers = <String, String>{};
    for (final row in _headerRows) {
      final k = row.key.text.trim();
      final v = row.value.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) headers[k] = v;
    }
    return headers;
  }

  List<String> _parsedEfforts() {
    return _effortsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<CustomLocalProviderEntry>> _latestList() async {
    try {
      return await widget.repo.getCustomLocalProviders();
    } catch (_) {
      return const [];
    }
  }

  String? _validateId(String? raw) {
    if (raw == null) return 'ID is required';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'ID is required';
    final currentList = _latestListSync();
    final existingIds = currentList.map((e) => e.id);
    return validateCustomLocalProviderId(
      trimmed,
      existingIds: existingIds,
      currentId: _isEdit ? widget.entry!.id : null,
    );
  }

  List<CustomLocalProviderEntry> _latestListSync() {
    return _latestListCache ?? const [];
  }

  List<CustomLocalProviderEntry>? _latestListCache;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    _latestListCache = await _latestList();

    // Re-validate with fresh list
    final idError = _validateId(_idController.text);
    if (idError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(idError)));
      return;
    }

    final name = _nameController.text.trim();
    final id = _idController.text.trim();
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    final entry = CustomLocalProviderEntry(
      id: id,
      name: name,
      extraHeaders: _parsedHeaders(),
      defaultEfforts: _parsedEfforts(),
    );

    // Save URL and API key
    if (url.isEmpty) {
      await widget.repo.setBaseUrlOverride(id, 'http://127.0.0.1:8080/v1');
    } else {
      await widget.repo.setBaseUrlOverride(id, url);
    }
    if (key.isEmpty) {
      await widget.repo.clearApiKey(id);
    } else {
      await widget.repo.setApiKey(id, key);
    }

    // Update index
    final list = _latestListCache!.toList();
    if (_isEdit) {
      final idx = list.indexWhere((e) => e.id == widget.entry!.id);
      if (idx >= 0) {
        list[idx] = entry;
      } else {
        list.add(entry);
      }
    } else {
      list.add(entry);
    }
    await widget.repo.setCustomLocalProviders(list);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit provider' : 'Add provider'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idController,
                  enabled: !_isEdit,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    border: OutlineInputBorder(),
                    helperText:
                        'Lowercase letters, digits, underscores. 2–32 chars.',
                  ),
                  validator: _validateId,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'URL is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _keyController,
                  obscureText: _obscured,
                  decoration: InputDecoration(
                    labelText: 'API key (optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscured ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Extra headers',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() {
                        _headerRows.add((
                          key: TextEditingController(),
                          value: TextEditingController(),
                        ));
                      }),
                    ),
                  ],
                ),
                for (var i = 0; i < _headerRows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _headerRows[i].key,
                            decoration: const InputDecoration(
                              hintText: 'Key',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty &&
                                  (_headerRows[i].value.text
                                      .trim()
                                      .isNotEmpty)) {
                                return 'Key required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _headerRows[i].value,
                            decoration: const InputDecoration(
                              hintText: 'Value',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty &&
                                  (_headerRows[i].key.text.trim().isNotEmpty)) {
                                return 'Value required';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            _headerRows[i].key.dispose();
                            _headerRows[i].value.dispose();
                            setState(() => _headerRows.removeAt(i));
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _effortsController,
                  decoration: const InputDecoration(
                    labelText: 'Default efforts (comma-separated)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g. low, medium, high',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _testing ? null : _testConnection,
          child: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Test connection'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _OllamaLocalSection extends StatefulWidget {
  const _OllamaLocalSection({required this.repo});
  final SettingsRepository repo;

  @override
  State<_OllamaLocalSection> createState() => _OllamaLocalSectionState();
}

class _OllamaLocalSectionState extends State<_OllamaLocalSection> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.repo.getOllamaBaseUrl().then((v) {
      setState(() => _controller.text = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ollama Local',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final router = GoRouter.of(context);
            await widget.repo.setOllamaBaseUrl(_controller.text);
            if (mounted) router.pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ApiKeySection extends StatefulWidget {
  const _ApiKeySection({
    required this.repo,
    required this.providerId,
    required this.label,
  });
  final SettingsRepository repo;
  final String providerId;
  final String label;

  @override
  State<_ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends State<_ApiKeySection> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    widget.repo.getApiKey(widget.providerId).then((v) {
      setState(() {
        _controller.text = v ?? '';
        _hasKey = v != null && v.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Badge(
              label: Text(_hasKey ? 'Set' : 'Not configured'),
              backgroundColor: _hasKey
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          obscureText: _obscured,
          decoration: InputDecoration(
            labelText: 'API Key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final router = GoRouter.of(context);
            await widget.repo.setApiKey(widget.providerId, _controller.text);
            setState(() => _hasKey = _controller.text.isNotEmpty);
            if (mounted) router.pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ReadmeSection extends StatefulWidget {
  const _ReadmeSection({required this.repo});
  final SettingsRepository repo;

  @override
  State<_ReadmeSection> createState() => _ReadmeSectionState();
}

class _ReadmeSectionState extends State<_ReadmeSection> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.repo.getReadmePath().then((v) {
      if (!mounted) return;
      setState(() => _controller.text = v ?? '');
    });
  }

  Future<void> _browse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md'],
      dialogTitle: 'Select README.md',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _controller.text = path);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'README publishing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'README path',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _browse, child: const Text('Browse...')),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'The "Publish to README" button replaces content between\n'
          '  <!-- BENCHMARK_RESULTS:START -->\n'
          '  <!-- BENCHMARK_RESULTS:END -->\n'
          'markers in the file above. Add these markers manually to your '
          'README before publishing.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await widget.repo.setReadmePath(
              _controller.text.trim().isEmpty ? null : _controller.text.trim(),
            );
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('README path saved')),
            );
          },
          child: const Text('Save README path'),
        ),
      ],
    );
  }
}
