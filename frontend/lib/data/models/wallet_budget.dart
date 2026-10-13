class WalletBudget {
  final int id;
  final String name;
  final double amount;
  final double spent;
  final double remaining;
  final String color;
  final List<WalletCategoryBinding> bindings;

  const WalletBudget({
    required this.id,
    required this.name,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.color,
    this.bindings = const [],
  });

  factory WalletBudget.fromJson(Map<String, dynamic> json) => WalletBudget(
    id: json['id'] as int,
    name: '${json['name'] ?? ''}',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    spent: (json['spent'] as num?)?.toDouble() ?? 0,
    remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
    color: '${json['color'] ?? ''}',
    bindings: ((json['bindings'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => WalletCategoryBinding.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class WalletCategoryBinding {
  final int categoryId;
  final bool includeDescendants;
  const WalletCategoryBinding({required this.categoryId, required this.includeDescendants});
  factory WalletCategoryBinding.fromJson(Map<String, dynamic> json) => WalletCategoryBinding(
    categoryId: json['category_id'] as int,
    includeDescendants: json['include_descendants'] == true,
  );
}
