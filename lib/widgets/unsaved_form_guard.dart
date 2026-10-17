import 'package:flutter/material.dart';

/// Protege somente o preenchimento local; salvar continua sendo tarefa da tela.
class UnsavedFormGuard extends StatefulWidget {
  const UnsavedFormGuard({
    required this.controllers,
    required this.initialValues,
    required this.busy,
    required this.child,
    this.isDirty,
    super.key,
  });

  final List<TextEditingController> controllers;
  final List<String> initialValues;
  final bool busy;
  final Widget child;
  final bool Function()? isDirty;

  @override
  State<UnsavedFormGuard> createState() => _UnsavedFormGuardState();
}

class _UnsavedFormGuardState extends State<UnsavedFormGuard> {
  bool _dialogOpen = false;
  bool _discardConfirmed = false;

  bool get _changed =>
      (widget.controllers.length == widget.initialValues.length &&
          widget.controllers.indexed.any(
            (entry) => entry.$2.text != widget.initialValues[entry.$1],
          )) ||
      (widget.isDirty?.call() ?? false);

  Future<void> _onBack() async {
    if (_dialogOpen) return;
    if (widget.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde o salvamento antes de sair.')),
      );
      return;
    }
    _dialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Descartar alterações?'),
        content: const Text('As alterações ainda não foram salvas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || discard != true || widget.busy) return;
    setState(() => _discardConfirmed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(widget.controllers),
    builder: (context, child) => PopScope(
      canPop: !widget.busy && (!_changed || _discardConfirmed),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: child!,
    ),
    child: widget.child,
  );
}
