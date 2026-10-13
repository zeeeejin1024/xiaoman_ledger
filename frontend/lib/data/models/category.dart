class Category {
  final int id;
  final int? parentId;
  final String name;
  final String type;
  final String? emoji;
  final bool isSystem;
  final List<Category> children;

  Category({
    required this.id,
    this.parentId,
    required this.name,
    required this.type,
    this.emoji,
    this.isSystem = true,
    this.children = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      type: json['type'],
      emoji: json['emoji'],
      isSystem: json['is_system'] ?? true,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((c) => Category.fromJson(c))
              .toList() ??
          [],
    );
  }

  /// 递归获取所有叶子节点（没有子分类的最终分类）
  List<Category> get leafCategories {
    if (children.isEmpty) return [this];
    return children.expand((c) => c.leafCategories).toList();
  }
}
