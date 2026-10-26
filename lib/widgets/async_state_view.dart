import 'package:flutter/material.dart';

import '../app/theme.dart';

class AsyncLoadingView extends StatelessWidget {
  const AsyncLoadingView({this.label = 'Carregando conteúdo.', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: label,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        label: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: _StateIcon(icon: icon, color: AppColors.textoSuave),
            ),
            const SizedBox(height: AppSpace.lg),
            ExcludeSemantics(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionErrorView extends StatelessWidget {
  const SectionErrorView({
    required this.message,
    required this.onRetry,
    this.retrying = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    liveRegion: retrying,
    label: retrying ? '$message Atualizando.' : message,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton.icon(
          onPressed: retrying ? null : onRetry,
          icon: retrying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(retrying ? 'Atualizando…' : 'Tentar novamente'),
        ),
      ],
    ),
  );
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        label: '$title $message',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: _StateIcon(icon: icon, color: AppColors.verdeEscuro),
            ),
            const SizedBox(height: AppSpace.lg),
            ExcludeSemantics(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            ExcludeSemantics(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textoSuave),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpace.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Mensagem vazia compacta para seções dentro de uma página carregada.
class InlineEmptyState extends StatelessWidget {
  const InlineEmptyState({
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Semantics(
      container: true,
      label: message,
      child: ExcludeSemantics(
        child: Padding(
          padding: AppInsets.card,
          child: Row(
            children: [
              Icon(icon, color: AppColors.textoSuave, size: 22),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: child,
      ),
    ),
  );
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.verdeClaro,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 64,
        child: Icon(icon, color: color, size: 32),
      ),
    ),
  );
}
