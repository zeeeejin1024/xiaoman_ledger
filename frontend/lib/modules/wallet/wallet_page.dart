import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/category_api.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'package:xiaojia_ledger/data/models/wallet_budget.dart';
import 'package:xiaojia_ledger/data/api/wallet_api.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<Category> _wallets = [];
  Map<int, double> _budgets = {};
  Map<int, double> _spent = {};
  bool _loading = true;
  bool _usingServerWallets = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final remote = await WalletApi.getWallets();
      if (remote != null) {
        final remoteCategories = remote
            .map(
              (wallet) => Category(
                id: wallet.id,
                name: wallet.name,
                type: 'expense',
                emoji: '💰',
              ),
            )
            .toList();
        if (mounted) {
          setState(() {
            _usingServerWallets = true;
            _wallets = remoteCategories;
            _budgets = {for (final wallet in remote) wallet.id: wallet.amount};
            _spent = {for (final wallet in remote) wallet.id: wallet.spent};
            _loading = false;
          });
        }
        return;
      }
      final r = await CategoryApi.getCategories();
      final prefs = await SharedPreferences.getInstance();
      if (r.isSuccess && r.data != null) {
        final all = r.data!
            .where((c) => c.type == 'expense')
            .expand((c) => c.leafCategories)
            .toList();
        final budgets = <int, double>{};
        final active = prefs.getStringList('active_wallets') ?? [];
        // 读取预算
        for (final c in all) {
          final b = prefs.getDouble('wallet_budget_${c.id}') ?? 0;
          if (b > 0) budgets[c.id] = b;
        }
        // 筛选显示的钱包：active 列表优先，否则用有预算的
        List<Category> shown;
        if (active.isNotEmpty) {
          shown = all.where((c) => active.contains(c.id.toString())).toList();
        } else {
          shown = all.where((c) => budgets.containsKey(c.id)).toList();
        }
        // 查询当月支出记录，计算每个分类的花费
        final spentMap = <int, double>{};
        final now = DateTime.now();
        final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final recR = await RecordApi.getRecords(month: month);
        if (recR.isSuccess && recR.data != null) {
          for (final rec in recR.data!) {
            if (!rec.isIncome) {
              spentMap[rec.categoryId] =
                  (spentMap[rec.categoryId] ?? 0) + rec.amount;
            }
          }
        }
        if (mounted) {
          setState(() {
            _wallets = shown;
            _budgets = budgets;
            _spent = spentMap;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addWallet() async {
    final r = await CategoryApi.getCategories();
    if (!r.isSuccess || r.data == null) return;
    final roots = r.data!.where((c) => c.type == 'expense').toList();
    if (_usingServerWallets) {
      await _addServerWallet(roots);
      return;
    }
    final all = r.data!
        .where((c) => c.type == 'expense')
        .expand((c) => c.leafCategories)
        .toList();
    final existing = _wallets.map((w) => w.id).toSet();
    final available = all.where((c) => !existing.contains(c.id)).toList();
    if (!mounted) return;
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) {
          final q = searchCtrl.text;
          final filtered = q.isEmpty
              ? available
              : available.where((c) => c.name.contains(q)).toList();
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.55,
            ),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '添加钱包',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setInner(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索分类...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.gray,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: Text(
                          c.emoji ?? '💰',
                          style: TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          c.name,
                          style: TextStyle(fontSize: 14, color: AppColors.ink),
                        ),
                        trailing: Icon(
                          Icons.add_circle_outline,
                          color: AppColors.gold,
                        ),
                        onTap: () async {
                          final bc = TextEditingController();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: Text('${c.name} 月预算'),
                              content: TextField(
                                controller: bc,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0 表示不设限',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dctx, false),
                                  child: Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dctx, true),
                                  child: Text('添加'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            try {
                              final b = double.tryParse(bc.text) ?? 0;
                              final p = await SharedPreferences.getInstance();
                              if (b > 0)
                                await p.setDouble('wallet_budget_${c.id}', b);
                              final a = p.getStringList('active_wallets') ?? [];
                              if (!a.contains(c.id.toString()))
                                a.add(c.id.toString());
                              await p.setStringList('active_wallets', a);
                              Navigator.pop(context);
                              _load();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已添加 ${c.name}')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('添加失败: $e')),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addServerWallet(List<Category> roots) async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final selectedRoots = <int>{};
    final selectedLeaves = <int>{};
    String? validationMessage;
    bool saving = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '新建钱包',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(sheetContext, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          maxLength: 20,
                          decoration: const InputDecoration(
                            labelText: '钱包名称',
                            hintText: '例如：一日三餐',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 126,
                        child: TextField(
                          controller: budgetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '月预算',
                            prefixText: '¥ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '计入分类',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '选大类会自动包含它的全部子类，也可以只选具体子类。',
                    style: TextStyle(color: AppColors.gray, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final root in roots) ...[
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selectedRoots.contains(root.id),
                            secondary: Text(
                              root.emoji ?? '•',
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(root.name),
                            subtitle: const Text('包含全部子类'),
                            onChanged: (selected) => setSheetState(() {
                              if (selected == true) {
                                selectedRoots.add(root.id);
                                selectedLeaves.removeAll(
                                  root.children.map((child) => child.id),
                                );
                              } else {
                                selectedRoots.remove(root.id);
                              }
                              validationMessage = null;
                            }),
                          ),
                          if (!selectedRoots.contains(root.id))
                            for (final child in root.children)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.only(left: 34),
                                value: selectedLeaves.contains(child.id),
                                title: Text(child.name),
                                secondary: Text(child.emoji ?? '•'),
                                onChanged: (selected) => setSheetState(() {
                                  selected == true
                                      ? selectedLeaves.add(child.id)
                                      : selectedLeaves.remove(child.id);
                                  validationMessage = null;
                                }),
                              ),
                        ],
                      ],
                    ),
                  ),
                  if (validationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        validationMessage!,
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final amount =
                                  double.tryParse(
                                    budgetController.text.trim(),
                                  ) ??
                                  0;
                              if (name.isEmpty ||
                                  amount <= 0 ||
                                  (selectedRoots.isEmpty &&
                                      selectedLeaves.isEmpty)) {
                                setSheetState(() {
                                  validationMessage = name.isEmpty
                                      ? '请填写钱包名称'
                                      : amount <= 0
                                      ? '月预算需要大于 0'
                                      : '请至少选择一个分类';
                                });
                                return;
                              }
                              setSheetState(() => saving = true);
                              final bindings = [
                                ...selectedRoots.map(
                                  (id) => WalletCategoryBinding(
                                    categoryId: id,
                                    includeDescendants: true,
                                  ),
                                ),
                                ...selectedLeaves.map(
                                  (id) => WalletCategoryBinding(
                                    categoryId: id,
                                    includeDescendants: false,
                                  ),
                                ),
                              ];
                              final ok = await WalletApi.createWallet(
                                name: name,
                                amount: amount,
                                bindings: bindings,
                              );
                              if (!sheetContext.mounted) return;
                              if (ok) {
                                Navigator.pop(sheetContext, true);
                              } else {
                                setSheetState(() {
                                  saving = false;
                                  validationMessage = '创建失败，请检查网络后重试';
                                });
                              }
                            },
                      child: Text(saving ? '创建中...' : '创建钱包'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
    budgetController.dispose();
    if (created == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('钱包已创建')));
      }
    }
  }

  Future<void> _editBudget(Category c) async {
    final budget = _budgets[c.id] ?? 0;
    final bc = TextEditingController(
      text: budget > 0 ? budget.toStringAsFixed(0) : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 ${c.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bc,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '月预算金额',
                hintText: '0 表示不设限',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('保存', style: TextStyle(color: AppColors.highlight)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final b = double.tryParse(bc.text) ?? 0;
      if (_usingServerWallets) {
        final updated = await WalletApi.updateBudget(c.id, b);
        if (!updated) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('钱包更新失败')));
          return;
        }
        await _load();
        return;
      }
      final p = await SharedPreferences.getInstance();
      if (b > 0)
        await p.setDouble('wallet_budget_${c.id}', b);
      else
        await p.remove('wallet_budget_${c.id}');
      _load();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${c.name} 已更新')));
    }
  }

  Future<void> _removeWallet(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('移除钱包'),
        content: Text('确定移除「${c.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (_usingServerWallets) {
        if (await WalletApi.deleteWallet(c.id)) {
          await _load();
        }
        return;
      }
      final p = await SharedPreferences.getInstance();
      await p.remove('wallet_budget_${c.id}');
      final a = p.getStringList('active_wallets') ?? [];
      a.remove(c.id.toString());
      await p.setStringList('active_wallets', a);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppThemedPage(builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('我的钱包', style: TextStyle(color: AppColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.gold),
            onPressed: () {
              HapticFeedback.lightImpact();
              _addWallet();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _wallets.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: AppColors.accent.withAlpha(80),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '还没有钱包',
                    style: TextStyle(fontSize: 16, color: AppColors.gray),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _addWallet,
                    icon: Icon(Icons.add),
                    label: Text('添加第一个钱包'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: _wallets.length,
              itemBuilder: (_, i) {
                final c = _wallets[i];
                final budget = _budgets[c.id] ?? 0;
                final spent = _spent[c.id] ?? 0;
                final isOver = budget > 0 && spent > budget;
                final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: PremiumCard(
                    padding: EdgeInsets.all(18),
                    gradient: isOver
                        ? [AppColors.cardAlt, AppColors.card]
                        : null,
                    child: Row(
                      children: [
                        Text(c.emoji ?? '💰', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isOver
                                            ? AppColors.card
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (isOver)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withAlpha(40),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '超支',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                '已花 ¥${spent.toStringAsFixed(2)}${budget > 0 ? ' / 预算 ¥${budget.toStringAsFixed(2)}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOver
                                      ? AppColors.ink2.withAlpha(180)
                                      : AppColors.gray,
                                ),
                              ),
                              if (budget > 0) ...[
                                SizedBox(height: 8),
                                PremiumBar(
                                  value: pct,
                                  color: isOver
                                      ? AppColors.danger
                                      : AppColors.gold,
                                  height: 5,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz,
                            color: isOver
                                ? AppColors.ink2.withAlpha(150)
                                : AppColors.gray,
                          ),
                          onSelected: (v) {
                            if (v == 'edit')
                              _editBudget(c);
                            else
                              _removeWallet(c);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text('编辑预算')),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                '移除',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
