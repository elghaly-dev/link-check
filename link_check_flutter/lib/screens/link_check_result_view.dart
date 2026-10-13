import 'package:flutter/material.dart';
import 'package:link_check_client/link_check_client.dart';

/// Presents a [LinkCheckResult] or a transport-level failure message.
class LinkCheckResultView extends StatelessWidget {
  const LinkCheckResultView({
    super.key,
    this.result,
    this.transportError,
  });

  final LinkCheckResult? result;
  final String? transportError;

  @override
  Widget build(BuildContext context) {
    if (transportError != null) {
      return _Shell(
        tone: _ResultTone.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Could not reach server'),
            Text(
              transportError!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final data = result;
    if (data == null) {
      return _Shell(
        tone: _ResultTone.neutral,
        child: Text(
          'Enter a URL above and run a check to see status, timing, and HTTPS details.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final tone = _toneFor(data);
    return _Shell(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusHeader(result: data, tone: tone),
          const SizedBox(height: 20),
          _MetricRow(
            icon: Icons.speed_outlined,
            label: 'Response time',
            value: '${data.responseTimeMs} ms',
          ),
          if (data.statusCode != null) ...[
            const SizedBox(height: 12),
            _MetricRow(
              icon: Icons.tag_outlined,
              label: 'HTTP status',
              value: '${data.statusCode}',
            ),
          ],
          const SizedBox(height: 12),
          _MetricRow(
            icon: data.isHttps ? Icons.lock_outline : Icons.lock_open_outlined,
            label: 'HTTPS',
            value: data.isHttps ? 'Yes' : 'No',
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _UrlBlock(label: 'Requested URL', url: data.requestedUrl),
          if (data.finalUrl != null &&
              data.finalUrl!.isNotEmpty &&
              data.finalUrl != data.requestedUrl) ...[
            const SizedBox(height: 12),
            _UrlBlock(label: 'Final URL (after redirects)', url: data.finalUrl!),
          ],
          if (data.error != null && data.error!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: data.error!),
          ],
          const SizedBox(height: 16),
          Text(
            'Checked ${_formatTimestamp(data.checkedAt)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static _ResultTone _toneFor(LinkCheckResult result) {
    if (result.error != null && !result.isReachable) {
      return _ResultTone.error;
    }
    if (result.isReachable) {
      final code = result.statusCode ?? 0;
      if (code >= 200 && code < 400) return _ResultTone.success;
      if (code >= 400) return _ResultTone.warning;
    }
    return _ResultTone.neutral;
  }

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min local';
  }
}

enum _ResultTone { success, warning, error, neutral }

class _Shell extends StatelessWidget {
  const _Shell({required this.tone, required this.child});

  final _ResultTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, border) = switch (tone) {
      _ResultTone.success => (colors.primaryContainer.withValues(alpha: 0.35), colors.primary),
      _ResultTone.warning => (colors.tertiaryContainer.withValues(alpha: 0.45), colors.tertiary),
      _ResultTone.error => (colors.errorContainer.withValues(alpha: 0.45), colors.error),
      _ResultTone.neutral => (colors.surfaceContainerHighest.withValues(alpha: 0.5), colors.outlineVariant),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.result, required this.tone});

  final LinkCheckResult result;
  final _ResultTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = _statusLabel(result);

    final accent = switch (tone) {
      _ResultTone.success => theme.colorScheme.primary,
      _ResultTone.warning => theme.colorScheme.tertiary,
      _ResultTone.error => theme.colorScheme.error,
      _ResultTone.neutral => theme.colorScheme.onSurfaceVariant,
    };

    return Row(
      children: [
        Icon(icon, size: 28, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  (String, IconData) _statusLabel(LinkCheckResult result) {
    if (result.error != null && !result.isReachable) {
      return ('Check blocked or failed', Icons.block_flipped);
    }
    if (!result.isReachable) {
      return ('Unreachable', Icons.cloud_off_outlined);
    }
    final code = result.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      return ('Reachable · $code OK', Icons.check_circle_outline);
    }
    if (code >= 300 && code < 400) {
      return ('Reachable · $code redirect', Icons.swap_horiz);
    }
    if (code >= 400) {
      return ('Reachable · $code error', Icons.error_outline);
    }
    return ('Reachable', Icons.link);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UrlBlock extends StatelessWidget {
  const _UrlBlock({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          url,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
