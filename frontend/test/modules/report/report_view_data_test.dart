import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/modules/report/report_view_data.dart';

void main() {
  test('uses evidence-backed recommendation messages from the server', () {
    final messages = reportRecommendationMessages({
      'insights': {
        'data_sufficient': true,
        'recommendations': [
          {
            'fact_id': 'monthly-top-category',
            'message': '餐饮占 42%，下月先减少 ¥20.00。',
          },
        ],
      },
    });

    expect(messages, ['餐饮占 42%，下月先减少 ¥20.00。']);
  });

  test('does not invent advice when the sample is insufficient', () {
    final messages = reportRecommendationMessages({
      'insights': {'data_sufficient': false, 'recommendations': const []},
    });

    expect(messages, ['继续记录几笔，数据充足后再给你有依据的建议。']);
  });
}
