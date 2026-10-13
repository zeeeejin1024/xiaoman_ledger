class AuthData {
  final String username;
  final String token;
  final bool needMigrate;

  AuthData({
    required this.username,
    required this.token,
    this.needMigrate = false,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      username: json['username'] ?? '',
      token: json['token'] ?? '',
      needMigrate: json['need_migrate'] ?? false,
    );
  }
}

class UserInfo {
  final String username;

  UserInfo({required this.username});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(username: json['username'] ?? '');
  }
}
