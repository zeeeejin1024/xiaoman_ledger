import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/models/api_response.dart';
import 'package:xiaojia_ledger/data/models/user.dart';

class AuthApi {
  static final ApiClient _client = ApiClient();

  // 登录（兼容用户名和手机号）
  static Future<ApiResponse<AuthData>> login(
    String account,
    String password,
  ) async {
    final response = await _client.post(
      '/auth/login',
      data: {'username': account, 'password': password},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => AuthData.fromJson(json),
    );
  }

  // 注册（用户名）
  static Future<ApiResponse<dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await _client.post(
      '/auth/register',
      data: {'username': username, 'password': password},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => AuthData.fromJson(json),
    );
  }

  // 手机号注册
  static Future<ApiResponse<dynamic>> registerWithPhone(
    String phone,
    String password,
    String securityQuestion,
    String securityAnswer,
  ) async {
    final response = await _client.post(
      '/auth/register',
      data: {
        'phone': phone,
        'password': password,
        'security_question': securityQuestion,
        'security_answer': securityAnswer,
      },
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => AuthData.fromJson(json),
    );
  }

  // 老用户迁移
  static Future<ApiResponse<dynamic>> migrate(
    String phone,
    String password,
    String securityQuestion,
    String securityAnswer,
  ) async {
    final response = await _client.post(
      '/auth/migrate',
      data: {
        'phone': phone,
        'password': password,
        'security_question': securityQuestion,
        'security_answer': securityAnswer,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // 忘记密码
  static Future<ApiResponse<dynamic>> forgotPassword(
    String phone,
    String securityAnswer,
  ) async {
    final response = await _client.post(
      '/auth/forgot-password',
      data: {'phone': phone, 'security_answer': securityAnswer},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // 重置密码
  static Future<ApiResponse<dynamic>> resetPassword(
    String tempToken,
    String newPassword,
  ) async {
    final response = await _client.post(
      '/auth/reset-password',
      data: {'temp_token': tempToken, 'new_password': newPassword},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // 修改密码
  static Future<ApiResponse<dynamic>> updatePassword(
    String oldPw,
    String newPw,
  ) async {
    final response = await _client.put(
      '/auth/user/update-password',
      data: {'old_password': oldPw, 'new_password': newPw},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // 修改手机号
  static Future<ApiResponse<dynamic>> updatePhone(
    String password,
    String phone,
  ) async {
    final response = await _client.put(
      '/auth/user/update-phone',
      data: {'password': password, 'phone': phone},
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  // 修改密保
  static Future<ApiResponse<dynamic>> updateSecurity(
    String password,
    String question,
    String answer,
  ) async {
    final response = await _client.put(
      '/auth/user/update-security',
      data: {
        'password': password,
        'security_question': question,
        'security_answer': answer,
      },
    );
    return ApiResponse.fromJson(response.data, (json) => json);
  }

  static Future<ApiResponse<UserInfo>> getMe() async {
    final response = await _client.get('/auth/me');
    return ApiResponse.fromJson(response.data, UserInfo.fromJson);
  }
}
