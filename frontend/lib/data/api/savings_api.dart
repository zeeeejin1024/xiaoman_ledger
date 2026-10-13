import 'package:xiaojia_ledger/data/api/api_client.dart';

class SavingsApi {
  static final ApiClient _client = ApiClient();

  static Future<List<dynamic>> getGoals() async {
    final res = await _client.get('/savings/goals');
    if (res.data['code'] == 0) return res.data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>?> createGoal(
    String name,
    double target, {
    String? deadline,
    String? emoji,
  }) async {
    final res = await _client.post(
      '/savings/goals',
      data: {
        'name': name,
        'target_amount': target,
        'deadline': deadline,
        'emoji': emoji,
      },
    );
    if (res.data['code'] == 0) return res.data['data'];
    return null;
  }

  static Future<bool> deleteGoal(int id) async {
    final res = await _client.delete('/savings/goals/$id');
    return res.data['code'] == 0;
  }

  static Future<bool> updateGoal(int id, String name, double target) async {
    final res = await _client.put(
      '/savings/goals/$id',
      data: {'name': name, 'target_amount': target},
    );
    return res.data['code'] == 0;
  }

  static Future<List<dynamic>> getGoalHistory(int goalId) async {
    final res = await _client.get('/savings/goals/$goalId/history');
    if (res.data['code'] == 0) return res.data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>?> deposit(
    int goalId,
    double amount, {
    String? note,
  }) async {
    final res = await _client.post(
      '/savings/deposit',
      data: {
        'goal_id': goalId,
        'amount': amount,
        if (note != null) 'note': note,
      },
    );
    if (res.data['code'] == 0) return res.data['data'];
    return null;
  }

  static Future<bool> createRule(
    int goalId,
    String ruleType, {
    double? amount,
  }) async {
    final res = await _client.post(
      '/savings/rules',
      data: {'goal_id': goalId, 'rule_type': ruleType, 'amount': amount},
    );
    return res.data['code'] == 0;
  }

  static Future<bool> deleteRule(int ruleId) async {
    final res = await _client.delete('/savings/rules/$ruleId');
    return res.data['code'] == 0;
  }
}
