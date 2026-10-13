import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/living_allowance_repository.dart';
import 'package:xiaojia_ledger/data/api/category_api.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/models/category.dart';
import 'package:xiaojia_ledger/modules/savings/savings_page.dart';
import 'package:xiaojia_ledger/widgets/particle_effect.dart';
import 'package:uuid/uuid.dart';

class AddRecordSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  const AddRecordSheet({super.key, this.onSaved});
  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  String _type = 'expense';
  Category? _cat;
  final _amt = TextEditingController(),
      _note = TextEditingController(),
      _search = TextEditingController();
  DateTime _date = DateTime.now();
  List<Category> _roots = [], _all = [];
  List<Category> _recentCats = [];
  int? _expandedId;
  bool _load = true, _saving = false;
  bool _includeIncomeInLivingAllowance = false;
  Timer? _debounce;
  String? _requestId;
  String? _requestFingerprint;

  @override
  void initState() {
    super.initState();
    _l();
    _loadRecent();
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _loadRecent() async {
    final p = await SharedPreferences.getInstance();
    final ids = p.getStringList('recent_cats_$_type') ?? [];
    if (_all.isEmpty) return;
    final found = <Category>[];
    for (final id in ids) {
      final idInt = int.tryParse(id);
      if (idInt == null) continue;
      for (final root in _all) {
        for (final leaf in root.leafCategories) {
          if (leaf.id == idInt && leaf.type == _type) {
            found.add(leaf);
            break;
          }
        }
      }
    }
    if (mounted) setState(() => _recentCats = found.take(5).toList());
  }

  Future<void> _saveRecentCat(Category cat) async {
    final p = await SharedPreferences.getInstance();
    final key = 'recent_cats_${cat.type}';
    final ids = p.getStringList(key) ?? [];
    ids.remove(cat.id.toString());
    ids.insert(0, cat.id.toString());
    await p.setStringList(key, ids.take(10).toList());
  }

  Future<void> _l() async {
    final r = await CategoryApi.getCategories();
    if (r.isSuccess && r.data != null) {
      _all = r.data!;
      _f();
      await _loadRecent();
    }
    if (mounted) setState(() => _load = false);
  }

  void _f() {
    _search.clear();
    _expandedId = null;
    _roots = _all.where((c) => c.type == _type).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    final a = double.tryParse(_amt.text);
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    if (_cat == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择分类')));
      return;
    }
    setState(() => _saving = true);
    final fingerprint =
        '$_type|$a|${_cat!.id}|${_date.toIso8601String()}|${_note.text}';
    if (_requestFingerprint != fingerprint) {
      _requestFingerprint = fingerprint;
      _requestId = const Uuid().v4();
    }
    var recordSaved = false;
    try {
      final r = await RecordApi.addRecord(
        type: _type,
        amount: a,
        categoryId: _cat!.id,
        date: _date.toIso8601String().split('T')[0],
        note: _note.text.isNotEmpty ? _note.text : null,
        requestId: _requestId,
      );
      if (!r.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.message)));
        }
        return;
      }
      recordSaved = true;
      try {
        if (_type == 'income' &&
            _includeIncomeInLivingAllowance &&
            r.data != null) {
          final preferences = await SharedPreferences.getInstance();
          await LivingAllowanceRepository(
            preferences,
          ).includeIncomeRecord(r.data!.id);
        }
        await _saveRecentCat(_cat!);
      } catch (error) {
        debugPrint(
          'Record saved, local preferences failed: ${error.runtimeType}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('账单已保存，但本地附加设置未保存，请稍后检查生活费设置')),
          );
        }
      }
      // RecordApi refreshes notifications independently of this sheet.
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(recordSaved ? '账单已保存，请刷新查看' : '保存失败，请检查网络后重试'),
          ),
        );
      }
    } finally {
      if (mounted && !recordSaved) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amt.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btm = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: btm),
      decoration: BoxDecoration(
        color: AppColors.bgSheet,
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
          SizedBox(height: 16),
          Text(
            '记一笔',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 16),
          // Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tb('expense', '支出'),
                _tb('income', '收入'),
                _tb('savings', '存钱'),
              ],
            ),
          ),
          SizedBox(height: 12),
          // 搜索
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索分类...',
                prefixIcon: Icon(Icons.search, color: AppColors.gray, size: 18),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              style: TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ),
          SizedBox(height: 12),
          // 最近使用分类
          if (_recentCats.isNotEmpty && _search.text.isEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '最近使用',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.gray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _recentCats.map((c) {
                  final sel = _cat?.id == c.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _cat = c;
                        _expandedId = null;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.accent.withAlpha(40)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: sel
                            ? Border.all(color: AppColors.accent, width: 1.2)
                            : null,
                      ),
                      child: Text(
                        '${c.emoji ?? ''} ${c.name}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? AppColors.accentDark : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 8),
          ],
          // 分类 — 大类展开子类
          Expanded(
            child: _load
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  )
                : _roots.isEmpty
                ? Center(
                    child: Text(
                      '暂无分类',
                      style: TextStyle(color: AppColors.gray),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _roots.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _roots.length) return _addCustomBtn();
                      return _parentTile(_roots[i]);
                    },
                  ),
          ),
          // 底部
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                if (_cat != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_cat!.emoji ?? ''} ${_cat!.name}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accentDark,
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _cat = null),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                TextField(
                  controller: _amt,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -1,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppColors.gray),
                    border: InputBorder.none,
                  ),
                ),
                // 金额下方渐变装饰线
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withAlpha(80),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _datePicker()),
                    SizedBox(width: 8),
                    Expanded(child: _noteField()),
                  ],
                ),
                if (_type == 'income')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('计入本月生活费'),
                    subtitle: const Text('作为本期生活费的补充收入'),
                    value: _includeIncomeInLivingAllowance,
                    onChanged: (value) => setState(
                      () => _includeIncomeInLivingAllowance = value ?? false,
                    ),
                  ),
                SizedBox(height: 18),
                // 渐变保存按钮 + 粒子特效
                ParticleEffect(
                  onTap: _saving ? null : _save,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.premiumLight,
                          AppColors.premium,
                          AppColors.premiumDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.premium.withAlpha(
                            AppColors.isDark ? 100 : 50,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 内高光线
                        Positioned(
                          top: 0,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withAlpha(80),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _saving ? '保存中...' : '保 存',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(_date.year, _date.month, _date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    return '${_date.month}月${_date.day}日';
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (p != null) setState(() => _date = p);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 16, color: AppColors.gray),
            SizedBox(width: 6),
            Text(
              _friendlyDate(),
              style: TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return TextField(
      controller: _note,
      decoration: InputDecoration(
        hintText: '备注',
        hintStyle: TextStyle(color: AppColors.gray),
        border: InputBorder.none,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      style: TextStyle(color: AppColors.ink, fontSize: 14),
    );
  }

  Widget _parentTile(Category parent) {
    final children = parent.children.where((c) => c.type == _type).toList();
    // 即使没有子类，根分类也要显示（用户可以创建自定义子类）
    final isExpanded = _expandedId == parent.id;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _cat = parent;
              _expandedId = null;
            });
          },
          onLongPress: parent.isSystem ? null : () => _deleteCategory(parent),
          child: Container(
            margin: EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppColors.accent.withAlpha(15)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(parent.emoji ?? '', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parent.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                GestureDetector(
                  key: ValueKey('category-expand-${parent.id}'),
                  onTap: children.isEmpty
                      ? null
                      : () => setState(
                          () => _expandedId = isExpanded ? null : parent.id,
                        ),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: children.isEmpty
                        ? AppColors.gray.withAlpha(80)
                        : AppColors.gray,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: EdgeInsets.only(left: 12, bottom: 8),
            child: children.isEmpty
                ? GestureDetector(
                    onTap: () => _addCustom(parent),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.accent.withAlpha(60),
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text(
                            '添加子分类',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...children.map((c) {
                        final sel = _cat?.id == c.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _cat = c);
                            _expandedId = null;
                          },
                          onLongPress: c.isSystem
                              ? null
                              : () => _deleteCategory(c),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.accent.withAlpha(40)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: sel
                                  ? Border.all(
                                      color: AppColors.accent,
                                      width: 1.2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              '${c.emoji ?? ''} ${c.name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: sel
                                    ? AppColors.accentDark
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: () => _addCustom(parent),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.gray.withAlpha(80),
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 13, color: AppColors.gray),
                              SizedBox(width: 2),
                              Text(
                                '自定义',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _addCustomBtn() {
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: 16),
      child: GestureDetector(
        onTap: () => _addCustom(null),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.gray.withAlpha(60),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: AppColors.gray),
              SizedBox(width: 6),
              Text(
                '新建根分类',
                style: TextStyle(fontSize: 14, color: AppColors.gray),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCustom(Category? parent) async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📌');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加自定义分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text('图标', style: TextStyle(color: AppColors.gray)),
                ),
                Expanded(
                  child: TextField(
                    controller: emojiCtrl,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24),
                    decoration: InputDecoration(counterText: ''),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text('名称', style: TextStyle(color: AppColors.gray)),
                ),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(hintText: '如：买菜'),
                    autofocus: true,
                  ),
                ),
              ],
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
            child: Text('添加'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      try {
        final body = <String, dynamic>{
          'name': nameCtrl.text.trim(),
          'type': _type,
          'emoji': emojiCtrl.text.isNotEmpty ? emojiCtrl.text : '📌',
        };
        if (parent != null) body['parent_id'] = parent.id;
        final r = await ApiClient().post('/categories', data: body);
        if (r.data['code'] == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加 ${nameCtrl.text.trim()}')),
          );
          _l(); // 刷新分类列表
        }
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败')));
      }
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除分类'),
        content: Text(
          '确定要删除「${cat.emoji ?? ''} ${cat.name}」吗？\n该分类下的子分类也会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final r = await CategoryApi.deleteCategory(cat.id);
        if (r.isSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已删除')));
          _l();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.message)));
        }
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败')));
      }
    }
  }

  Widget _tb(String type, String label) {
    final a = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (type == 'savings') {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavingsPage()),
            );
            return;
          }
          setState(() {
            _type = type;
            _cat = null;
          });
          _f();
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: a ? AppColors.amber.withAlpha(30) : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: a
                ? Border.all(color: AppColors.amber.withAlpha(100))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: a ? AppColors.ink : AppColors.gray,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
