import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'package:xiaojia_ledger/data/models/category_selection.dart';
import 'package:xiaojia_ledger/widgets/category_selector.dart';

void main() {
  final categories = [
    Category(
      id: 1,
      name: '餐饮',
      type: 'expense',
      emoji: '🍜',
      children: [
        Category(id: 2, name: '早餐', type: 'expense', emoji: '🥐'),
      ],
    ),
  ];

  Widget app({required ValueChanged<CategorySelection?> onChanged}) {
    return MaterialApp(
      home: Scaffold(
        body: CategorySelector(
          categories: categories,
          value: null,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('a root category can be selected without choosing a child', (
    tester,
  ) async {
    CategorySelection? value;
    await tester.pumpWidget(app(onChanged: (next) => value = next));

    await tester.tap(find.byKey(const ValueKey('category-select-1')));
    await tester.pump();

    expect(
      value,
      const CategorySelection(
        categoryId: 1,
        parentCategoryId: 1,
        specificity: CategorySpecificity.parent,
        source: CategorySelectionSource.user,
        confidence: 1,
      ),
    );
    expect(find.text('早餐'), findsNothing);
  });

  testWidgets('child categories expand from a separate control', (tester) async {
    CategorySelection? value;
    await tester.pumpWidget(app(onChanged: (next) => value = next));

    await tester.tap(find.byKey(const ValueKey('category-expand-1')));
    await tester.pump();
    expect(value, isNull);
    expect(find.textContaining('早餐'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('category-select-2')));
    await tester.pump();
    expect(value?.categoryId, 2);
    expect(value?.parentCategoryId, 1);
    expect(value?.specificity, CategorySpecificity.leaf);
  });
}
