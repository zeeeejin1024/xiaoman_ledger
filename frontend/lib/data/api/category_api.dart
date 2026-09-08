import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/models/api_response.dart';
import 'package:xiaojia_ledger/data/models/category.dart';

class CategoryApi {
  static final ApiClient _client = ApiClient();

  static Future<ApiResponse<List<Category>>> getCategories() async {
    final response = await _client.get('/categories');
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (apiResp.isSuccess && apiResp.data != null) {
      final list = (apiResp.data as List<dynamic>)
          .map((e) => Category.fromJson(e))
          .toList();
      return ApiResponse(code: 0, message: 'ok', data: list);
    }
    return ApiResponse(code: apiResp.code, message: apiResp.message);
  }

  static Future<ApiResponse<dynamic>> deleteCategory(int id) async {
    final response = await _client.delete('/categories/$id');
    return ApiResponse.fromJson(response.data, null);
  }
}
