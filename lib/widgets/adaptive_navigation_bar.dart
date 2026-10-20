import 'package:flutter/material.dart';

/// Mantém os destinos legíveis quando a preferência de texto exige mais espaço.
class AdaptiveNavigationBar extends StatefulWidget {
  const AdaptiveNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  State<AdaptiveNavigationBar> createState() => _AdaptiveNavigationBarState();
}

class _AdaptiveNavigationBarState extends State<AdaptiveNavigationBar> {
  final _scrollController = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revelarSelecionado();
  }

  @override
  void didUpdateWidget(AdaptiveNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _revelarSelecionado();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revelarSelecionado();
  }

  void _revelarSelecionado() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _selectedKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context, alignment: 0.5);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NavigationBar limita internamente o texto. Acima desse limite, os
    // destinos ganham largura e rolagem, mantendo a escala escolhida no sistema.
    if (MediaQuery.textScalerOf(context).scale(12) <= 15.6) {
      return NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        destinations: widget.destinations,
      );
    }

    final theme = Theme.of(context);
    final navigationTheme = theme.navigationBarTheme;
    return Material(
      color: navigationTheme.backgroundColor,
      elevation: navigationTheme.elevation ?? 0,
      child: SafeArea(
        top: false,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Navegação principal. Deslize para ver todas as abas.',
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < widget.destinations.length;
                    index++
                  )
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        selected: index == widget.selectedIndex,
                        enabled: widget.destinations[index].enabled,
                        label: MaterialLocalizations.of(context).tabLabel(
                          tabIndex: index + 1,
                          tabCount: widget.destinations.length,
                        ),
                        child: Tooltip(
                          message:
                              widget.destinations[index].tooltip ??
                              widget.destinations[index].label,
                          excludeFromSemantics: true,
                          child: TextButton(
                            key: index == widget.selectedIndex
                                ? _selectedKey
                                : null,
                            onPressed: widget.destinations[index].enabled
                                ? () => widget.onDestinationSelected(index)
                                : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(88, 64),
                              backgroundColor: index == widget.selectedIndex
                                  ? navigationTheme.indicatorColor
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: index == widget.selectedIndex
                                      ? widget
                                                .destinations[index]
                                                .selectedIcon ??
                                            widget.destinations[index].icon
                                      : widget.destinations[index].icon,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.destinations[index].label,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
