import 'package:flutter/material.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'ocr_result_controller.dart';

class OcrResultPage extends StatefulWidget {
  final OcrResultController controller;
  final List<Category> categories;
  final Future<OcrBatchSaveResult> Function(List<OcrEditableItem>) onSave;
  const OcrResultPage({
    super.key,
    required this.controller,
    required this.categories,
    required this.onSave,
  });
  @override
  State<OcrResultPage> createState() => _OcrResultPageState();
}

class _OcrResultPageState extends State<OcrResultPage> {
  bool _saving = false;

  Future<int?> _pickCategory() => showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '选择分类',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final root in widget.categories) ...[
            ListTile(
              leading: Text(root.emoji ?? '•'),
              title: Text(root.name),
              subtitle: const Text('选择大类'),
              onTap: () => Navigator.pop(sheetContext, root.id),
            ),
            for (final child in root.children)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: Text(child.emoji ?? '•'),
                title: Text(child.name),
                onTap: () => Navigator.pop(sheetContext, child.id),
              ),
          ],
        ],
      ),
    ),
  );

  Future<void> _batchCategory() async {
    final categoryId = await _pickCategory();
    if (categoryId != null) widget.controller.applyCategory(categoryId);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await widget.onSave(List.of(widget.controller.items));
      widget.controller.applySaveResult(result);
      if (!mounted) return;
      if (widget.controller.allSaved) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保留保存失败的账单，请修改后重试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _categoryName(int? categoryId) {
    if (categoryId == null) return '待选分类';
    for (final root in widget.categories) {
      if (root.id == categoryId) return root.name;
      for (final child in root.children) {
        if (child.id == categoryId) return child.name;
      }
    }
    return '分类 $categoryId';
  }

  Future<void> _pickDate(OcrEditableItem item) async {
    final initial = DateTime.tryParse(item.date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    widget.controller.updateDate(
      item.clientId,
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (_, __) => Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('确认截图账单')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                TextButton(
                  key: const ValueKey('ocr-select-all'),
                  onPressed: widget.controller.selectAll,
                  child: const Text('全选'),
                ),
                const Spacer(),
                OutlinedButton(
                  key: const ValueKey('ocr-batch-category'),
                  onPressed: widget.controller.selected.isEmpty
                      ? null
                      : _batchCategory,
                  child: const Text('批量设置分类'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.controller.items.length,
              itemBuilder: (_, index) {
                final item = widget.controller.items[index];
                final error = widget.controller.errors[item.clientId];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: widget.controller.selected.contains(
                                item.clientId,
                              ),
                              onChanged: (_) =>
                                  widget.controller.toggle(item.clientId),
                            ),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('ocr-merchant-${item.clientId}'),
                                initialValue: item.merchant,
                                decoration: const InputDecoration(
                                  labelText: '商家',
                                  isDense: true,
                                ),
                                onChanged: (value) => widget.controller
                                    .updateMerchant(item.clientId, value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('ocr-amount-${item.clientId}'),
                                initialValue: item.amount > 0
                                    ? item.amount.toStringAsFixed(2)
                                    : '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '金额',
                                  prefixText: '¥ ',
                                  isDense: true,
                                ),
                                onChanged: (value) =>
                                    widget.controller.updateAmount(
                                      item.clientId,
                                      double.tryParse(value) ?? 0,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                key: ValueKey('ocr-date-${item.clientId}'),
                                onTap: () => _pickDate(item),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '日期',
                                    isDense: true,
                                  ),
                                  child: Text(item.date),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: ValueKey('ocr-category-${item.clientId}'),
                                icon: const Icon(
                                  Icons.category_outlined,
                                  size: 18,
                                ),
                                label: Text(_categoryName(item.categoryId)),
                                onPressed: () async {
                                  final id = await _pickCategory();
                                  if (id != null)
                                    widget.controller.applyCategoryTo(
                                      item.clientId,
                                      id,
                                    );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('ocr-note-${item.clientId}'),
                                initialValue: item.note,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  labelText: '备注（可选）',
                                  isDense: true,
                                ),
                                onChanged: (value) => widget.controller
                                    .updateNote(item.clientId, value),
                              ),
                            ),
                          ],
                        ),
                        if (error != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 40, top: 4),
                              child: Text(
                                error,
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('ocr-save'),
                onPressed: widget.controller.canSave && !_saving ? _save : null,
                child: Text(_saving ? '保存中...' : '保存全部'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
