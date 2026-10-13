import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaojia_ledger/core/living_allowance.dart';

Future<LivingAllowanceSettings?> showLivingAllowanceSetup(
  BuildContext context, {
  required LivingAllowanceSettings initial,
}) async {
  final amount = TextEditingController(
    text: initial.baseAmount > 0 ? initial.baseAmount.toStringAsFixed(0) : '',
  );
  final payday = TextEditingController(text: initial.payday.toString());
  var autoSave = initial.autoSaveRemainder;
  try {
    return await showDialog<LivingAllowanceSettings>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('设置本月生活费'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('小满会根据到账日计算周期。收入只有在记账时勾选“计入本月生活费”才会补充额度。'),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '每期基础生活费'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payday,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '每月到账日（1—28日）'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('月底结余转为存钱成果'),
                  subtitle: const Text('自动存入“生活费结余”目标'),
                  value: autoSave,
                  onChanged: (value) => setState(() => autoSave = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amount.text.trim());
                final day = int.tryParse(payday.text.trim());
                if (value == null ||
                    value <= 0 ||
                    day == null ||
                    day < 1 ||
                    day > 28)
                  return;
                Navigator.pop(
                  ctx,
                  LivingAllowanceSettings(
                    baseAmount: value,
                    payday: day,
                    autoSaveRemainder: autoSave,
                    setupComplete: true,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  } finally {
    amount.dispose();
    payday.dispose();
  }
}

Future<bool> showLivingAllowancePrimer(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('管好这个月的生活费'),
        content: const Text('设置每期可用额度，小满会观察使用速度。月底剩余的钱会自动计入存钱成果，不会算作新的收入或消费。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('以后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('开始设置'),
          ),
        ],
      ),
    ) ??
    false;
