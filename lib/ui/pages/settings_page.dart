import 'package:dart_arena/storage/settings.dart';
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

  @override
  void initState() {
    super.initState();
    _repo = context.read<SettingsRepository>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _JudgeSection(),
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
          _LocalOpenAiSection(repo: _repo),
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
          const _ConcurrencySection(),
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
  const _JudgeSection();
  @override
  State<_JudgeSection> createState() => _JudgeSectionState();
}

class _JudgeSectionState extends State<_JudgeSection> {
  final _repo = SettingsRepository();
  final _modelController = TextEditingController();
  String? _providerId;

  static const _knownProviders = <String>[
    'ollama_local',
    'ollama_cloud',
    'local_openai',
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
    setState(() {
      _providerId = pid;
      _modelController.text = mid ?? '';
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
              initialValue: _knownProviders.contains(_providerId)
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
                ..._knownProviders.map(
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

class _LocalOpenAiSection extends StatefulWidget {
  const _LocalOpenAiSection({required this.repo});
  final SettingsRepository repo;

  @override
  State<_LocalOpenAiSection> createState() => _LocalOpenAiSectionState();
}

class _LocalOpenAiSectionState extends State<_LocalOpenAiSection> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final baseUrl = await widget.repo.getBaseUrlOverride('local_openai');
    final apiKey = await widget.repo.getApiKey('local_openai');
    if (!mounted) return;
    setState(() {
      _baseUrlController.text = baseUrl ?? 'http://127.0.0.1:8080/v1';
      _apiKeyController.text = apiKey ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Local OpenAI-compatible',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'For llama.cpp, vLLM, LM Studio, and other local /v1 endpoints.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscured,
          decoration: InputDecoration(
            labelText: 'API Key (optional)',
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
            final messenger = ScaffoldMessenger.of(context);
            final baseUrl = _baseUrlController.text.trim().isEmpty
                ? 'http://127.0.0.1:8080/v1'
                : _baseUrlController.text.trim();
            await widget.repo.setBaseUrlOverride('local_openai', baseUrl);
            final apiKey = _apiKeyController.text.trim();
            if (apiKey.isEmpty) {
              await widget.repo.clearApiKey('local_openai');
            } else {
              await widget.repo.setApiKey('local_openai', apiKey);
            }
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Local provider saved')),
            );
          },
          child: const Text('Save local provider'),
        ),
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
