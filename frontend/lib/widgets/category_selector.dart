import 'package:flutter/material.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'package:xiaojia_ledger/data/models/category_selection.dart';

class CategorySelector extends StatefulWidget {
  final List<Category> categories;
  final CategorySelection? value;
  final ValueChanged<CategorySelection?> onChanged;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  int? _expandedId;

  void _select(
    Category category, {
    required bool parent,
    required int rootId,
  }) {
    widget.onChanged(
      CategorySelection(
        categoryId: category.id,
        parentCategoryId: rootId,
        specificity: parent ? CategorySpecificity.parent : CategorySpecificity.leaf,
        source: CategorySelectionSource.user,
        confidence: 1,
      ),
    );
    if (!parent) setState(() => _expandedId = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: widget.categories.map((parent) {
        final children = parent.children;
        final expanded = _expandedId == parent.id;
        final parentSelected = widget.value?.categoryId == parent.id;
        return Column(
          key: ValueKey('category-group-${parent.id}'),
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: ValueKey('category-select-${parent.id}'),
                    onTap: () => _select(parent, parent: true, rootId: parent.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: parentSelected
                            ? AppColors.accent.withAlpha(40)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(parent.emoji ?? '', style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(parent.name)),
                          if (parentSelected)
                            Icon(Icons.check_circle, color: AppColors.accent, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                if (children.isNotEmpty)
                  GestureDetector(
                    key: ValueKey('category-expand-${parent.id}'),
                    onTap: () => setState(
                      () => _expandedId = expanded ? null : parent.id,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ),
              ],
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6, bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: children.map((child) {
                    final selected = widget.value?.categoryId == child.id;
                    return InkWell(
                      key: ValueKey('category-select-${child.id}'),
                      onTap: () => _select(child, parent: false, rootId: parent.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.accent.withAlpha(40) : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: selected ? Border.all(color: AppColors.accent) : null,
                        ),
                        child: Text('${child.emoji ?? ''} ${child.name}'),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }
}
