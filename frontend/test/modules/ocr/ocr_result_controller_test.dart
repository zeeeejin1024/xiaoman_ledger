import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/modules/ocr/ocr_result_controller.dart';

void main() {
  test('editable OCR fields update the candidate before saving', () {
    final controller = OcrResultController([
      OcrEditableItem(
        clientId: 'row-1',
        amount: 12,
        merchant: '旧商家',
        date: '2026-09-15',
      ),
    ]);

    controller.updateAmount('row-1', 18.5);
    controller.updateMerchant('row-1', '新商家');
    controller.updateDate('row-1', '2026-09-16');
    controller.updateNote('row-1', '午餐');
    controller.applyCategoryTo('row-1', 7);

    final item = controller.items.single;
    expect(item.amount, 18.5);
    expect(item.merchant, '新商家');
    expect(item.date, '2026-09-16');
    expect(item.note, '午餐');
    expect(item.categoryId, 7);
    expect(controller.canSave, isTrue);
  });

  test(
    'partial save removes successes and retains failed rows with errors',
    () {
      final controller = OcrResultController([
        OcrEditableItem(
          clientId: 'ok',
          amount: 12,
          categoryId: 1,
          date: '2026-09-16',
        ),
        OcrEditableItem(
          clientId: 'failed',
          amount: 20,
          categoryId: 2,
          date: '2026-09-16',
        ),
      ]);

      controller.applySaveResult(
        const OcrBatchSaveResult([
          OcrItemSaveResult(clientId: 'ok', saved: true),
          OcrItemSaveResult(
            clientId: 'failed',
            saved: false,
            message: '网络中断，请重试',
          ),
        ]),
      );

      expect(controller.items.map((item) => item.clientId), ['failed']);
      expect(controller.errors['failed'], '网络中断，请重试');
      expect(controller.allSaved, isFalse);
    },
  );
}
