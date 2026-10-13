class AppConstants {
  static const String appName = '小满记账';
  static const String appVersion = '7.0.10';

  // API 地址：开发环境用 localhost，生产环境替换为服务器 IP
  static const String baseUrl = 'http://114.55.138.55/api/v1';

  static const String tokenKey = 'auth_token';
  static const String usernameKey = 'auth_username';
  static const String themeKey = 'app_theme';
  static const String splashSkippedKey = 'splash_skipped';

  // 密保问题列表（避免重复定义）
  static const List<String> securityQuestions = [
    '你的母亲的名字是？',
    '你的父亲的名字是？',
    '你小时候最好的朋友叫什么？',
    '你的第一只宠物叫什么？',
    '你出生在哪个城市？',
    '你的小学叫什么名字？',
  ];
}
