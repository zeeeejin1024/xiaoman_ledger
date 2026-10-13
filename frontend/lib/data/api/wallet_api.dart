import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/models/wallet_budget.dart';

class WalletApi {
  static final ApiClient _client = ApiClient();

  static Future<List<WalletBudget>?> getWallets() async {
    try {
      final response = await _client.get('/wallets');
      if (response.data['code'] != 0 || response.data['data'] is! List)
        return null;
      return (response.data['data'] as List)
          .whereType<Map>()
          .map((e) => WalletBudget.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> createWallet({
    required String name,
    required double amount,
    required List<WalletCategoryBinding> bindings,
  }) async {
    try {
      final response = await _client.post(
        '/wallets',
        data: {
          'name': name,
          'amount': amount,
          'wallet_type': 'custom',
          'bindings': bindings
              .map(
                (binding) => {
                  'category_id': binding.categoryId,
                  'include_descendants': binding.includeDescendants,
                },
              )
              .toList(),
        },
      );
      return response.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateBindings(
    int walletId,
    List<WalletCategoryBinding> bindings,
  ) async {
    try {
      final response = await _client.put(
        '/wallets/$walletId/categories',
        data: bindings
            .map(
              (e) => {
                'category_id': e.categoryId,
                'include_descendants': e.includeDescendants,
              },
            )
            .toList(),
      );
      return response.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateBudget(int walletId, double amount) async {
    try {
      final response = await _client.put(
        '/wallets/$walletId',
        data: {'amount': amount},
      );
      return response.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteWallet(int walletId) async {
    try {
      final response = await _client.delete('/wallets/$walletId');
      return response.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }
}
