import 'package:xiaojia_ledger/data/models/category.dart';

/// Category leafCategories 缓存，避免重复递归计算
///
/// 参考：ui-ux-pro-max 性能优化规则 - 缓存重复计算结果
/// 在分类数据变更时调用 clear() 清除缓存
class CategoryCache {
  static Map<int, List<Category>> _cache = {};

  /// 获取叶子分类（带缓存）
  static List<Category> getLeafCategories(Category category) {
    return _cache[category.id] ??= category.leafCategories;
  }

  /// 清除所有缓存（分类变更时调用）
  static void clear() {
    _cache.clear();
  }
}
