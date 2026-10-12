import 'package:flutter/material.dart';

class ActionLabel extends StatelessWidget {
  const ActionLabel({required this.text, required this.busy, super.key});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) =>
      Semantics(liveRegion: busy, child: Text(text));
}

class ButtonProgressIndicator extends StatelessWidget {
  const ButtonProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
