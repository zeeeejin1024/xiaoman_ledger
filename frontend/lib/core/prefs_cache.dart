import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 单例缓存，避免重复异步获取实例
///
/// 在 main.dart 中初始化一次，后续所有地方通过 getInstance() 获取
/// 参考：ui-ux-pro-max 性能优化规则 - 减少异步操作重复调用
class PrefsCache {
  static SharedPreferences? _instance;

  /// 获取缓存的 SharedPreferences 实例
  static Future<SharedPreferences> getInstance() async {
    _instance ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// 清除缓存（仅在登出时调用）
  static void clear() {
    _instance = null;
  }
}
