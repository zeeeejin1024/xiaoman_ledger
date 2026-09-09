import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/data/api/savings_api.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});
  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  List<dynamic> _goals = [];
  bool _loading = true;
  final Map<int, bool> _expanded = {};
  final Map<int, List<dynamic>> _histories = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _goals = await SavingsApi.getGoals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败，请稍后重试')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadHistory(int goalId) async {
    if (_histories.containsKey(goalId)) return;
    try {
      final history = await SavingsApi.getGoalHistory(goalId);
      _histories[goalId] = history;
    } catch (_) {
      _histories[goalId] = [];
    }
    setState(() {});
  }

  Future<void> _create() async {
    final nc = TextEditingController(), ac = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('创建存钱目标'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nc,
              decoration: InputDecoration(labelText: '目标名称'),
            ),
            SizedBox(height: 8),
            TextField(
              controller: ac,
              decoration: InputDecoration(labelText: '目标金额'),
              keyboardType: TextInputType.number,
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
            child: Text('创建'),
          ),
        ],
      ),
    );
    if (ok == true &&
        nc.text.isNotEmpty &&
        (double.tryParse(ac.text) ?? 0) > 0) {
      try {
        await SavingsApi.createGoal(nc.text.trim(), double.parse(ac.text));
        _load();
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('创建失败，请重试')));
      }
    }
  }

  Future<void> _deposit(dynamic goal) async {
    final ctrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('存入「${goal['name']}」'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '金额'),
              autofocus: true,
            ),
            SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: '备注（可选）'),
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
            child: Text('存入'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final a = double.tryParse(ctrl.text) ?? 0;
      if (a > 0) {
        try {
          await SavingsApi.deposit(
            goal['id'],
            a,
            note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
          );
          _histories.remove(goal['id']);
          _load();
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('存入失败，请重试')));
        }
      }
    }
  }

  void _editGoal(dynamic goal) async {
    final nc = TextEditingController(text: goal['name'] ?? '');
    final ac = TextEditingController(
      text: (goal['target_amount'] ?? 0).toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑目标'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nc,
              decoration: InputDecoration(labelText: '目标名称'),
            ),
            SizedBox(height: 8),
            TextField(
              controller: ac,
              decoration: InputDecoration(labelText: '目标金额'),
              keyboardType: TextInputType.number,
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
            child: Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SavingsApi.updateGoal(
          goal['id'],
          nc.text.trim(),
          double.tryParse(ac.text) ?? 0,
        );
        _load();
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('编辑失败，请重试')));
      }
    }
  }

  void _deleteGoal(dynamic goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除目标'),
        content: Text('确定删除「${goal['name']}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.coralRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SavingsApi.deleteGoal(goal['id']);
        _load();
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Center(child: CircularProgressIndicator(color: AppColors.amber));
    if (_goals.isEmpty)
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UnfinishedRingMark(
                  size: 62,
                  animate: true,
                  ringColor: AppColors.accent.withAlpha(110),
                  markerColor: AppColors.highlight,
                  trackColor: AppColors.accent.withAlpha(20),
                ),
                SizedBox(height: 16),
                Text(
                  '还没有存钱目标',
                  style: TextStyle(fontSize: 14, color: AppColors.gray),
                ),
                SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _create,
                    child: Text('创建第一个目标'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withAlpha(50),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _create();
          },
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: Icon(Icons.add),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: _goals.length,
        itemBuilder: (_, i) {
          final g = _goals[i];
          final id = g['id'] as int;
          final n = g['name'] ?? '';
          final t = (g['target_amount'] as num?)?.toDouble() ?? 0;
          final cur = (g['current_amount'] as num?)?.toDouble() ?? 0;
          final pct = t > 0 ? (cur / t).clamp(0.0, 1.0) : 0.0;
          final achieved = pct >= 1;
          final isExpanded = _expanded[id] ?? false;

          return Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: GestureDetector(
              onLongPress: () => _showActions(g),
              child: GlassCard(
                padding: EdgeInsets.all(20),
                gradient: achieved ? AppColors.cardSageTint : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          g['emoji'] ?? '💰',
                          style: TextStyle(fontSize: 32),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '¥${cur.toStringAsFixed(2)} / ¥${t.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: achieved
                                      ? AppColors.sage
                                      : AppColors.inkSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (achieved)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sage,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: 14,
                                  color: AppColors.card,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '已达成',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.card,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 14),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 12,
                          backgroundColor: AppColors.lightGray.withAlpha(80),
                          valueColor: AlwaysStoppedAnimation(
                            achieved ? AppColors.sage : AppColors.amber,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: achieved ? AppColors.sage : AppColors.gray,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _deposit(g),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '存入',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 展开历史
                    if (isExpanded) ...[
                      SizedBox(height: 12),
                      Divider(),
                      Builder(
                        builder: (_) {
                          final history = _histories[id] ?? [];
                          if (history.isEmpty)
                            return Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '暂无存入记录',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray,
                                ),
                              ),
                            );
                          return Column(
                            children: history
                                .take(5)
                                .map<Widget>(
                                  (h) => Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.add_circle,
                                          size: 14,
                                          color: AppColors.sage,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '+¥${(h['amount'] as num).toDouble().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.sage,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (h['note'] != null) ...[
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              h['note']!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.gray,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Text(
                                          h['date'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.gray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                    SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        _loadHistory(id);
                        setState(() => _expanded[id] = !isExpanded);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isExpanded ? '收起' : '查看存入记录',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray,
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 14,
                            color: AppColors.gray,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showActions(dynamic goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: GlassCard(
          padding: EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: AppColors.sage),
                title: Text('存入'),
                onTap: () {
                  Navigator.pop(context);
                  _deposit(goal);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: AppColors.ink),
                title: Text('编辑'),
                onTap: () {
                  Navigator.pop(context);
                  _editGoal(goal);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.coralRed),
                title: Text('删除', style: TextStyle(color: AppColors.coralRed)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteGoal(goal);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
