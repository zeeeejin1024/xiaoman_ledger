import 'package:flutter/foundation.dart';

class OcrEditableItem {
  final String clientId;
  double amount;
  String merchant;
  String date;
  String note;
  int? categoryId;

  OcrEditableItem({
    required this.clientId,
    required this.amount,
    this.merchant = '',
    required this.date,
    this.note = '',
    this.categoryId,
  });
}

class OcrItemSaveResult {
  final String clientId;
  final bool saved;
  final String? message;

  const OcrItemSaveResult({
    required this.clientId,
    required this.saved,
    this.message,
  });
}

class OcrBatchSaveResult {
  final List<OcrItemSaveResult> items;
  const OcrBatchSaveResult(this.items);
}

class OcrResultController extends ChangeNotifier {
  final List<OcrEditableItem> items;
  final Set<String> selected = {};
  final Map<String, String> errors = {};

  OcrResultController(this.items);

  OcrEditableItem? _find(String id) {
    for (final item in items) {
      if (item.clientId == id) return item;
    }
    return null;
  }

  void toggle(String id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(items.map((item) => item.clientId));
    notifyListeners();
  }

  void applyCategory(int categoryId) {
    for (final item in items) {
      if (selected.contains(item.clientId)) item.categoryId = categoryId;
    }
    notifyListeners();
  }

  void applyCategoryTo(String clientId, int categoryId) {
    _find(clientId)?.categoryId = categoryId;
    errors.remove(clientId);
    notifyListeners();
  }

  void updateAmount(String clientId, double amount) {
    _find(clientId)?.amount = amount;
    errors.remove(clientId);
    notifyListeners();
  }

  void updateMerchant(String clientId, String merchant) {
    _find(clientId)?.merchant = merchant.trim();
  }

  void updateDate(String clientId, String date) {
    _find(clientId)?.date = date;
    errors.remove(clientId);
    notifyListeners();
  }

  void updateNote(String clientId, String note) {
    _find(clientId)?.note = note.trim();
  }

  void applySaveResult(OcrBatchSaveResult result) {
    final savedIds = result.items
        .where((item) => item.saved)
        .map((item) => item.clientId)
        .toSet();
    items.removeWhere((item) => savedIds.contains(item.clientId));
    selected.removeAll(savedIds);
    errors.clear();
    for (final item in result.items.where((item) => !item.saved)) {
      errors[item.clientId] = item.message ?? '保存失败，请重试';
    }
    notifyListeners();
  }

  bool get allSaved => items.isEmpty;

  bool get canSave =>
      items.isNotEmpty &&
      items.every((item) {
        return item.amount > 0 &&
            item.categoryId != null &&
            DateTime.tryParse(item.date) != null;
      });
}
