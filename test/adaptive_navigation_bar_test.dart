import 'package:conectarlar_app/app/theme.dart';
import 'package:conectarlar_app/widgets/adaptive_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navegação respeita texto ampliado e mantém todas as ações', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const labels = ['Central', 'Contas', 'Moderação', 'Catálogo', 'Auditoria'];

    for (final width in [360.0, 390.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        tester.view.physicalSize = Size(width, 844);
        var selected = 4;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$width-$scale'),
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: AdaptiveNavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (index) =>
                      setState(() => selected = index),
                  destinations: [
                    for (final label in labels)
                      NavigationDestination(
                        icon: const Icon(Icons.circle_outlined),
                        label: label,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Auditoria').hitTestable(), findsOneWidget);
        for (var index = 0; index < labels.length; index++) {
          final label = find.text(labels[index]);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(paragraph.textScaler.scale(12), closeTo(12 * scale, 0.01));
          expect(paragraph.didExceedMaxLines, isFalse);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(selected, index);
          expect(tester.takeException(), isNull, reason: '$width / $scale');
        }
      }
    }
  });
}
