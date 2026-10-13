import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/models/api_response.dart';
import 'package:xiaojia_ledger/data/models/record.dart';

class RecordApi {
  static final ApiClient _client = ApiClient();

  static Future<ApiResponse<List<Record>>> getRecords({String? month}) async {
    final response = await _client.get(
      '/records',
      queryParameters: month != null ? {'month': month} : null,
    );
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (apiResp.isSuccess && apiResp.data != null) {
      final list = (apiResp.data as List<dynamic>)
          .map((e) => Record.fromJson(e))
          .toList();
      return ApiResponse(code: 0, message: 'ok', data: list);
    }
    return ApiResponse(code: apiResp.code, message: apiResp.message);
  }

  static Future<ApiResponse<Record>> addRecord({
    required String type,
    required double amount,
    required int categoryId,
    required String date,
    String? note,
    String? requestId,
  }) async {
    final response = await _client.post(
      '/records',
      data: {
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'date': date,
        'note': note ?? '',
      },
      options: requestId == null
          ? null
          : Options(headers: {'Idempotency-Key': requestId}),
    );
    final apiResp = ApiResponse.fromJson(response.data, Record.fromJson);
    final now = DateTime.now();
    final recordedDate = DateTime.tryParse(apiResp.data?.date ?? date);
    if (apiResp.isSuccess &&
        recordedDate != null &&
        recordedDate.year == now.year &&
        recordedDate.month == now.month &&
        recordedDate.day == now.day) {
      try {
        await (await NotificationPreferencesRepository.create()).markRecordedOn(
          now,
        );
      } catch (error) {
        // The server already saved the record. Notification bookkeeping must
        // never make a successful save appear failed and invite a duplicate.
        debugPrint('Record reminder marker failed: ${error.runtimeType}');
      }
    }
    if (apiResp.isSuccess) {
      unawaited(_refreshNotifications());
    }
    return apiResp;
  }

  static Future<void> _refreshNotifications() async {
    try {
      await (await NotificationCoordinator.shared()).reconcileAll();
    } catch (error) {
      debugPrint('Post-save notification refresh failed: ${error.runtimeType}');
    }
  }

  static Future<bool> updateRecord(int id, String field, dynamic value) async {
    final response = await _client.put(
      '/records/$id',
      data: {'field': field, 'value': value},
    );
    return response.data['code'] == 0;
  }

  static Future<bool> deleteRecord(int id) async {
    final response = await _client.delete('/records/$id');
    return response.data['code'] == 0;
  }
}
