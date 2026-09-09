import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';

void main() {
  testWidgets('未满之圆提供品牌语义并保持固定尺寸', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UnfinishedRingMark(size: 72, animate: false)),
      ),
    );

    expect(find.byType(UnfinishedRingMark), findsOneWidget);
    expect(find.bySemanticsLabel('小满记账标志'), findsOneWidget);
    expect(tester.getSize(find.byType(UnfinishedRingMark)), const Size(72, 72));
  });

  testWidgets('动态模式可以在不改变布局尺寸的情况下运行', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UnfinishedRingMark(size: 96, animate: true)),
      ),
    );

    final before = tester.getSize(find.byType(UnfinishedRingMark));
    await tester.pump(const Duration(milliseconds: 800));
    final after = tester.getSize(find.byType(UnfinishedRingMark));

    expect(before, const Size(96, 96));
    expect(after, const Size(96, 96));
  });
}
