import 'package:xiaojia_ledger/data/api/api_client.dart';

class StatsApi {
  static final ApiClient _client = ApiClient();

  static Future<Map<String, dynamic>?> getMonthly(String month) async {
    final res = await _client.get(
      '/stats/monthly',
      queryParameters: {'month': month},
    );
    if (res.data['code'] == 0) return res.data['data'];
    return null;
  }

  static Future<Map<String, dynamic>?> getYearly(String year) async {
    final res = await _client.get(
      '/stats/yearly',
      queryParameters: {'year': year},
    );
    if (res.data['code'] == 0) return res.data['data'];
    return null;
  }

  static Future<Map<String, dynamic>?> getWeekly(
    String start,
    String end,
  ) async {
    final res = await _client.get(
      '/stats/weekly',
      queryParameters: {'start': start, 'end': end},
    );
    if (res.data['code'] == 0) return res.data['data'];
    return null;
  }
}
