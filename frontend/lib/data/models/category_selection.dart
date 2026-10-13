enum CategorySpecificity { parent, leaf }

enum CategorySelectionSource { user, merchantRule, parser, vision }

class CategorySelection {
  final int categoryId;
  final int parentCategoryId;
  final CategorySpecificity specificity;
  final CategorySelectionSource source;
  final double confidence;

  const CategorySelection({
    required this.categoryId,
    required this.parentCategoryId,
    required this.specificity,
    required this.source,
    required this.confidence,
  });

  @override
  bool operator ==(Object other) =>
      other is CategorySelection &&
      other.categoryId == categoryId &&
      other.parentCategoryId == parentCategoryId &&
      other.specificity == specificity &&
      other.source == source &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
    categoryId,
    parentCategoryId,
    specificity,
    source,
    confidence,
  );
}
