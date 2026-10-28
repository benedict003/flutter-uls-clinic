import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.cloud_off, size: 52, color: theme.colorScheme.error),
        const SizedBox(height: 14),
        Text('$error', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),
        if (onRetry != null)
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
      ],
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 64),
        Icon(icon, size: 52, color: theme.colorScheme.outline),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$error')));
}

String dash(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}