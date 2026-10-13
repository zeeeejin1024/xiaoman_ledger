import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/widgets/lazy_tab_host.dart';

void main() {
  testWidgets('builds tabs lazily once and preserves their state', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);
    final buildCounts = <int>[0, 0, 0];

    Widget buildTab(int index) {
      buildCounts[index]++;
      return _StatefulProbe(index: index);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (_, index, _) => Scaffold(
            body: LazyTabHost(
              index: index,
              builders: [
                (_) => buildTab(0),
                (_) => buildTab(1),
                (_) => buildTab(2),
              ],
            ),
          ),
        ),
      ),
    );

    expect(buildCounts, [1, 0, 0]);
    expect(find.text('页面 0：0'), findsOneWidget);

    selected.value = 1;
    await tester.pumpAndSettle();
    expect(buildCounts, [1, 1, 0]);
    expect(find.text('页面 1：0'), findsOneWidget);

    await tester.tap(find.text('增加'));
    await tester.pump();
    expect(find.text('页面 1：1'), findsOneWidget);

    selected.value = 0;
    await tester.pumpAndSettle();
    selected.value = 1;
    await tester.pumpAndSettle();

    expect(buildCounts, [1, 1, 0]);
    expect(find.text('页面 1：1'), findsOneWidget);
    expect(find.text('页面 0：0'), findsNothing);
  });

  testWidgets('disables hidden interaction, semantics, and tickers', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (_, index, _) =>
              LazyTabHost(index: index, builders: [_firstProbe, _secondProbe]),
        ),
      ),
    );

    selected.value = 1;
    await tester.pumpAndSettle();

    final tickerModes = tester.widgetList<TickerMode>(
      find.byType(TickerMode, skipOffstage: false),
    );
    final pointerGuards = tester.widgetList<IgnorePointer>(
      find.byType(IgnorePointer, skipOffstage: false),
    );
    final semanticGuards = tester.widgetList<ExcludeSemantics>(
      find.byType(ExcludeSemantics, skipOffstage: false),
    );

    expect(tickerModes.any((widget) => !widget.enabled), isTrue);
    expect(pointerGuards.any((widget) => widget.ignoring), isTrue);
    expect(semanticGuards.any((widget) => widget.excluding), isTrue);
    expect(find.byType(AnimatedOpacity, skipOffstage: false), findsWidgets);
    expect(find.byType(AnimatedSlide, skipOffstage: false), findsWidgets);
  });
}

class _StatefulProbe extends StatefulWidget {
  final int index;

  const _StatefulProbe({required this.index});

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('页面 ${widget.index}：$count'),
      TextButton(
        onPressed: () => setState(() => count++),
        child: const Text('增加'),
      ),
    ],
  );
}

Widget _firstProbe(BuildContext context) => const Text('first');
Widget _secondProbe(BuildContext context) => const Text('second');
