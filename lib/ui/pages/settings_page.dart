import 'package:dart_arena/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repo = SettingsRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OllamaLocalSection(repo: _repo),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'ollama_cloud',
            label: 'Ollama Cloud',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'opencode_zen',
            label: 'OpenCode Zen',
          ),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'openai',
            label: 'OpenAI',
          ),
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
          const ListTile(
            title: Text('Factory Droid'),
            subtitle: Text('Uses local droid CLI; no key needed in app.'),
          ),
        ],
      ),
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
        const Text('Ollama Local',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            Text(widget.label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Badge(
              label: Text(_hasKey ? 'Set' : 'Not configured'),
              backgroundColor:
                  _hasKey ? Colors.green.shade700 : Colors.orange.shade800,
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
