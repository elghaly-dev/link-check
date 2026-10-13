import 'package:flutter/material.dart';
import 'package:link_check_client/link_check_client.dart';

import '../client.dart';
import 'link_check_result_view.dart';

class LinkCheckScreen extends StatefulWidget {
  const LinkCheckScreen({super.key});

  @override
  State<LinkCheckScreen> createState() => _LinkCheckScreenState();
}

class _LinkCheckScreenState extends State<LinkCheckScreen> {
  final _urlController = TextEditingController(
    text: 'https://example.com',
  );

  LinkCheckResult? _result;
  String? _transportError;
  bool _loading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = null;
        _transportError = 'Please enter a URL to check.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _transportError = null;
      _result = null;
    });

    try {
      final result = await client.linkCheck.check(url);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transportError = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final maxContentWidth = width > 720 ? 640.0 : width;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check any public HTTP or HTTPS link for status, timing, and TLS — without leaving your browser.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _urlController,
                enabled: !_loading,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _runCheck(),
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com/page',
                  prefixIcon: const Icon(Icons.link),
                  border: const OutlineInputBorder(),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Check link',
                          onPressed: _runCheck,
                          icon: const Icon(Icons.search),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _runCheck,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_loading ? 'Checking…' : 'Check link'),
              ),
              const SizedBox(height: 28),
              LinkCheckResultView(
                result: _result,
                transportError: _transportError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
